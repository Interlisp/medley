#!only-to-be-sourced
# shellcheck shell=sh
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
  local_oem_file="${TMPDIR:-/tmp}"/oem_$$
  echo "$1" >"${local_oem_file}"
  while read -r line
  do
    if [ -n "${is_tput}" ];
    then
      echo "$(${is_tput} setab 1)$(${is_tput} setaf 7)${line}$(${is_tput} sgr0)"
    else
      echo "$1"
    fi
  done <"${local_oem_file}"
  rm -f "${local_oem_file}"
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
  if [ -e "$2" ]
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

check_dir_writeable_or_creatable() {
  local_msg_core="\"$2\" given as the value of the \"$1\" flag"
  local_err_msg=""
  if [ -e "$2" ]
  then
    if [ ! -d "$2" ]
    then
      local_err_msg="Error: ${local_msg_core} exists but is not a directory.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    elif [ ! -w "$2" ]
    then
      local_err_msg="Error: Directory ${local_msg_core} exists but is not writeable
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    fi
  else
    if [ ! -w "$(dirname -- "$2")" ]
    then
      local_err_msg="Error: Directory ${local_msg_core} cannot be created because
its directory either doesn't exist or is not writeable.
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

check_dir_exists() {
  local_msg_core="\"$2\" given as the value of the \"$1\" flag"
  if [ -e "$2" ]
  then
    if [ ! -d "$2" ]
    then
      local_err_msg="Error: Pathname ${local_msg_core} exists but is not a directory.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    elif [ ! -r "$2" ]
    then
      local_err_msg="Error: Directory ${local_msg_core} exists but is not readable.
Exiting"
      output_error_msg "${local_err_msg}"
      exit 1
    fi
  fi
}

parse_nethub_data() {
  nh_host=""
  nh_port=""
  nh_mac=""
  nh_debug=""
  #
  x="${1%:}:"
  nh_host="${x%%:*}"
  x="${x#"${nh_host}":*}"
  nh_port="${x%%:*}"
  if [ "${nh_port}" = "${x}" ]; then nh_port=""; return 0; fi
  x="${x#"${nh_port}":*}"
  nh_mac="${x%%:*}"
  if [ "${nh_mac}" = "${x}" ]; then nh_mac=""; return 0; fi
  nh_debug="${x#"${nh_mac}":*}"
  if [ "${nh_debug}" = "${x}" ]; then nh_debug=""; return 0; fi
  nh_debug="${nh_debug%:}"
  return 0
}

