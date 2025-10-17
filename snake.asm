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
grow_flag:      .long  0
saved_apple_idx: .long  0
saved_head_x:   .long  0
saved_head_y:   .long  0

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

        /* Clamp: len>=2, len<=INNER_W/2, apples>=1 */
        movl    cur_len(%rip), %eax
        cmpl    $2, %eax
        jge     5f
        movl    $2, cur_len(%rip)
        jmp     6f
5:
        /* Make sure snake isn't too long for the board */
        movl    $INNER_W, %ecx
        shrl    $1, %ecx         /* INNER_W/2 */
        cmpl    %ecx, %eax
        jle     6f
        movl    %ecx, cur_len(%rip)
6:
        movl    apple_count(%rip), %eax
        cmpl    $1, %eax
        jge     7f
        movl    $1, apple_count(%rip)
7:
        /* apples >= 1 already handled; now cap to MAX_APPLES */
        movl    apple_count(%rip), %eax
        cmpl    $MAX_APPLES, %eax
        jle     8f
        movl    $MAX_APPLES, apple_count(%rip)
8:       
        /* Direction RIGHT, delay */
        movl    $DIR_RIGHT, cur_dir(%rip)
        movq    $START_DELAY, %rax
        movq    %rax, delay_us(%rip)

        /* Center head (inside field already for 60x20) */
        movl    $BOARD_W/2, %r8d               /* head x */
        movl    $BOARD_H/2, %r9d               /* head y */

        /* Build initial snake inside inner field, horizontal left */
        xorl    %ebx, %ebx
init_snake_loop:
        movl    cur_len(%rip), %eax
        cmpl    %eax, %ebx
        jge     init_snake_done

        /* x = headx - i */
        movl    %r8d, %edx
        subl    %ebx, %edx
        /* y = heady for every segment */
        movl    %r9d, %ecx

        /* write arrays */
        movl    %edx, (%r12,%rbx,4)
        movl    %ecx, (%r13,%rbx,4)

        /* draw head and body at init */
        movl    %edx, %edi
        movl    %ecx, %esi
        testl   %ebx, %ebx
        jne     1f
        movl    $CH_HEAD, %edx
        jmp     2f
1:
        movl    $CH_BODY, %edx
2:
        call    board_put_char

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

        /* snapshot OLD tail coords for proper erase / growth */
        movl    cur_len(%rip), %ecx
        decl    %ecx
        movl    (%r12,%rcx,4), %eax
        movl    %eax, tail_x(%rip)
        movl    (%r13,%rcx,4), %eax
        movl    %eax, tail_y(%rip)

        /* Self-collision? compare new head vs current body (skip index 0, the head) */
        movl    $1, %ebx
        movl    cur_len(%rip), %eax
        cmpl    %ebx, %eax
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

        /* Apples: set grow flag (in memory, not a volatile register) */
        movl    $0, grow_flag(%rip)
        xorl    %ebx, %ebx
        movl    apple_count(%rip), %eax
        testl   %eax, %eax
        jle     apples_done
apple_loop:
        movl    (%r14,%rbx,4), %ecx
        movl    (%r15,%rbx,4), %edx
        cmpl    %ecx, %edi
        jne     next_apple
        cmpl    %edx, %esi
        jne     next_apple

        incl    grow_flag(%rip)

        /* Save apple index and head position in memory for retry loop */
        movl    %ebx, saved_apple_idx(%rip)
        movl    %edi, saved_head_x(%rip)
        movl    %esi, saved_head_y(%rip)

        /* respawn inside inner area - retry until valid position */
respawn_retry:
        call    rand
        xorl    %edx, %edx
        movl    $INNER_W, %ecx
        divl    %ecx
        movl    %edx, %r9d
        incl    %r9d
        
        /* Save X on stack before second rand() which will clobber r9 */
        pushq   %r9

        call    rand
        xorl    %edx, %edx
        movl    $INNER_H, %ecx
        divl    %ecx
        movl    %edx, %r10d
        incl    %r10d
        
        /* Restore X coordinate */
        popq    %r9

        /* Check collision with new head position */
        movl    saved_head_x(%rip), %eax
        cmpl    %eax, %r9d
        jne     check_snake_body
        movl    saved_head_y(%rip), %eax
        cmpl    %eax, %r10d
        je      respawn_retry           /* Collision with head, retry */
        
check_snake_body:
        /* Check against current snake body positions */
        xorl    %ebx, %ebx
check_loop:
        movl    cur_len(%rip), %eax
        cmpl    %ebx, %eax
        jle     no_collision
        movl    (%r12,%rbx,4), %ecx
        movl    (%r13,%rbx,4), %edx
        cmpl    %ecx, %r9d
        jne     check_next
        cmpl    %edx, %r10d
        je      respawn_retry           /* Collision with body, retry */
check_next:
        incl    %ebx
        jmp     check_loop
        
no_collision:
        /* Valid position found - restore apple index and store */
        movl    saved_apple_idx(%rip), %ebx
        movl    %r9d,  (%r14,%rbx,4)
        movl    %r10d, (%r15,%rbx,4)

        /* Draw the new apple */
        movl    %r9d, %edi
        movl    %r10d, %esi
        movl    $CH_APPLE, %edx
        call    board_put_char
        
        /* Restore original head position for later use */
        movl    saved_head_x(%rip), %edi
        movl    saved_head_y(%rip), %esi

        /* speed up slightly */
        movq    delay_us(%rip), %rax
        subq    $DELTA_DELAY, %rax
        cmpq    $MIN_DELAY, %rax
        jge     sp_ok
        movq    $MIN_DELAY, %rax
sp_ok:  movq    %rax, delay_us(%rip)
next_apple:
        incl    %ebx
        /* rand/div clobber %eax, so reload the bound before comparing */
        movl    apple_count(%rip), %eax
        cmpl    %ebx, %eax
        jg      apple_loop
apples_done:

        /* --- Move & draw --- */

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

        /* draw previous head as body AFTER the shift
           (segment #1 now equals the old head) */
        movl    4(%r12), %edi          /* x = snake_x[1] */
        movl    4(%r13), %esi          /* y = snake_y[1] */
        movl    $CH_BODY, %edx
        call    board_put_char

        /* grow length if needed (append preserved tail once per apple eaten) */
        movl    grow_flag(%rip), %ebx
        testl   %ebx, %ebx
        je      no_grow
grow_loop:
        movl    cur_len(%rip), %eax
        cmpl    $MAX_SNAKE, %eax
        jge     grow_done_one
        incl    %eax
        movl    %eax, cur_len(%rip)

        leal    -1(%eax), %ecx          /* new last index */
        movl    tail_x(%rip), %edx
        movl    %edx, (%r12,%rcx,4)
        movl    tail_y(%rip), %edx
        movl    %edx, (%r13,%rcx,4)
grow_done_one:
        decl    %ebx
        testl   %ebx, %ebx
        jg      grow_loop
no_grow:

        /* erase OLD tail if not growing */
        cmpl    $0, grow_flag(%rip)
        jne     no_erase
        movl    tail_x(%rip), %edi
        movl    tail_y(%rip), %esi
        movl    $CH_EMPTY, %edx
        call    board_put_char
no_erase:

        /* write and draw NEW head from saved next_x/next_y */
        movl    next_x(%rip), %eax
        movl    %eax, (%r12)
        movl    next_y(%rip), %eax
        movl    %eax, (%r13)

        movl    next_x(%rip), %edi
        movl    next_y(%rip), %esi
        movl    $CH_HEAD, %edx
        call    board_put_char

        /* Sleep – pass 32-bit useconds_t cleanly */
        movl    delay_us(%rip), %edi
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
