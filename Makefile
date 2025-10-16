# Makefile for snake game in C and assembly
# Usage:
#   make            - build both versions
#   make snake_asm  - build C entry version
#   make snake_asm_start - build pure ASM entry version
#   make clean      - remove binaries and object files
all: snake_asm snake_asm_start

.c.o:
	gcc -Os -Wall -g -c $<

%.o: %.asm
	as -gstabs $< -o $@

snake_asm: main.o snake.o helpers.o
	gcc $^ -lncurses -o $@

snake_asm_start: start.o snake.o helpers.o workaround.o
	gcc -nostdlib -no-pie -Wl,-e,_start $^ -lc -lncurses -o $@

clean:
	rm -f *~ *.o snake snake_asm snake_asm_start

