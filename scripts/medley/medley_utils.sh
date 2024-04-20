#!/bin/sh
###############################################################################
#
#    medley_utils.sh - script containing various useful functions for medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-23 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################

is_tput="$(which tput)"

output_error_msg() {
  if [ -n "${is_tput}" ];
  then
    echo "$(${is_tput} setab 1)$(${is_tput} setaf 7)$1$(${is_tput} sgr0)"
  else
    echo "$1"
  fi
}

check_for_dash_or_end() {
  local_err_msg="";
  if [ -z "$2" ] || [ "$2" = "--" ]
  then
    local_err_msg="Error: the flag \"$1\" requires a value.
Value is missing."
    usage "${local_err_msg}"
  else
    case "$2" in
       -*)
           local_err_msg="Error: either the value for flag \"${1}\" is missing OR
the value begins with a \"-\", which is not allowed."
           usage "${local_err_msg}"
           ;;
    esac
  fi
}

check_file_writeable_or_creatable() {
  local_msg_core="\"$2\" given as the value of the \"$1\" flag"
  local_err_msg=""
  if [ -e "$%2" ]
  then
    if [ ! -f "$2" ]
    then
      local_err_msg="Error: File ${local_msg_core} is not a regular file.
It is either a directory or a device file of some sort.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    elif [ ! -w "$2" ]
    then
      local_err_msg="Error: File ${local_msg_core} exists but is not writeable
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    fi
  else
    if [ ! -w "$(dirname -- "$2")" ]
    then
      local_err_msg="Error: File ${local_msg_core} cannot be created because
its directory either doen't exist or is not writeable.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    fi
  fi
}

check_file_readable() {
  local_msg_core="\"$2\" given as the value of the \"$1\" flag"
  if [ ! -r "$2" ]
  then
    local_err_msg="Error: File ${local_msg_core}
either doesn't exist or is not readable.
Exiting"
    output_error_msg "${local_err_msg}"
    exit 1
  fi
}

check_dir_writeable_or_creatable() {
  local_msg_core="\"$2\" given as the value of the \"$1\" flag"
  if [ -e "$2" ]
  then
    if [ ! -d "$2" ]
    then
      local_err_msg="Error: Pathname ${local_msg_core} exists but is not a directory.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    elif [ ! -w "$2" ]
    then
      local_err_msg="Error: Directory ${local_msg_core} exists but is not writeable.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    fi
  else
    if [ ! -w "$(dirname -- "$2")" ]
    then
      local_err_msg="Error: Directory ${local_msg_core} cannot be created because
its parent directory either doesn't exist or is not writeable.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    fi
  fi
}


