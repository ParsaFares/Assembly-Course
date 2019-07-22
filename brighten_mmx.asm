%define     SYS_READ        0
%define     SYS_WRITE       1
%define     SYS_OPEN        2
%define     SYS_CLOSE       3
%define     SYS_EXIT        60
%define     SYS_CREAT       85

%define     BYTE_MIN        0
%define     BYTE_MAX        255

%imacro read 3
        mov	        rax, SYS_READ
        mov	        rdi, %1
        mov	        rsi, %2
        mov	        rdx, %3
        syscall
%endm

%imacro write 3
        mov	        rax, SYS_WRITE
        mov	        rdi, %1
        mov	        rsi, %2
        mov	        rdx, %3
        syscall
%endm

%imacro open 3
        mov	        rax, SYS_OPEN
        mov	        rdi, %1
        mov	        rsi, %3
        mov	        rdx, 644q
        syscall

        mov	        [%2], rax
%endm

%imacro close 1
        mov	        rax, SYS_CLOSE
        mov	        rdi, %1
        syscall
%endm


        section     .data
out_file            db      "output_mmx.bmp", 0
datasize            dq      0
darken_degree_bytes dq      0
buff_size           dq      1000
head_size           dq      54
darken_degree       db      0
; darken_degree       db      20
data_size           dq      0
buff	            times   1000    db      0
fd1                 dq      0
fd2                 dq      0
head                times   54	    db	    0
; name	            times   50	    db      0
name                db      "ray.bmp", 0

        section     .text
        global      _start

set_darken_array:
        push        rax
        push        rcx

        mov         rcx, 8
        xor         rax, rax

    loop:
        dec         rcx
        shl         rax, 8
        add         al, [darken_degree]

        cmp         rcx, 0
        ja          loop

        mov         [darken_degree_bytes], rax

        pop         rcx
        pop         rax
ret

read_header:
	    read	    [fd1], head, [head_size]
ret

read_image_data:
	    read	    [fd1], buff, [buff_size]

        mov         qword [data_size], rax
ret

change_image:
        movq        mm1, [darken_degree_bytes]
        mov         rcx, qword [data_size]

    image:
        cmp         rcx, 8
        jb          normal_add

        sub         rcx, 8

        movq        mm0, [buff + rcx]
        paddusb     mm0, mm1
        movq        [buff + rcx], mm0
        jmp         image

    normal_add:
        xor	        al, al
	    add	        al, byte [buff + rcx]
	    add	        al, byte [darken_degree]

        jnc         end
        cmp         byte [darken_degree], 0
        ja          positive
        jb          negative

    positive:
        mov         al, byte BYTE_MAX
        jmp         end

    negative:
        mov         al, byte BYTE_MIN
        jmp         end

    end:
        mov	        byte [buff + rcx], al
        clc
        cmp         rcx, 0
        ja          normal_add
ret

write_image:
	    write	    [fd2], buff, [data_size]
ret

create_new_image:
	    open	    out_file, fd2, 0102
        
        write	    [fd2], head, [head_size]
ret

_start:
        ; read	    0 , name, 50
        ; mov	        byte [name+rax-1], 0
        read	    0 , darken_degree, 50
   
	    open	    name, fd1, 00

        call        read_header
        call        create_new_image

        call        set_darken_array

    read_loop:
        call        read_image_data

        cmp         qword [data_size],0
        je          closes

        call        change_image
        call        write_image

        jmp         read_loop
        
    closes:
	    close	    [fd1]
	    close	    [fd2]

exit:
        mov         rax, SYS_EXIT
        mov         rdi, 0
        syscall
