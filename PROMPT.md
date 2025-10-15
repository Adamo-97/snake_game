**Prompt:**
Implement a playable **Snake** game **entirely in x86-64 assembly (AT&T syntax)** for **Linux (Fedora)** using **GNU as**, **gcc** (for linking), **make**, and **ncurses**.

**Build/Run**

* Tools: GNU as, gcc, make, ncurses (`sudo dnf install ncurses-devel`).
* Compile with the provided/updated **Makefile**.
* Run: `./snake <len> <n_apples>` (e.g., `./snake 5 2`).

**Interfaces (must follow System V AMD64 C calling convention)**

* In **snake.asm**:
  `void start_game(int len, int n_apples);`
* In **start.asm**:
  `_start(void)` → calls `start_game` with reasonable defaults.
* Must be startable from C **and** directly (avoid `_start` collision by keeping it in a separate file from the C-linked build).

**Provided C functions (callable from assembly)**

* `void board_init();` — init ncurses/window/RNG (call first).
* `void game_exit();` — cleanup and exit on game end.
* `int board_get_key();` — returns key or `-1`. Key codes:
  `258` Down, `259` Up, `260` Left, `261` Right, `'a'..'z'`, `-1` none.
* `void board_put_char(int x,int y,int ch);`
* `void board_put_str(int x,int y,const char *str);`
* You may also call libc: `int rand();` and `void usleep(unsigned long usec);`

**Game Requirements**

* Playable Snake with **>1 apples** configurable via CLI arg.
* Snake **grows** on eating an apple.
* Control via **arrow keys**; if no key pressed, **continue moving** in last direction; **cannot reverse** into itself.
* **Self-collision = death**.
* Hitting field edge: choose **either** (a) **die** and end, **or** (b) **wrap** to the opposite side. Implement one behavior consistently.
* Apples at **random positions**; when eaten, **respawn** a new apple. You **do not need** to handle apples spawning on the snake body (only head eats).
* Board size unspecified but must **fit the screen**; snake **starts centered**.
* **Pure assembly**: no generating asm from C; hand-written AT&T syntax.
* **Well-commented**, but not on every line.

**CLI**

* Must accept: initial snake **length** and **number of apples** via argv: `./snake 5 2`.

**Non-Requirements (do NOT implement)**

* High scores, pause, start screen, game over screen, multiple levels, multiplayer, or any advanced features.

**Optional Extra Features (each counts as +1 point)**

* Speed increases each time an apple is eaten.
* A timer that ends the game after a set time; reset on eating an apple (tip: use `usleep` per loop and count iterations).
* Apples only spawn in **empty** cells (not on snake or other apples).
* Re-implement **helpers.c** functionality in assembly (still calling ncurses) and adjust Makefile accordingly.

**Files/Submission**

* Deliver: `snake.asm`, `start.asm`, provided `helpers.c`, Makefile, and a `.txt` with student names, desired grade, supported features, and a brief approach.
* Submit everything as a single **.zip** (code + `.txt`).
* Grading (points → grade): 1=E, 2=D, 3=C, 4=B, 5=A. Incorrect/incomplete features earn **0** points. Fx can only be complemented up to **E**. Submit via Canvas before deadline.

**Acceptance Criteria**

* Builds with `make`; runs as specified.
* Uses ncurses via provided functions; initializes/cleans up correctly.
* Meets all mandatory gameplay rules; consistent edge behavior; multiple apples; growth; controls; continuous motion; no reverse; self-death.
* Pure x86-64 AT&T assembly; C ABI compliance; start from C and from `_start`.
