/* Snake in x86-64 AT&T syntax for GNU as + helpers.c (ncurses)
 * - Multiple apples, growth on eat
 * - Continuous motion, arrows, no reverse
 * - Self-collision => die
 * - # border; die on wall (inner field 1..W-2 x 1..H-2)
 * - Start centered
 * - Small speed-up each apple
 */

        .att_syntax

/* ------------------------------ Constants ------------------------------ */
        .equ    BOARD_W, 60
        .equ    BOARD_H, 20
        .equ    MAX_SNAKE, (BOARD_W*BOARD_H)
        .equ    MAX_APPLES, 64

        .equ    DIR_RIGHT, 0
        .equ    DIR_LEFT,  1
        .equ    DIR_UP,    2
        .equ    DIR_DOWN,  3

        .equ    CH_HEAD,  79     /* 'O' */
        .equ    CH_BODY, 111     /* 'o' */
        .equ    CH_APPLE, 42     /* '*' */
        .equ    CH_EMPTY, 32     /* ' ' */
        .equ    CH_WALL,  35     /* '#' */

        .equ    START_DELAY, 100000   /* microseconds */
        .equ    MIN_DELAY,     30000
        .equ    DELTA_DELAY,    5000

        .equ    INNER_W, (BOARD_W-2)
        .equ    INNER_H, (BOARD_H-2)

/* ------------------------------ Externs ------------------------------ */
        .extern board_init
        .extern game_exit
        .extern board_get_key
        .extern board_put_char
        .extern board_put_str
        .extern rand
        .extern usleep

/* ------------------------------ Storage ------------------------------ */
        .bss
        .align 4
        .lcomm snake_x, 4*MAX_SNAKE
        .lcomm snake_y, 4*MAX_SNAKE
        .lcomm apples_x, 4*MAX_APPLES
        .lcomm apples_y, 4*MAX_APPLES

        .data
        .align 8
cur_len:        .long  0
cur_dir:        .long  0
apple_count:    .long  0
delay_us:       .quad  0
next_x:         .long  0
next_y:         .long  0
old_x:          .long  0
old_y:          .long  0
tail_x:         .long  0
tail_y:         .long  0

/* ------------------------------ Code ------------------------------ */
        .text
        .p2align 4,,15
        .globl  start_game
        .type   start_game,@function

/* void start_game(int len, int n_apples) */
start_game:
        /* Prologue (keep 16B alignment for every 'call') */
        pushq   %rbp
        movq    %rsp, %rbp
        pushq   %rbx
        pushq   %r12
        pushq   %r13
        pushq   %r14
        pushq   %r15
        subq    $8, %rsp

        /* Save args */
        movl    %edi, cur_len(%rip)
        movl    %esi, apple_count(%rip)

        /* RIP-relative bases (PIE safe) */
        leaq    snake_x(%rip), %r12
        leaq    snake_y(%rip), %r13
        leaq    apples_x(%rip), %r14
        leaq    apples_y(%rip), %r15

        /* Init board */
        call    board_init

        /* ---------- Draw # border ---------- */
        xorl    %ebx, %ebx                     /* x = 0 */
1:      cmpl    $BOARD_W, %ebx
        jge     2f
        movl    %ebx, %edi                     /* top y=0 */
        xorl    %esi, %esi
        movl    $CH_WALL, %edx
        call    board_put_char
        movl    %ebx, %edi                     /* bottom y=H-1 */
        movl    $BOARD_H-1, %esi
        movl    $CH_WALL, %edx
        call    board_put_char
        incl    %ebx
        jmp     1b
2:
        movl    $1, %ebx                       /* y = 1..H-2 */
3:      cmpl    $BOARD_H-1, %ebx
        jge     4f
        xorl    %edi, %edi                     /* x=0 */
        movl    %ebx, %esi
        movl    $CH_WALL, %edx
        call    board_put_char
        movl    $BOARD_W-1, %edi               /* x=W-1 */
        movl    %ebx, %esi
        movl    $CH_WALL, %edx
        call    board_put_char
        incl    %ebx
        jmp     3b
4:
        /* ---------------------------------- */

        /* Clamp: len>=2, apples>=1 */
        movl    cur_len(%rip), %eax
        cmpl    $2, %eax
        jge     5f
        movl    $2, cur_len(%rip)
5:
        movl    apple_count(%rip), %eax
        cmpl    $1, %eax
        jge     6f
        movl    $1, apple_count(%rip)
6:

        /* Direction RIGHT, delay */
        movl    $DIR_RIGHT, cur_dir(%rip)
        movq    $START_DELAY, %rax
        movq    %rax, delay_us(%rip)

        /* Center head (inside field already for 60x20) */
        movl    $BOARD_W/2, %r8d
        movl    $BOARD_H/2, %r9d

        /* Build initial snake inside inner field, horizontal left */
        xorl    %ebx, %ebx
init_snake_loop:
        movl    cur_len(%rip), %eax
        cmpl    %eax, %ebx
        jge     init_snake_done

        /* x = 1 + ((headx-1 - i) mod INNER_W) */
        movl    %r8d, %edx
        decl    %edx
        subl    %ebx, %edx
        movl    $INNER_W, %ecx
        movl    %edx, %eax
        cltd
        idivl   %ecx                 /* eax=quot, edx=rem (-INNER_W<rem<INNER_W) */
        movl    %edx, %edx
        cmpl    $0, %edx
        jge     7f
        addl    %ecx, %edx
7:      incl    %edx                 /* 1..INNER_W */

        movl    %r9d, %ecx           /* y = heady */

        movl    %edx, (%r12,%rbx,4)
        movl    %ecx, (%r13,%rbx,4)

        cmpl    $0, %ebx
        jne     8f
        movl    %edx, %edi           /* head */
        movl    %ecx, %esi
        movl    $CH_HEAD, %edx
        call    board_put_char
        jmp     9f
8:      movl    %edx, %edi           /* body */
        movl    %ecx, %esi
        movl    $CH_BODY, %edx
        call    board_put_char
9:
        incl    %ebx
        jmp     init_snake_loop
init_snake_done:

        /* Spawn apples in inner area */
        xorl    %ebx, %ebx
spawn_apples_loop:
        movl    apple_count(%rip), %eax
        cmpl    %eax, %ebx
        jge     spawn_apples_done

        call    rand
        xorl    %edx, %edx
        movl    $INNER_W, %ecx
        divl    %ecx
        movl    %edx, %r10d
        incl    %r10d                           /* 1..INNER_W */

        call    rand
        xorl    %edx, %edx
        movl    $INNER_H, %ecx
        divl    %ecx
        movl    %edx, %r11d
        incl    %r11d                           /* 1..INNER_H */

        movl    %r10d, (%r14,%rbx,4)
        movl    %r11d, (%r15,%rbx,4)

        movl    %r10d, %edi
        movl    %r11d, %esi
        movl    $CH_APPLE, %edx
        call    board_put_char

        incl    %ebx
        jmp     spawn_apples_loop
spawn_apples_done:

/* ------------------------------ Main loop ------------------------------ */
game_loop:
        /* Non-blocking key */
        call    board_get_key
        cmpl    $-1, %eax
        je      keep_dir

        /* Update direction, forbid reverse */
        movl    cur_dir(%rip), %r8d
        cmpl    $261, %eax          /* Right */
        jne     Lleft
        cmpl    $DIR_LEFT, %r8d
        je      keep_dir
        movl    $DIR_RIGHT, cur_dir(%rip)
        jmp     have_dir
Lleft:  cmpl    $260, %eax          /* Left */
        jne     Lup
        cmpl    $DIR_RIGHT, %r8d
        je      keep_dir
        movl    $DIR_LEFT, cur_dir(%rip)
        jmp     have_dir
Lup:    cmpl    $259, %eax          /* Up */
        jne     Ldown
        cmpl    $DIR_DOWN, %r8d
        je      keep_dir
        movl    $DIR_UP, cur_dir(%rip)
        jmp     have_dir
Ldown:  cmpl    $258, %eax          /* Down */
        jne     have_dir
        cmpl    $DIR_UP, %r8d
        je      keep_dir
        movl    $DIR_DOWN, cur_dir(%rip)
keep_dir:
have_dir:
        /* dx,dy */
        movl    cur_dir(%rip), %eax
        xorl    %r9d, %r9d
        xorl    %r10d, %r10d
        cmpl    $DIR_RIGHT, %eax
        jne     Dleft
        movl    $1, %r9d
        jmp     got_dxy
Dleft:  cmpl    $DIR_LEFT, %eax
        jne     Dup
        movl    $-1, %r9d
        jmp     got_dxy
Dup:    cmpl    $DIR_UP, %eax
        jne     Ddown
        movl    $-1, %r10d
        jmp     got_dxy
Ddown:  movl    $1, %r10d
got_dxy:

        /* --- Snapshot state BEFORE any modification --- */
        /* old head */
        movl    (%r12), %r11d
        movl    (%r13), %r8d
        movl    %r11d, old_x(%rip)
        movl    %r8d,  old_y(%rip)

        /* compute new head; die on wall */
        movl    %r11d, %edi
        addl    %r9d, %edi
        movl    %r8d,  %esi
        addl    %r10d, %esi

        cmpl    $1, %edi
        jl      hit_wall
        cmpl    $BOARD_W-2, %edi
        jg      hit_wall
        cmpl    $1, %esi
        jl      hit_wall
        cmpl    $BOARD_H-2, %esi
        jg      hit_wall
        jmp     ok_wall
hit_wall:
        call    game_exit
ok_wall:
        /* save new head now */
        movl    %edi, next_x(%rip)
        movl    %esi, next_y(%rip)

        /* snapshot OLD tail coords for proper erase */
        movl    cur_len(%rip), %ecx
        decl    %ecx
        movl    (%r12,%rcx,4), %eax
        movl    %eax, tail_x(%rip)
        movl    (%r13,%rcx,4), %eax
        movl    %eax, tail_y(%rip)

        /* Self-collision? compare new head vs current body */
        xorl    %ebx, %ebx
        movl    cur_len(%rip), %eax
        jle     no_self
self_loop:
        movl    (%r12,%rbx,4), %ecx
        movl    (%r13,%rbx,4), %edx
        cmpl    %ecx, %edi
        jne     self_next
        cmpl    %edx, %esi
        jne     self_next
        call    game_exit
self_next:
        incl    %ebx
        cmpl    %ebx, %eax
        jg      self_loop
no_self:

        /* Apples: set grow flag r11d */
        xorl    %r11d, %r11d
        xorl    %ebx, %ebx
        movl    apple_count(%rip), %eax
        jle     apples_done
apple_loop:
        movl    (%r14,%rbx,4), %ecx
        movl    (%r15,%rbx,4), %edx
        cmpl    %ecx, %edi
        jne     next_apple
        cmpl    %edx, %esi
        jne     next_apple

        movl    $1, %r11d                   /* eaten */

        /* respawn inside inner area */
        call    rand
        xorl    %edx, %edx
        movl    $INNER_W, %ecx
        divl    %ecx
        movl    %edx, %r9d
        incl    %r9d

        call    rand
        xorl    %edx, %edx
        movl    $INNER_H, %ecx
        divl    %ecx
        movl    %edx, %r10d
        incl    %r10d

        movl    %r9d,  (%r14,%rbx,4)
        movl    %r10d, (%r15,%rbx,4)

        movl    %r9d, %edi
        movl    %r10d, %esi
        movl    $CH_APPLE, %edx
        call    board_put_char

        /* speed up slightly */
        movq    delay_us(%rip), %rax
        subq    $DELTA_DELAY, %rax
        cmpq    $MIN_DELAY, %rax
        jge     sp_ok
        movq    $MIN_DELAY, %rax
sp_ok:  movq    %rax, delay_us(%rip)
        jmp     apples_done
next_apple:
        incl    %ebx
        cmpl    %ebx, %eax
        jg      apple_loop
apples_done:

        /* --- Move & draw --- */

        /* erase OLD tail if not growing (uses snapshotted tail_x/tail_y) */
        testl   %r11d, %r11d
        jne     no_erase
        movl    tail_x(%rip), %edi
        movl    tail_y(%rip), %esi
        movl    $CH_EMPTY, %edx
        call    board_put_char
no_erase:

        /* draw OLD head as body 'o' */
        movl    old_x(%rip), %edi
        movl    old_y(%rip), %esi
        movl    $CH_BODY, %edx
        call    board_put_char

        /* shift body right: k=len-1..1 */
        movl    cur_len(%rip), %ecx
        decl    %ecx
shift_loop:
        cmpl    $1, %ecx
        jl      shift_done
        movl    -4(%r12,%rcx,4), %eax
        movl    %eax, (%r12,%rcx,4)
        movl    -4(%r13,%rcx,4), %eax
        movl    %eax, (%r13,%rcx,4)
        decl    %ecx
        jmp     shift_loop
shift_done:

        /* grow length if needed */
        testl   %r11d, %r11d
        je      no_grow
        movl    cur_len(%rip), %eax
        cmpl    $MAX_SNAKE, %eax
        jge     no_grow
        incl    %eax
        movl    %eax, cur_len(%rip)
no_grow:

        /* write and draw NEW head from saved next_x/next_y */
        movl    next_x(%rip), %eax
        movl    %eax, (%r12)
        movl    next_y(%rip), %eax
        movl    %eax, (%r13)

        movl    next_x(%rip), %edi
        movl    next_y(%rip), %esi
        movl    $CH_HEAD, %edx
        call    board_put_char

        /* Sleep */
        movq    delay_us(%rip), %rdi
        call    usleep

        jmp     game_loop

        /* (Not reached) */
        addq    $8, %rsp
        popq    %r15
        popq    %r14
        popq    %r13
        popq    %r12
        popq    %rbx
        popq    %rbp
        ret

        .size   start_game, .-start_game
