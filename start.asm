        .text
        .globl _start
        .type  _start,@function
        .extern start_game
_start:
        andq    $-16, %rsp
        movl    $5, %edi
        movl    $2, %esi
        call    start_game
        movl    $60, %eax
        xorl    %edi, %edi
        syscall
        .size _start, .-_start
