# Makefile for snake game in C and assembly
# Usage:
#   make          - build both versions
#   make snake    - build C entry version (run as ./snake)
#   make snake_asm  - build pure ASM entry version (entry at _start)
#   make clean    - remove binaries and object files

all: snake snake_asm

.c.o:
	gcc -Os -Wall -g -c $<

%.o: %.asm
	as -gstabs $< -o $@

# C entrypoint -> outputs executable named 'snake'
snake: main.o snake.o helpers.o
	gcc $^ -lncurses -o $@

# Pure ASM entrypoint -> outputs executable named 'snake_asm'
snake_asm: start.o snake.o helpers.o workaround.o
	gcc -nostdlib -no-pie -Wl,-e,_start $^ -lc -lncurses -o $@

.PHONY: clean
clean:
	rm -f *~ *.o snake snake_asm
