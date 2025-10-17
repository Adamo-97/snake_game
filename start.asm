.intel_syntax noprefix
.text
.globl _start
.type  _start,@function
.extern start_game

# tiny atoi: accepts optional '+' and digits
atoi:
    xor     eax, eax
    mov     rdx, rdi
    mov     bl, '+'
    cmp     byte ptr [rdx], bl
    jne     .atoi_loop
    inc     rdx
.atoi_loop:
    movzx   ecx, byte ptr [rdx]
    test    ecx, ecx
    je      .atoi_done
    mov     edi, ecx
    sub     edi, '0'
    cmp     edi, 9
    ja      .atoi_done
    lea     eax, [rax + 4*rax]   # acc *= 10
    lea     eax, [rdi + 2*rax]   # acc += digit
    inc     rdx
    jmp     .atoi_loop
.atoi_done:
    ret

_start:
    and     rsp, -16             # align stack

    mov     rcx, [rsp]           # argc
    lea     r8,  [rsp+8]         # &argv[0]

    # defaults
    mov     edi, 5               # len
    mov     esi, 2               # apples

    # if argc > 1: argv[1] -> len
    cmp     rcx, 1
    jle     .have_len
    mov     rdi, [r8+8]
    call    atoi
    mov     edi, eax
.have_len:

    # if argc > 2: argv[2] -> apples
    cmp     rcx, 2
    jle     .have_apples
    mov     rdi, [r8+16]
    call    atoi
    mov     esi, eax
.have_apples:

    call    start_game           # start_game(int len, int apples)

    mov     eax, 60              # exit(0)
    xor     edi, edi
    syscall

.size _start, .-_start
