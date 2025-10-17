# Snake Game - x86-64 Assembly Implementation

## Overview
A classic Snake game implementation written in x86-64 AT&T syntax assembly language for GNU Assembler (as), with ncurses helper functions provided by a C companion file.

This implementation meets all core requirements and includes two extra features:
1. **Speed Increase** - Game accelerates as snake eats apples 
2. **Apple Collision Avoidance** - Apples never spawn on snake 

## Features (Code References)

### Core Features (Required)
- **Multiple Apples**: Support for up to 64 simultaneous apples on the board
  - *Code: `snake.asm` lines 7, 41-42 (MAX_APPLES constant and arrays)*
  
- **Snake Growth**: Snake grows by one segment each time it eats an apple
  - *Code: `snake.asm` lines 450-467 (grow_loop section)*
  
- **Continuous Motion**: Snake moves continuously in the current direction
  - *Code: `snake.asm` lines 223-255 (input handling with direction persistence)*
  
- **Arrow Key Controls**: Use arrow keys to change direction (no 180° reversals allowed)
  - *Code: `snake.asm` lines 229-254 (direction change with reverse prevention)*
  - Key codes: Up=259, Down=258, Left=260, Right=261
  
- **Collision Detection**: 
  - Self-collision with body segments → game over
    - *Code: `snake.asm` lines 310-328 (self_loop section)*
  - Wall collision → game over
    - *Code: `snake.asm` lines 287-300 (boundary checks and hit_wall)*
  
- **Bordered Playfield**: '#' characters form a wall border around the playfield
  - *Code: `snake.asm` lines 86-113 (border drawing)*
  
- **Centered Start**: Snake starts at the center of the board
  - *Code: `snake.asm` lines 153-154 (BOARD_W/2, BOARD_H/2)*

### Extra Features 

#### 1. Dynamic Speed Increase 
Game speed increases slightly with each apple eaten, making the game progressively more challenging.
- **Implementation**: `snake.asm` lines 413-420
- **Logic**: 
  - Initial delay: `START_DELAY` (100,000 µs = 100ms)
  - Decrease: `DELTA_DELAY` (5,000 µs = 5ms) per apple
  - Minimum: `MIN_DELAY` (30,000 µs = 30ms)
  
```asm
movq    delay_us(%rip), %rax
subq    $DELTA_DELAY, %rax
cmpq    $MIN_DELAY, %rax
jge     sp_ok
movq    $MIN_DELAY, %rax
sp_ok:  movq    %rax, delay_us(%rip)
```

#### 2. Apple Collision Avoidance 
Apples never spawn on the snake's body or head position, ensuring they're always visible and collectible.
- **Implementation**: `snake.asm` lines 346-395
- **Logic**:
  1. Save apple index and head position (lines 349-351)
  2. Generate random position using `rand()` (lines 354-368)
  3. Check collision with new head position (lines 371-378)
  4. Check collision with all snake body segments (lines 380-395)
  5. If collision detected, retry from step 2
  6. If valid, store and draw the apple (lines 399-408)

```asm
respawn_retry:
    call    rand
    # ... generate position in %r9d, %r10d ...
    
    # Check against head
    cmpl    saved_head_x(%rip), %r9d
    jne     check_snake_body
    cmpl    saved_head_y(%rip), %r10d
    je      respawn_retry
    
check_snake_body:
    # Loop through all snake segments
    # Jump to respawn_retry if collision found
```

## Constants (Code References)
*Defined in `snake.asm` lines 4-24*

- **Board Dimensions**: 60×20 (including borders) - `BOARD_W`, `BOARD_H`
- **Inner Play Area**: 58×18 (excluding borders) - `INNER_W`, `INNER_H`
- **Maximum Snake Length**: Full board size (1200 segments) - `MAX_SNAKE`
- **Maximum Apples**: 64 - `MAX_APPLES`
- **Starting Delay**: 100ms between moves - `START_DELAY` (100000 µs)
- **Minimum Delay**: 30ms (maximum speed) - `MIN_DELAY` (30000 µs)
- **Speed Increment**: 5ms faster per apple - `DELTA_DELAY` (5000 µs)

## Characters (Code References)
*Defined in `snake.asm` lines 14-18*

- 'O' (79): Snake head - `CH_HEAD`
- 'o' (111): Snake body - `CH_BODY`
- '*' (42): Apple - `CH_APPLE`
- ' ' (32): Empty space - `CH_EMPTY`
- '#' (35): Wall/border - `CH_WALL`

## Direction Codes (Code References)
*Defined in `snake.asm` lines 9-12*

- 0: RIGHT - `DIR_RIGHT`
- 1: LEFT - `DIR_LEFT`
- 2: UP - `DIR_UP`
- 3: DOWN - `DIR_DOWN`

## Data Structures (Code References)

### Arrays (`snake.asm` lines 38-42)
```asm
.lcomm snake_x, 4*MAX_SNAKE    # X coordinates of snake segments
.lcomm snake_y, 4*MAX_SNAKE    # Y coordinates of snake segments
.lcomm apples_x, 4*MAX_APPLES  # X coordinates of apples
.lcomm apples_y, 4*MAX_APPLES  # Y coordinates of apples
```

### State Variables (`snake.asm` lines 47-59)
```asm
cur_len:         .long  0  # Current snake length
cur_dir:         .long  0  # Current direction (0-3)
apple_count:     .long  0  # Number of apples on screen
delay_us:        .quad  0  # Current delay in microseconds
next_x:          .long  0  # Next head X position
next_y:          .long  0  # Next head Y position
old_x:           .long  0  # Previous head X position
old_y:           .long  0  # Previous head Y position
tail_x:          .long  0  # Current tail X position
tail_y:          .long  0  # Current tail Y position
grow_flag:       .long  0  # Number of segments to grow
saved_apple_idx: .long  0  # Temporary: apple index during respawn
saved_head_x:    .long  0  # Temporary: head X during respawn
saved_head_y:    .long  0  # Temporary: head Y during respawn
```

## Main Functions (Code References)

### `start_game(int len, int n_apples)` 
*Defined in `snake.asm` lines 68-512*

Initializes and runs the snake game. Complies with C calling convention.

**Parameters:**
- `len` (%edi): Initial snake length (clamped to 2 ≤ len ≤ INNER_W/2)
- `n_apples` (%esi): Number of apples on board (clamped to 1 ≤ n ≤ 64)

**Register Usage:**
- %r12: Base pointer to `snake_x` array
- %r13: Base pointer to `snake_y` array
- %r14: Base pointer to `apples_x` array
- %r15: Base pointer to `apples_y` array
- Callee-saved registers preserved: %rbx, %rbp, %r12-r15

**Execution Flow:**

1. **Initialization** (lines 70-218):
   - Function prologue with stack alignment (lines 70-77)
   - Save parameters (lines 79-80)
   - Initialize ncurses via `board_init()` (line 83)
   - Draw border walls (lines 86-113)
   - Validate and clamp parameters (lines 116-145)
   - Set initial direction and speed (lines 148-150)
   - Create initial snake at center (lines 156-186)
   - Spawn initial apples (lines 189-218)

2. **Game Loop** (lines 223-498):
   
   a. **Input Handling** (lines 223-255):
      - `board_get_key()` for non-blocking input
      - Update direction with reverse prevention
      - Example: Can't go LEFT while moving RIGHT
   
   b. **Movement Calculation** (lines 258-273):
      - Compute dx, dy based on `cur_dir`
      - Calculate new head position: `(old_x + dx, old_y + dy)`
   
   c. **Collision Detection**:
      - **Wall Check** (lines 287-300):
        ```asm
        cmpl    $1, %edi           # Check left wall
        jl      hit_wall
        cmpl    $BOARD_W-2, %edi   # Check right wall
        jg      hit_wall
        # ... similar for top/bottom
        ```
      - **Self-Collision** (lines 310-328):
        ```asm
        self_loop:
            # Compare new head vs each body segment
            cmpl    %ecx, %edi
            jne     self_next
            cmpl    %edx, %esi
            jne     self_next
            call    game_exit      # Die on collision
        ```
   
   d. **Apple Detection & Respawn** (lines 330-423):
      - Check each apple position (lines 336-342)
      - If eaten: increment `grow_flag`, respawn apple (lines 343-408)
      - Speed increase after eating (lines 413-420)
   
   e. **Snake Movement** (lines 426-476):
      - Shift body segments (lines 429-440):
        ```asm
        shift_loop:
            movl    -4(%r12,%rcx,4), %eax
            movl    %eax, (%r12,%rcx,4)  # Copy segment[i-1] to segment[i]
        ```
      - Draw old head as body (lines 443-447)
      - Handle growth (lines 450-467)
      - Erase old tail if not growing (lines 470-475)
      - Write and draw new head (lines 478-484)
   
   f. **Frame Delay** (lines 487-488):
      - `usleep(delay_us)` for animation timing

**Exit Conditions:**
- Wall collision → `game_exit()` at line 300
- Self-collision → `game_exit()` at line 323
- Never returns to caller (infinite game loop)

### `_start(void)`
*Defined in `start.asm` lines 5-12*

Assembly entry point for standalone executable. Calls `start_game(5, 2)` with hardcoded parameters.

```asm
_start:
    andq    $-16, %rsp        # Align stack to 16 bytes
    movl    $5, %edi          # Length = 5
    movl    $2, %esi          # Apples = 2
    call    start_game
    movl    $60, %eax         # sys_exit
    xorl    %edi, %edi        # exit code 0
    syscall
```

## Game Loop Architecture (Detailed)

### Main Loop Structure (`snake.asm` lines 223-498)

```
┌─────────────────────────────────────┐
│    1. Get Keyboard Input            │  (lines 223-227)
│    board_get_key() → %eax           │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│    2. Update Direction              │  (lines 229-255)
│    - Check key code                 │
│    - Prevent reverse movement       │
│    - Update cur_dir                 │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│    3. Calculate Movement            │  (lines 258-273)
│    - Get dx, dy from direction      │
│    - new_pos = old_pos + (dx, dy)   │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│    4. Wall Collision Check          │  (lines 287-300)
│    if (x < 1 || x > W-2 ||          │
│        y < 1 || y > H-2)            │
│        → game_exit()                │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│    5. Self Collision Check          │  (lines 310-328)
│    for each body segment:           │
│        if (head == segment)         │
│            → game_exit()            │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│    6. Apple Collision & Respawn     │  (lines 330-423)
│    for each apple:                  │
│        if (head == apple):          │
│            grow_flag++              │
│            respawn with collision   │
│            speed increase           │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│    7. Move Snake Body               │  (lines 426-476)
│    - Shift segments                 │
│    - Draw old head as body          │
│    - Append tail if growing         │
│    - Erase old tail if not growing  │
│    - Draw new head                  │
└─────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────┐
│    8. Frame Delay                   │  (lines 487-488)
│    usleep(delay_us)                 │
└─────────────────────────────────────┘
                  ↓
         (Loop back to step 1)
```

## External Dependencies (Helper Functions)
*Implemented in `helpers.c`*

### `void board_init(void)`
Initialize ncurses display system.
- Sets up window
- Initializes random number generator with `srand(time(0))`
- Configures: no echo, no cursor, non-blocking input

### `void game_exit(void)`
Clean up and exit game.
- Closes ncurses window
- Restores terminal state
- Calls `exit(0)`

### `int board_get_key(void)`
Non-blocking keyboard input.
- Returns: Key code (258-261 for arrows, 'a'-'z' for letters, -1 if no key)
- Called every game loop iteration

### `void board_put_char(int x, int y, int ch)`
Draw single character at position.
- Parameters: x, y coordinates (0,0 = top-left), ASCII character
- Immediately refreshes display
- Used for drawing snake, apples, walls

### `void board_put_str(int x, int y, const char *str)`
Draw string at position.
- Parameters: x, y coordinates, null-terminated string
- Useful for debug output (not used in final version)

### `int rand(void)` (from libc)
Generate random number.
- Returns: Random integer
- Used for apple placement: `rand() % INNER_W` for X coordinate

### `void usleep(unsigned long usec)` (from libc)
Sleep for microseconds.
- Parameters: Microseconds to sleep
- Used for game animation timing

## Build System (Code References)

### Makefile Targets
*File: `Makefile`*

```makefile
# Build both versions
make

# C entry point version (via main.c)
make snake_asm

# Assembly entry point version (via start.asm)  
make snake_asm_start

# Clean all build artifacts
make clean
```

### Compilation Process

**C Entry Version** (`snake_asm`):
```bash
gcc -Os -Wall -g -c main.c         # Compile C wrapper
as -gstabs snake.asm -o snake.o    # Assemble game logic
gcc -Os -Wall -g -c helpers.c      # Compile helpers
gcc main.o snake.o helpers.o -lncurses -o snake_asm
```

**Assembly Entry Version** (`snake_asm_start`):
```bash
as -gstabs start.asm -o start.o    # Assemble entry point
as -gstabs snake.asm -o snake.o    # Assemble game logic
as -gstabs workaround.asm -o workaround.o  # Linker compatibility
gcc -nostdlib -no-pie -Wl,-e,_start start.o snake.o helpers.o workaround.o -lc -lncurses -o snake_asm_start
```

**Note**: `workaround.asm` provides dummy `__progname` and `environ` symbols required when linking without standard startup code.

## Usage

### Running the Game

**With C entry point:**
```bash
./snake_asm <length> <apples>
```
Examples:
- `./snake_asm 5 2` - Snake of length 5, 2 apples
- `./snake_asm 10 5` - Snake of length 10, 5 apples
- `./snake_asm 3 1` - Minimum configuration

**With assembly entry point:**
```bash
./snake_asm_start
```
- Hardcoded to length=5, apples=2 (modify `start.asm` to change)

### Controls
- **↑** (Up Arrow): Move up
- **↓** (Down Arrow): Move down
- **←** (Left Arrow): Move left  
- **→** (Right Arrow): Move right
- **Ctrl+C**: Exit game

### Gameplay
1. Snake starts at center, moving right
2. Use arrow keys to change direction
3. Eat apples (*) to grow and increase speed
4. Avoid walls (#) and your own body (o)
5. Game ends on collision

## Technical Details

### Assembly Conventions
- **Syntax**: AT&T (`.att_syntax` directive)
- **Architecture**: x86-64 (64-bit)
- **Assembler**: GNU as (gas)
- **ABI**: System V AMD64 (for C interoperability)

### Stack Alignment
Maintains 16-byte alignment per System V ABI:
```asm
start_game:
    pushq   %rbp           # Save frame pointer
    movq    %rsp, %rbp     # Set up frame
    pushq   %rbx           # Save callee-saved regs
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    subq    $8, %rsp       # Align to 16 bytes (7 pushes + 1)
```

### Position-Independent Code (PIE)
Uses RIP-relative addressing for all data accesses:
```asm
movl    cur_len(%rip), %eax     # Load cur_len
movq    delay_us(%rip), %rax    # Load delay_us
```

### Critical Bug Fixes (Development Notes)

During development, three critical bugs were identified and fixed:

1. **rand() clobbering %r9**: 
   - Problem: Second `rand()` call destroyed X coordinate
   - Solution: Save/restore %r9 around second call (line 362)

2. **rand() clobbering %rdi/%rsi**:
   - Problem: Lost head position during apple respawn
   - Solution: Save head position in memory variables (lines 349-351)

3. **Stack imbalance in retry loop**:
   - Problem: Complex push/pop sequences caused segfaults
   - Solution: Simplified using memory storage for retry logic

## File Structure

```
snake_game/
├── snake.asm           # Main game logic (511 lines, x86-64 assembly)
├── start.asm           # Assembly entry point (_start symbol)
├── main.c              # C entry point wrapper
├── helpers.c           # ncurses helper functions
├── workaround.asm      # Linker compatibility symbols
├── Makefile            # Build configuration
├── SUBMISSION.txt      # Assignment submission report
├── README.md           # This file (detailed documentation)
└── snake.gdb           # GDB debugging script (original)
```

## Testing & Validation

The game has been tested with:
- Snake lengths: 2 to 29 (maximum for 60x20 board)
- Apple counts: 1 to 64
- All movement directions and combinations
- Collision detection (walls and self)
- Apple respawning with collision avoidance
- Speed increase mechanics
- Extended gameplay (multiple apples eaten)
- Memory safety (no segmentation faults)

## Requirements Compliance

### Core Requirements ✓
- ✅ Implemented in x86-64 assembly (AT&T syntax)
- ✅ GNU as assembler compatible
- ✅ Playable snake game
- ✅ Configurable apples via command-line
- ✅ Snake growth on eating apples
- ✅ Arrow key controls (no reverse)
- ✅ Self-collision detection
- ✅ Wall collision detection  
- ✅ Random apple placement
- ✅ Apple respawning
- ✅ Centered start position
- ✅ C calling convention compliance
- ✅ Compilable with provided Makefile
- ✅ Dual entry points (C and assembly)

### Extra Features ✓
- ✅ Speed increase 
- ✅ Apple collision avoidance 