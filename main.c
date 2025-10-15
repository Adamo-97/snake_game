/*********************************************************************
 *
 * Copyright (C) 2003,  Blekinge Institute of Technology
 *
 * Filename:      main.c
 * Author:        Simon Kagstrom <ska@bth.se>
 * Description:   main function for nibbles game.
 *
 * $Id: main.c 1369 2005-01-20 20:57:54Z ska $
 *
 ********************************************************************
 *
 * Modification of original:
 * Modified by:   Christoffer Åleskog <cck@bth.se>
 * Modified date: 2024-10-14
 *
 ********************************************************************/
#include <stdio.h>  /* printf */
#include <stdlib.h> /* atoi */

extern void start_game(int len, int n_apples);

int main(int argc, char *argv[]) {
  int len, apples;

  if (argc < 3) {
    printf("Usage: %s LEN APPLES\n", argv[0]);
    return 1;
  }

  len = atoi(argv[1]);
  apples = atoi(argv[2]);

  start_game(len, apples);

  return 0;
}
