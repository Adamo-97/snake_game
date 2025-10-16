set pagination off
set confirm off
set logging file snake_dbg.txt
set logging overwrite on
set logging enabled on

# Don't stop on common signals ncurses/usleep use
handle SIGWINCH nostop noprint pass
handle SIGALRM  nostop noprint pass

# After init: arrays should be centered (only head drawn on screen)
break init_snake_done
commands
  silent
  printf "=== INIT ===\n"
  p/d *(int*)&cur_len
  x/20wd &snake_x
  x/20wd &snake_y
  continue
end

# Every tick: right after the shift, before growth and head write
break shift_done
commands
  silent
  printf "\n=== TICK ===\n"
  p/d *(int*)&cur_len
  p/d *(int*)&grow_flag
  p/d *(int*)&next_x
  p/d *(int*)&next_y
  p/d *(int*)&old_x
  p/d *(int*)&old_y
  p/d *(int*)&tail_x
  p/d *(int*)&tail_y
  p/d *(int*)&delay_us
  x/20wd &snake_x
  x/20wd &snake_y
  continue
end

# Log when an apple marks growth
watch *(int*)&grow_flag if (*(int*)&grow_flag)==1
commands
  silent
  printf "\n*** GROW FLAG SET (apple eaten) ***\n"
  p/d *(int*)&cur_len
  p/d *(int*)&delay_us
  x/10wd &snake_x
  x/10wd &snake_y
  continue
end

# Auto-run your program with args
run
