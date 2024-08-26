#!/bin/bash

export -f fn_draw_menu_window_user

fn_draw_menu_window() {
  ipcrm -M ${MENU_KEY} 2> /dev/null # fixing `yad: cannot create shared memory for key 100: File exists`

  USER_CMD="fn_draw_menu_window_user"
  for ARG in "$@"; do
    USER_CMD+=" '$ARG'"
  done

  YAD_RES=$(su -c "${USER_CMD}" gostik)
  echo -n "${YAD_RES}"
}

################################################################################

export -f fn_draw_create_backup_window_user

fn_draw_create_backup_window() {
  ipcrm -M ${CREATE_BAKUP_KEY} 2> /dev/null # fixing `yad: cannot create shared memory for key 100: File exists`

  USER_CMD="fn_draw_create_backup_window_user"
  for ARG in "$@"; do
    USER_CMD+=" '$ARG'"
  done

  YAD_RES=$(su -c "${USER_CMD}" gostik)
  echo -n "${YAD_RES}"
}