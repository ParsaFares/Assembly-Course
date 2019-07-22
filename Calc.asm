%define     SYS_READ        3
%define     SYS_WRITE       4


        section     .data
errormsg        db      "INVALID INPUT!!", 10
error_len       equ     $-errormsg
helpmsg         db      "c -> clear, q -> quit, = -> result", 10
help_len        equ     $-helpmsg
hellomsg        db      "Press h for help!",10
hello_len       equ     $-hellomsg
divide_by_zero  db      "divided by zero", 10
div_len         equ     $-divide_by_zero
new_line        db      "", 10
new_line_len    equ     $-new_line

termios         times   36      db      0
stdin           equ     0
ICANON          equ     1<<1
ECHO            equ     1<<3
stdout          equ     1

isfloat         equ     1
opentered       equ     2
numentered      equ     3
erroroccured    equ     4
higherprec      equ     5
isneg           equ     6

max_size        equ     15
calc_flag       db      0
num_len         db      0
dot_pos         db      0
max_prec        db      0
num             dq      0
ten             dq      10
oldcontrol      dw      0
newcontrol      dw      0
fsig            dw      0
fexp            dq      0.0



        section     .bss
op_stack        resb    max_size                        ; operators' stack
num_stack       resq    max_size                        ; operands' stack
inp             resb    1                               ; holds input char
output          resb    max_size                        ; saves output



        section     .text
        global      _start

_start:
        call        hello_world
        call        canonical_off
        call        evaluate_expression

exit:
        call        canonical_on
        mov         rax, 1
        mov         rbx, 0
        int         80h


evaluate_expression:
        mov         rsi, num_stack
        mov         rdi, op_stack

    read_loop:
        call        read_char
        call        evaluate_char
        mov         bx, erroroccured
        clc
        btr         [calc_flag], bx
        jnc         read_loop

    reset:
        xor         rax, rax
        xor         rbx, rbx
        xor         rdx, rdx
        mov         qword[num], 0
        mov         byte[calc_flag], 0
        mov         byte[num_len], 0
        mov         byte[dot_pos], 0
        mov         rdi, op_stack
        mov         rcx, max_size

    clear_op_stack:
        mov         [rdi], bl
        inc         rdi
        loop        clear_op_stack
        mov         rsi, num_stack
        mov         rcx, max_size

    clear_num_stack:
        mov         [rsi], rbx
        add         rsi, 8
        loop        clear_num_stack
        xor         rcx, rcx
        jmp         evaluate_expression
ret



read_char:
        ; save contents of registers
        push        rax
        push        rbx
        push        rcx
        push        rdx

        mov         byte [inp], 0
        mov         rax, SYS_READ
        mov         rbx, stdin
        mov         rcx, inp
        mov         edx, 2
        int         80h

        ; retrieve contents of registers
        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret


evaluate_char:
        ; save contents of registers
        push        rax
        push        rbx

                                                        ; check clear command
        mov         al, byte 'h'
        cmp         al, [inp]
        jne         skiph
        call        goto_nextline
        call        print_help
        jmp         end_evaluate_char
    skiph:

                                                        ; check clear command
        mov         al, byte 'c'
        cmp         al, [inp]
        jne         skipc
        call        goto_nextline
        jmp         end_evaluate_char
    skipc:
                                                        ; check quit command
        mov         al, byte 'q'
        cmp         al, [inp]
        je          exit
                                                        ; space
        mov         al, 32 
        cmp         al, [inp]
        je          end_evaluate_char

                                                        ;check end of line
        mov         al, byte '='
        cmp         al, [inp]
        jne         dot
        call        push_number
        call        calculate
        call        print_result
        clc
        jmp         end_evaluate_char

        
    dot:                                                ; check for .
        mov         al, byte '.'
        cmp         al, [inp]
        jne         plus
        mov         al, [num_len]
        mov         [dot_pos], al
        mov         ax, isfloat
        clc
        bts         [calc_flag], ax
        jmp         end_evaluate_char

         
    plus:                                               ; check operator +
        mov         al, byte '+'
        cmp         al, [inp]
        jne         minus
        call        push_number
        call        evaluate_operator
        jmp         end_evaluate_char

    minus:                                              ; check operator -
        mov         al, byte '-'
        cmp         al, [inp]
        jne         star
        call        push_number
        call        evaluate_operator
        jmp         end_evaluate_char

    star:                                               ; check operator *
        mov         al, byte '*'
        cmp         al, [inp]
        jne         divide
        call        push_number
        call        evaluate_operator
        jmp         end_evaluate_char

    divide:                                             ; check operator /
        mov         al, byte '/'
        cmp         al, [inp]
        jne         digit
        call        push_number
        call        evaluate_operator
        jmp         end_evaluate_char

          
    digit:                                              ; check digit
        mov         al, byte '9'
        cmp         al, [inp]
        jl          char_error
        mov         al, byte '0'
        cmp         al, [inp]
        jg          char_error
        xor         rbx, rbx
        mov         bl, [inp]
        sub         bl, al
        push        rbx
        call        atoi
        mov         ax, numentered
        clc
        bts         [calc_flag], ax
        mov         ax, opentered
        clc
        btr         [calc_flag], ax
        clc
        jmp         end_evaluate_char

        
    char_error:                                         ; invalid expression
        call        invalid_exp_err

    end_evaluate_char:
        ; retrieve contents of registers
        pop         rbx
        pop         rax
ret



push_number:
        ; save registers' contents
        push        rax
        push        rbx
        push        rcx

        mov         bx, numentered
        clc
        btr         [calc_flag], bx
        jnc         end_push_number

        mov         bx, isneg
        clc
        btr         [calc_flag], bx
        jnc         continue_push
        neg         qword[num]

    continue_push:
        mov         bx, isfloat
        clc
        btr         [calc_flag], bx
        jc          push_float
        mov         al, [num_len]
        mov         [dot_pos], al

    push_float:
        xor         rcx, rcx
        mov         cl, [num_len]
        sub         cl, [dot_pos]
        cmp         [max_prec], cl
        jge         continue_push_float
        mov         [max_prec], cl

    continue_push_float:
        ffree       st0
        fild        qword[ten]
        fild        qword[num]
        mov         rax, [num]

    convert_to_float_loop:
        cmp         rcx, 0
        je          end_loop
        fdiv        st1
        dec         rcx
        jmp         convert_to_float_loop

    end_loop:
        fstp        qword[rsi]
        ffree       st0

        add         rsi, 8
        mov         qword[num], 0
        mov         byte[dot_pos], 0
        mov         byte[num_len], 0
        mov         ax, isfloat
        btr         [calc_flag], ax
        clc

    end_push_number:
        ; retrieve registers' contents
        pop         rcx
        pop         rbx
        pop         rax
ret



evaluate_operator:
        ; save registers' contents
        push        rax

        mov         ax, opentered
        clc
        bts         [calc_flag], ax
        jnc         check_prec
        xor         rax, rax
        mov         al, [inp]
        mov         al, byte '-'
        cmp         [inp], al
        jne         operator_error

        mov         ax, isneg
        clc
        btc         [calc_flag], ax
        jmp         end_evaluate_operator

    check_prec:
        dec         rdi
        clc

    continue:
        cmp         rdi, op_stack
        jl          push_operator

        push        rax
        mov         al, byte [inp]
        cmp         al, byte '/'
        je          check_second
        cmp         al, byte '*'
        je          check_second
        jmp         end_hiprec

    check_second:
        mov         al, byte [rdi]
        cmp         al, byte '+'
        je          is_higher
        cmp         al, byte '-'
        je          is_higher
        jmp         end_hiprec

    is_higher:
        mov         ax, higherprec
        clc
        bts         [calc_flag], ax

    end_hiprec:
        pop rax

        mov         ax, higherprec
        clc
        btr         [calc_flag], ax
        mov         al, [rdi]

        jc          push_operator
        clc
        inc         rdi
        call        calculate
        dec         rdi

    push_operator:
        inc         rdi
        cmp         rsi, num_stack
        je          first_neg
        mov         al, [inp]
        mov         [rdi], al
        mov         al, [rdi]
        inc         rdi
        jmp         end_evaluate_operator

    first_neg:
        mov         ax, isneg
        btc         [calc_flag], ax
        clc
        jmp         end_evaluate_operator


    operator_error:
        call        invalid_exp_err

    end_evaluate_operator:
        clc
        ; retrieve registers' contents
        pop         rax
ret



atoi:
        enter       16, 0
        ; save registers' contents
        mov         [rbp - 8], rax
        mov         [rbp - 16], rdx

        mov         rax, [num]
        mul         qword[ten]
        add         rax, [rbp + 16]
        mov         [num], rax
        inc         byte [num_len]

    end_atoi:
        ; retrieve contents of registers
        mov         rdx, [rbp - 16]
        mov         rax, [rbp - 8]
        leave
ret         8



calculate:
        ; save registers' contents
        push        rax
        push        rbx
        push        rcx
        push        rdx

    calculate_loop:
        cmp         rdi, op_stack
        je          end_calculate_loop
        sub         rsi, 8
        fld         qword[rsi]
        fldz
        fstp        qword[rsi]
        sub         rsi, 8
        fld         qword[rsi]
        fldz
        fstp        qword[rsi]

        dec         rdi
        mov         al, [rdi]
        mov         byte[rdi], 0

        cmp         al, byte '+'
        je          do_addition
        cmp         al, byte '-'
        je          do_subtraction
        cmp         al, byte '*'
        je          do_multiplication
        cmp         al, byte '/'
        je          do_division

    do_addition:
        fadd        st1
        jmp         end_calculate

    do_subtraction:
        fsub        st1
        jmp         end_calculate

    do_multiplication:
        fmul        st1
        jmp         end_calculate

    do_division:
        fdiv        st1
        fstsw       ax
        bt          ax, 2
        jnc         end_calculate
        call        goto_nextline
        mov         rax, SYS_WRITE
        mov         rbx, stdout
        mov         rcx, divide_by_zero
        mov         rdx, div_len
        int         80h
        jmp         exit

    end_calculate:
        fstp        qword[rsi]
        ffree       st0
        add         rsi, 8
        jmp         calculate_loop

    end_calculate_loop:
        ; retrieve registers' contents
        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret



print_result:
        ; save registers' contents
        push        rax
        push        rbx
        push        rcx
        push        rdx
        push        r8
        push        r9
        push        r10

        mov         r8, output
        mov         r9, output
        fstcw       word[oldcontrol]
        mov         ax, [oldcontrol]
        or          ax, 0x0c00
        mov         [newcontrol], ax
        fldcw       word[newcontrol]

        sub         rsi, 8
        fld         qword[rsi]
        fxam
        fstsw       ax
        clc
        bt          ax, 9
        jnc         generate_output
        clc
        mov         al, byte '-'
        mov         [r8], al
        inc         r8
        fchs
        inc         r9

    generate_output:
        fld         st0
        frndint
        fsub        st1, st0

        fistp       qword[fsig]
        mov         rax, [fsig]

    itoa_loop:
        xor         rdx, rdx
        div         qword[ten]
        add         dl, byte '0'
        mov         [r8], dl
        inc         r8
        cmp         rax, 0
        jne         itoa_loop

        fabs
        mov         r10, r8
        sub         r10, r9
        call        mirror
        fxam
        fstsw       ax
        sahf
        jz          isinteger
        mov         bl, byte '.'
        mov         [r8], bl
        inc         r8
        fild        qword[ten]
        fld1
        mov         rcx, 8

    precision_loop:
        fmul        st1
        loop        precision_loop

        fxch        st1
        fstp        st0
        mov         ax, [newcontrol]
        and         ax, 0xf3ff
        mov         [newcontrol], ax
        fldcw       word[newcontrol]
        fxch        st1

        fmul        st1
        frndint
        fistp       qword[fexp]
        ffree       st0
        ffree       st0
        ffree       st0
        ffree       st0
        mov         r9, r8
        mov         rax, [fexp]
        mov         rcx, 8

    ftoa_loop:
        xor         rdx, rdx
        div         qword[ten]
        add         dl, byte '0'
        mov         [r8], dl
        inc         r8
        loop        ftoa_loop
        call        mirror

    remove_trailing_zeros:
        dec         r8
        cmp         byte[r8], byte '0'
        jne         isinteger
        mov         byte[r8], 0
        jmp         remove_trailing_zeros

    isinteger:
        call        goto_nextline

        mov         rax, SYS_WRITE
        mov         rbx, stdout
        mov         rcx, output
        mov         rdx, max_size
        int         80h

    clear_output:
        mov         rcx, max_size
        xor         rdx, rdx
        mov         [num_len], rdx
        mov         r8, output

    clear_output_loop:
        mov         [r8], dl
        inc         r8
        loop        clear_output_loop

        add         rsi, 8

        ; retrieve registers' contents
        pop         r10
        pop         r9
        pop         r8
        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret



mirror:
        push        r8
        push        r9
        push        rdx
        push        rbx

        dec         r8

    mirror_while:
        cmp         r9, r8
        jge         end_mirror_while
        mov         bl, byte[r9]
        mov         dl, byte[r8]
        mov         [r9], dl
        mov         [r8], bl
        inc         r9
        dec         r8
        jmp         mirror_while

    end_mirror_while:
        pop         rbx
        pop         rdx
        pop         r9
        pop         r8
ret



extract_exp:
        fld         qword[rsi]
        fld         st0
        fldlg2
        fxch        st1            ; st2 = fvar, st1 = log_10(2), st0 = fvar
        fyl2x               ; log_10(fvar) = log_10(2) * log_2(fvar)
        frndint             ; truncate log_10(fvar)
        fst         qword[fexp]
        ; fsig = fvar / 10^(fexp)
        fldl2t              ; st2 = fvar, st1 = fexp, st0 = log_2(10)
        fmulp               ; m = log_2(10) * fexp
        fld         st0
        frndint             ; integral part of m
        fxch        st1            ; st2 = fvar, st1 = integer, st0 = m
        fsub        st0, st1       ; fractional part of m
        f2xm1
        fld1
        faddp               ; 2^(fraction)
        fscale              ; 10^fexp = 2^(integer) * 2^(fraction)
        fstp        st1            ; st1 = fvar, st0 = 10^fexp
        fdivp               ; fvar / 10^fexp
        fstp        qword[fsig]
ret



invalid_exp_err:
        ; save registers' contents
        push        rax
        push        rbx
        push        rcx
        push        rdx

        call        goto_nextline

        mov         rax, SYS_WRITE
        mov         rbx, stdout
        mov         rcx, errormsg
        mov         rdx, error_len
        int         80h

        mov         bx, erroroccured
        clc
        bts         [calc_flag], bx

        ; retrieve registers' contents
        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret



goto_nextline:
        ; save registers' contents
        push        rax
        push        rbx
        push        rcx
        push        rdx

        mov         rax, SYS_WRITE
        mov         rbx, stdout
        mov         rcx, new_line
        mov         rdx, new_line_len
        int         80h

        ; retrieve registers' contents
        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret



canonical_off:
        call        read_stdin_termios

        ; clear canonical bit in local mode flags
        push        rax
        mov         eax, ICANON
        not         eax
        and         [termios+12], eax
        pop         rax

        call        write_stdin_termios
ret



echo_off:
        call        read_stdin_termios

        ; clear echo bit in local mode flags
        push        rax
        mov         eax, ECHO
        not         eax
        and         [termios+12], eax
        pop         rax

        call        write_stdin_termios
ret



canonical_on:
        call        read_stdin_termios

        ; set canonical bit in local mode flags
        or          dword [termios+12], ICANON

        call        write_stdin_termios
ret



echo_on:
        call        read_stdin_termios

        ; set echo bit in local mode flags
        or          dword [termios+12], ECHO

        call        write_stdin_termios
ret



read_stdin_termios:
        push        rax
        push        rbx
        push        rcx
        push        rdx

        mov         eax, 36h
        mov         ebx, stdin
        mov         ecx, 5401h
        mov         edx, termios
        int         80h

        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret



write_stdin_termios:
        push        rax
        push        rbx
        push        rcx
        push        rdx

        mov         eax, 36h
        mov         ebx, stdin
        mov         ecx, 5402h
        mov         edx, termios
        int         80h

        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret

print_help:
        push        rax
        push        rbx
        push        rcx
        push        rdx

        mov         rax, SYS_WRITE
        mov         rbx, stdout
        mov         rcx, helpmsg
        mov         rdx, help_len
        int         80h

        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret


hello_world:
        push        rax
        push        rbx
        push        rcx
        push        rdx

        mov         rax, SYS_WRITE
        mov         rbx, stdout
        mov         rcx, hellomsg
        mov         rdx, hello_len
        int         80h

        pop         rdx
        pop         rcx
        pop         rbx
        pop         rax
ret