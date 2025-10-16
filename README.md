# Snake Game - x86-64 Assembly Implementation

## Overview
A classic Snake game implementation written in x86-64 AT&T syntax assembly language for GNU Assembler (as), with ncurses helper functions provided by a C companion file.

## Features
- **Multiple Apples**: Support for up to 64 simultaneous apples on the board
- **Snake Growth**: Snake grows by one segment each time it eats an apple
- **Continuous Motion**: Snake moves continuously in the current direction
- **Arrow Key Controls**: Use arrow keys to change direction (no 180° reversals allowed)
- **Collision Detection**: 
        - Self-collision with body segments results in game over
        - Wall collision results in game over
- **Bordered Playfield**: '#' characters form a wall border around the playfield
- **Dynamic Speed**: Game speed increases slightly with each apple eaten
- **Centered Start**: Snake starts at the center of the board

## Constants
- **Board Dimensions**: 60×20 (including borders)
- **Inner Play Area**: 58×18 (excluding borders)
- **Maximum Snake Length**: Full board size (1200 segments)
- **Maximum Apples**: 64
- **Starting Delay**: 100ms between moves
- **Minimum Delay**: 30ms (maximum speed)
- **Speed Increment**: 5ms faster per apple

## Characters
- 'O' (79): Snake head
- 'o' (111): Snake body
- '*' (42): Apple
- ' ' (32): Empty space
- '#' (35): Wall/border

## Direction Codes
- 0: RIGHT
- 1: LEFT
- 2: UP
- 3: DOWN

## Main Function
### `start_game(int len, int n_apples)`
Initializes and runs the snake game.

**Parameters:**
- `len` (edi): Initial snake length (clamped to 2 ≤ len ≤ INNER_W/2)
- `n_apples` (esi): Number of apples on board (clamped to 1 ≤ n ≤ 64)

**Behavior:**
1. Initializes ncurses board
2. Draws wall borders
3. Creates initial snake (horizontal, facing right, centered)
4. Spawns initial apples randomly within inner play area
5. Enters main game loop:
         - Reads non-blocking keyboard input
         - Updates direction (preventing reversal)
         - Calculates new head position
         - Checks for wall collision
         - Checks for self-collision
         - Checks for apple collision (triggers growth and respawn)
         - Shifts body segments
         - Erases old tail (unless growing)
         - Draws new head and body
         - Sleeps for current delay period

**Exit Conditions:**
- Wall collision
- Self-collision
- Explicit call to `game_exit()`

## Data Structures
- **snake_x[MAX_SNAKE]**: Array of x-coordinates for each snake segment
- **snake_y[MAX_SNAKE]**: Array of y-coordinates for each snake segment
- **apples_x[MAX_APPLES]**: Array of x-coordinates for each apple
- **apples_y[MAX_APPLES]**: Array of y-coordinates for each apple
- **cur_len**: Current snake length
- **cur_dir**: Current direction
- **apple_count**: Number of active apples
- **delay_us**: Current delay in microseconds between moves

## External Dependencies
- `board_init()`: Initialize ncurses display
- `game_exit()`: Clean up and exit game
- `board_get_key()`: Non-blocking keyboard input (-1 if no key)
- `board_put_char(x, y, char)`: Draw character at position
- `board_put_str()`: Draw string (unused in this implementation)
- `rand()`: Random number generation for apple placement
- `usleep(usec)`: Sleep for specified microseconds

## Notes
- Uses position-independent code (PIE) with RIP-relative addressing
- Maintains 16-byte stack alignment for System V ABI compliance
- Initial snake is placed horizontally extending left from center
- Apples respawn at random locations when eaten
- Game speed is capped at MIN_DELAY (30ms)