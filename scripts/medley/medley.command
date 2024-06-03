#!/bin/sh
# shellcheck disable=SC2164,SC2181,SC2009,SC2034,SC2154
# . ./medley_header.sh
# shellcheck shell=sh
###############################################################################
#
#    medley.sh - script for running Medley Interlisp on
#                Linux/WSL/Cygwin/MacOS. On all platforms it just sets
#                up directories and environment variables and then calls
#                maiko with the right arguments.  On WSL, there is an option to
#                run without or around X Windows by using the XVnc and a VNC viewer
#                on the Windows side.  This script will start this VNC viewer
#                on the Windows side.
#
#   NOTE:  This script is "compiled" using compile.sh (and inline.sh) from the
#          component scripts (medley_*.sh).  The top-level component is
#          medley_main.sh.  The other components are sourced (directly or
#          indirectly) from medley_main.sh.
#
#          Do not edit this script directly.  Edit the component scripts and
#          then recompile to get this "combined" script.  You can also run
#          the scripts by exec-ing the medley_main.sh script.  This will allow
#          testing of component modifications without having to compile.
#
#   2023-01-12 Frank Halasz
#   2024-04-29 Frank Halasz: Major overhaul
#
#   Copyright 2023-2024 Interlisp.org
#
###############################################################################
###############################################################################
#
#    medley_main.sh - "main" script for running Medley Interlisp on
#                Linux/WSL/Cygwin/MacOS. On all platforms it just sets
#                up directories and environment variables and then calls
#                maiko with the right arguments.  On WSL, there is an option to
#                run without or around X Windows by using the XVnc and a VNC viewer
#                on the Windows side.  This script will start this VNC viewer
#                on the Windows side.
#
#   2023-01-12 Frank Halasz
#   2024-04-29 Frank Halasz: Major overhaul
#
#   Copyright 2023-2024 Interlisp.org
#
###############################################################################

#set -x

#
#
# Start off with some functions to determine what directory this script is being executed from
#
#
get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

# This function taken from
# https://stackoverflow.com/questions/29832037/how-to-get-script-directory-in-posix-sh
rreadlink() (

  # Execute this function in a *subshell* to localize variables and the effect of `cd`.

  target=$1
  fname=
  targetDir=
  CDPATH=

  # Try to make the execution environment as predictable as possible:
  # All commands below are invoked via `command`, so we must make sure that `command`
  # itself is not redefined as an alias or shell function.
  # (Note that command is too inconsistent across shells, so we don't use it.)
  # `command` is a *builtin* in bash, dash, ksh, zsh, and some platforms do not even have
  # an external utility version of it (e.g, Ubuntu).
  # `command` bypasses aliases and shell functions and also finds builtins 
  # in bash, dash, and ksh. In zsh, option POSIX_BUILTINS must be turned on for that
  # to happen.
  { \unalias command; \unset -f command; } >/dev/null 2>&1
  [ -n "$ZSH_VERSION" ] && options[POSIX_BUILTINS]=on # make zsh find *builtins* with `command` too.

  while :; do # Resolve potential symlinks until the ultimate target is found.
      [ -L "$target" ] || [ -e "$target" ] || { command printf '%s\n' "ERROR: '$target' does not exist." >&2; return 1; }
      command cd "$(command dirname -- "$target")" # Change to target dir; necessary for correct resolution of target path.
      fname=$(command basename -- "$target") # Extract filename.
      [ "$fname" = '/' ] && fname='' # !! curiously, `basename /` returns '/'
      if [ -L "$fname" ]; then
        # Extract [next] target path, which may be defined
        # *relative* to the symlink's own directory.
        # Note: We parse `ls -l` output to find the symlink target
        #       which is the only POSIX-compliant, albeit somewhat fragile, way.
        target=$(command ls -l "$fname")
        target=${target#* -> }
        continue # Resolve [next] symlink target.
      fi
      break # Ultimate target reached.
  done
  targetDir=$(command pwd -P) # Get canonical dir. path
  # Output the ultimate target's canonical path.
  # Note that we manually resolve paths ending in /. and /.. to make sure we have a normalized path.
  if [ "$fname" = '.' ]; then
    command printf '%s\n' "${targetDir%/}"
  elif  [ "$fname" = '..' ]; then
    # Caveat: something like /var/.. will resolve to /private (assuming /var@ -> /private/var), i.e. the '..' is applied
    # AFTER canonicalization.
    command printf '%s\n' "$(command dirname -- "${targetDir}")"
  else
    command printf '%s\n' "${targetDir%/}/$fname"
  fi
)

get_script_dir() {

    # call this with $0 (from main script) as its (only) parameter
    # if you need to preserve cwd, run this is a subshell since
    # it can change cwd

    # set -x

    local_SCRIPT_PATH="$( get_abs_filename "$1" )";

    while [ -h "$local_SCRIPT_PATH" ];
    do
        cd "$( dirname -- "$local_SCRIPT_PATH"; )";
        local_SCRIPT_PATH="$( rreadlink "$local_SCRIPT_PATH" )";
    done

    cd "$( dirname -- "$local_SCRIPT_PATH"; )" > '/dev/null';
    local_SCRIPT_PATH="$( pwd; )";

    # set +x

    echo "${local_SCRIPT_PATH}"
}

# end of script directory functions
###############################################################################



# figure out the script dir
SCRIPTDIR="$(get_script_dir "$0")"

#  Define some generally useful functions
# shellcheck source=./medley_utils.sh
# . "${SCRIPTDIR}/medley_utils.sh"
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


MEDLEYDIR="$(cd "${SCRIPTDIR}/../.."; pwd)"
export MEDLEYDIR
IL_DIR="$(cd "${MEDLEYDIR}/.."; pwd)"

# Are we running under WSL or Darwin or Cygwin?
#
wsl=false
darwin=false
cygwin=false

if [ "$(uname)" = "Darwin" ]
then
  darwin=true
elif [ "$(uname -s | head --bytes 6)" = "CYGWIN" ]
then
  cygwin=true
elif [ -e "/proc/version" ] && grep --ignore-case --quiet Microsoft /proc/version
then
  wsl=true
  wsl_ver=0
  # WSL2
  grep --ignore-case --quiet wsl /proc/sys/kernel/osrelease
  if [ $? -eq 0 ];
  then
    wsl_ver=2
  else
    # WSL1
    grep --ignore-case --quiet microsoft /proc/sys/kernel/osrelease
    if [ $? -eq 0 ]
    then
      if [ "$(uname -m)" = "x86_64" ]
      then
        wsl_ver=1
      else
        err_msg="ERROR: Running Medley on WSL1 requires an x86_64-based PC.
This is not an x86_64-based PC.
Exiting"
        output_error_msg "${err_msg}"
        exit 23
      fi
    fi
  fi
fi

# process config file and args
# shellcheck source=./medley_configfile.sh
# . "${SCRIPTDIR}/medley_configfile.sh"
# shellcheck shell=sh
###############################################################################
#
#    medley_configfile.sh - script for processing the config file for the
#                           medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2024-04-20 Frank Halasz
#
#   Copyright 2024 Interlisp.org
#
###############################################################################

config_file=""

# look thru args looking to see if a config file was specified
j=1
jmax=$#
while [ "$j" -le "$jmax" ]
do
  if [ "$(eval "printf %s \${${j}}")" = "-c" ] || [ "$(eval "printf %s \${${j}}")" = "--config" ]
  then
    k=$(( j + 1 ))
    config_file="$(eval "printf %s \${${k}}")"
    if [ ! "${config_file}" = "-" ] && [ ! -f "${config_file}" ]
    then
      echo "Error: specified config file \"${config_file}\" not found."
      echo "Exiting."
      exit 52
    fi
    j=$(( j + 1 ))
  fi
  j=$(( j + 1 ))
done

# if no config file specified, use the defaults (if they exist)
if [ -z "${config_file}" ]
then
  for f in "${HOME}/.medley_config" "${MEDLEYDIR}/.medley_config"
  do
    if [ -f "$f" ]
    then
      config_file="$f"
    fi
  done
fi

# add marker to separate config file args from command line args
set -- "--start_cl_args" "--start_cl_args" "$@"

# if there is a config file and its not been suppressed with "-",
# read the config file (in reverse order) and add the first two items on each line
# to the arguments array
if [ -n "${config_file}" ] && [ ! "${config_file}" = "-" ]
then
  rev_config_file="${TMPDIR:-/tmp}"/.medley_config_$$
  # reverse order of lines in medley config file
  sed '1!x;H;1h;$!d;g' < "${config_file}" >"${rev_config_file}"
  while read -r arg1 arg2
  do
    if [ -n "${arg2}" ]
    then
      arg2="$(echo "${arg2}" | sed s/\"//g)"
      set -- "${arg2}" "$@"
    fi
    if [ -n "${arg1}" ]
    then
      set -- "${arg1}" "$@"
    fi
  done < "${rev_config_file}"
  rm -f "${rev_config_file}"
fi



# shellcheck source=./medley_args.sh
# . "${SCRIPTDIR}/medley_args.sh"
# shellcheck shell=sh
# shellcheck disable=SC2034,SC2154,SC2164
###############################################################################
#
#    medley_args.sh - script for processing the args to medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-12 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################

# load usage function
# shellcheck source=./medley_usage.sh
# . "${SCRIPTDIR}/medley_usage.sh"
# shellcheck shell=sh
# shellcheck disable=SC2154
###############################################################################
#
#    medley_useage.sh - script defining the "usage" for medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-21 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################


PAGER=$( if [ -n "$(which more)" ]; then echo "more"; else echo "cat"; fi)

usage() {
   usage_msg_path=/tmp/msg-$$

   if [ "${wsl}" = true ];
   then
     wsl_incl="+w"
     wsl_excl="-w"
   else
     wsl_incl="-w"
     wsl_excl="+w"
   fi

   if [ "${docker}" = true ];
   then
     docker_incl="+d"
     docker_excl="-d"
   else
     docker_incl="-d"
     docker_excl="+d"
   fi

   if [ "${windows}" = true ];
   then
     windows_incl="+W"
     windows_excl="-W"
   else
     windows_incl="-W"
     windows_excl="+W"
   fi

   if [ $# -ne 0 ];
   then
     full_msg="In ${args_stage}:
$1"
     { echo; output_error_msg "${full_msg}"; echo; } >> "${usage_msg_path}"
   else
     touch "${usage_msg_path}"
   fi

   cat "${usage_msg_path}" - <<EOF \
       | sed -e "/^${docker_excl}/d" -e "s/^${docker_incl}/  /" \
       | sed -e "/^${wsl_excl}/d" -e "s/^${wsl_incl}/  /" \
       | sed -e "/^${windows_excl}/d" -e "s/^${windows_incl}/  /" \
       | ${PAGER}
Usage: medley [flags] [sysout] [--] [pass_args ...]

Note: MEDLEYDIR is the directory at the top of the code tree where this script is executed from
      after all symbolic links have been resolved.  For standard installations this will be
      /usr/local/interlisp/medley.  For "local" installations this will be the "medley" sub-directory
      under the directory into which the Medley distribution was installed.

flags:
    -h | --help                : print this usage information

    -z | --man                 : show the man page for medley

    -c FILE | --config FILE    : use FILE as the config file (default: ~/.medley_config)

    -f | --full                : start Medley from the "full" sysout

    -l | --lisp                : start Medley from the "lisp" sysout

    -a | --apps                : start Medley from the "apps" sysout

    -u | --continue            : start Medley from the vmem file from previous Medley run

    -y FILE | --sysout FILE    : start Medley using FILE as sysout

    -e | --interlisp           : (for apps.sysout only) Start in the Interlisp exec

    -n | --noscroll            : do not use scroll bars in Medley window

    -g WxH | --geometry WxH    : set the window geometry to Width x Height.

    -s WxH | --screensize WxH  : set the Medley screen size to be Width x Height

    -ps N | --pixelscale N     : use N as the pixel scale factor - for SDL display only

    -t STRING | --title STRING : use STRING as title of window

    -d :N | --display :N       : use X display :N
+w
+w  -v | --vnc                 : (WSL only) Use a VNC window instead of an X window

    -i STRING | --id STRING    : use STRING as the id for this run of Medley (default: default)

    -m N | --mem N             : set Medley memory size to N

    -k FILE | --vmem FILE      : use FILE as the Medley virtual memory store.

    -r FILE | --greet FILE     : use FILE as the Medley greetfile.

    -r - | --greet -           : do not use a greetfile

    -x DIR | --logindir DIR    : use DIR as LOGINDIR in Medley

    -x - | --logindir -        : use MEDLEYDIR/logindir as LOGINDIR in Medley

sysout:
    The pathname of the file to use as a sysout for Medley to start from.
    If sysout is not provided and none of the flags [-a, -f & -l] is used, then Medley will start from
    the saved virtual memory file for the previous run with the sane id as this run.

pass_args:
    All arguments after the "--" flag, are passed unaltered to the Maiko emulator.

EOF

exit 1

}

args_stage="config file"

# Defaults
geometry=""
greet_specified=false
pass_args=false
run_id="default"
screensize=""
sysout_arg=""
sysout_stage=""
title=""
use_vnc=false
windows=false
maikodir_arg=""
maikodir_stage=""
maikoprog_arg=""
greet_arg=""
noscroll=false
display_arg=""
vmem_arg=""
mem_arg=""
maiko_args=""
logindir_arg=""
nh_host_arg=""
nh_port_arg=""
nh_mac_arg=""
nh_debug_arg=""
pixelscale_arg=""
borderwidth_arg=""


# Add marker at end of args so we can accumulate pass-on args in args array
set -- "$@" "--start_of_pass_args"

# Loop thru args and process
while [ "$#" -ne 0 ];
do
  if [ "${pass_args}" = false ];
  then
    case "$1" in
      -a | --apps)
        sysout_arg="apps"
        sysout_stage="${args_stage}"
        ;;
      -c | --config)
        # already handled so just skip both flag and value
        shift;
        ;;
      -d | --display)
        if [ "$2" = "-" ]
        then
          display=""
        else
          check_for_dash_or_end "$1" "$2"
          display_arg="$2"
        fi
        shift
        ;;
      -e | --interlisp)
        case "$2" in
          -)
            MEDLEY_EXEC=""
            shift
            ;;
          +)
            export MEDLEY_EXEC="inter"
            shift
            ;;
          *)
            export MEDLEY_EXEC="inter"
            ;;
        esac
        ;;
      -f | --full)
        sysout_arg="full"
        sysout_stage="${args_stage}"
        ;;
      -g | --geometry)
        if [ "$2" = "-" ]
        then
          geometry=""
        else
          check_for_dash_or_end "$1" "$2"
          geometry="$2"
        fi
        shift
        ;;
      -h | --help)
        usage
        ;;
      -i | --id)
        if [ "$2" = "-" ]
        then
          run_id="default"
        elif [ "$2" = "--" ]
        then
          run_id="$( basename "${MEDLEYDIR}" )"
        elif [ "$2" = "---" ]
        then
          run_id="$(cd "${MEDLEYDIR}/.."; basename "$(pwd)")"
        else
          check_for_dash_or_end "$1" "$2"
          run_id=$(echo "$2" | sed -e "s/++*\(.\)/\\1/g" -e "s/[^A-Za-z0-9+_]//g")
        fi
        shift
        ;;
      -k | --vmem)
        if [ "$2" = "-" ]
        then
          vmem_arg=""
        else
          check_for_dash_or_end "$1" "$2"
          check_file_writeable_or_creatable "$1" "$2"
          vmem_arg="$2"
        fi
        shift
        ;;
      -l | --lisp)
        sysout_arg="lisp"
        sysout_stage="${args_stage}"
        ;;
      -m | --mem)
        if [ "$2" = "-" ]
        then
          mem_arg=""
        else
          check_for_dash_or_end "$1" "$2"
          mem_arg="$2"
        fi
        shift
        ;;
      -n | --noscroll)
        case "$2" in
          -)
            noscroll=false
            shift
            ;;
          +)
            noscroll=true
            shift
            ;;
          *)
            noscroll=true
            ;;
        esac
        ;;
      -nh | --nethub)
        case "$2" in
          -:* | - )
            true
            ;;
          *)
            check_for_dash_or_end "$1" "$2"
            ;;
        esac
        parse_nethub_data "$2"
        if [ "${nh_host}" = "-" ]; then nh_host_arg=""; else nh_host_arg="${nh_host}"; fi
        if [ "${nh_port}" = "-" ]; then nh_port_arg=""; else nh_port_arg="${nh_port}"; fi
        if [ "${nh_mac}" = "-" ]; then nh_mac_arg=""; else nh_mac_arg="${nh_mac}"; fi
        if [ "${nh_debug}" = "-" ]; then nh_debug_arg=""; else nh_debug_arg="${nh_debug}"; fi
        shift
	;;
      -ps | --pixelscale)
        if [ "$2" = "-" ]
        then
          pixelscale_arg=""
        else
          check_for_dash_or_end "$1" "$2"
          pixelscale_arg="$2"
        fi
        shift
        ;;
      -r | --greet)
        if [ "$2" = "-" ] || [ "$2" = "--" ]
        then
          greet_arg="--nogreet--"
        else
          check_for_dash_or_end "$1" "$2"
          check_file_readable "$1" "$2"
          greet_arg="$2"
        fi
        greet_specified='true'
        shift
        ;;
      -s | --screensize)
        if [ "$2" = "-" ]
        then
          screensize=""
        else
          check_for_dash_or_end "$1" "$2"
          screensize="$2"
        fi
        shift
        ;;
      -t | --title)
        if [ "$2" = "-" ]
        then
          title=""
        else
          check_for_dash_or_end "$1" "$2"
          if [ -n "$2" ]; then title="$2"; fi
        fi
        shift
        ;;
      -u | --continue)
        sysout_arg=""
        sysout_stage="${args_stage}"
        ;;
      -v | --vnc)
        case "$2" in
          -)
            use_vnc=false
            shift
            ;;
          +)
            use_vnc=true
            shift
            ;;
          *)
            use_vnc=true
            ;;
        esac
        if [ "${use_vnc}" = true ] && { [ ! "${wsl}" = true ] || [ ! "$(uname -m)" = x86_64 ] ; }
        then
          echo "Warning: The -v or --vnc flag was set."
          echo "But the vnc option is only available when running on "
          echo "Windows System for Linux (wsl) on x86_64 machines."
          echo "Ignoring the -v or --vnc flag."
          use_vnc=false
        fi
        ;;
      -x | --logindir)
        if [ "$2" = "-" ] 
        then
          logindir_arg=""
        elif [ "$2" = "--" ]
        then
          check_dir_writeable_or_creatable "$1" "${MEDLEYDIR}/logindir"
          logindir_arg="${MEDLEYDIR}/logindir"
        else
          check_for_dash_or_end "$1" "$2"
          check_dir_writeable_or_creatable "$1" "$2"
          logindir_arg="$2"
        fi
        shift
        ;;
      -y | --sysout)
        if [ "$2" = "-" ]
        then
          sysout_arg=""
        else
          check_for_dash_or_end "$1" "$2"
          sysout_arg="$2"
        fi
        sysout_stage="${args_stage}"
        shift
        ;;
      -z | --man)
        if [ "${darwin}" = true ]
        then
          /usr/bin/man "${MEDLEYDIR}/docs/man-page/medley.1.gz"
        else
          /usr/bin/man -l "${MEDLEYDIR}/docs/man-page/medley.1.gz"
        fi
        exit 0
        ;;
      -nf | -NF | --nofork)
        # for use in loadups
        case $2 in
          -)
            nofork_arg=""
            ;;
          +)
            nofork_arg="-NF"
            ;;
          *)
            nofork_arg="-NF"
            ;;
        esac
        ;;
      --maikodir)
        # for use in loadups
        check_for_dash_or_end "$1" "$2"
        check_dir_exists "$1" "2"
        maikodir_arg="$2"
        maikodir_stage="${args_stage}"
        shift;
        ;;
      -prog | --maikoprog)
        # for use in loadups
        check_for_dash_or_end "$1" "$2"
        maikoprog_arg="$2"
        shift
        ;;
      --windows)
        # internal:  called from Windows medley.ps1 (via docker)
        windows=true
        ;;
      --start_cl_args)
        # internal: used to separate config file args from command line args
        args_stage="command line arguments"
        pass_args=false
        ;;
      --start_of_pass_args)
        # internal: used to mark end of args and start of accumulated pass-on args
        shift
        break
        ;;
      --)
        pass_args=true
        ;;
      -*)
        usage "ERROR: Unknown flag: $1"
        ;;
      *)
        # if matched the empty string, just ignore
        if [ -n "$1" ];
        then
          if [ $# -eq 1 ] || [ "$2" = "--" ]
          then
            sysout_arg="$1"
            sysout_stage="${args_stage}"
          else
            err_msg="ERROR: unexpected argument \"$1\""
            usage "${err_msg}"
          fi
        fi
        ;;
    esac
  else
    if [ "$1" = "--start_cl_args" ]
    then
      args_stage="command line arguments"
      pass_args=false
    elif [ "$1" = "--start_of_pass_args" ]
    then
      shift
      break
    else
      # add pass-on args to end of args array
      set -- "$@" "$1"
      # maiko_args="${maiko_args} \"$1\""
    fi
  fi
  shift
done

# if running on WSL1, force use_vnc
if [ "${wsl}" = true ] && [ "${wsl_ver}" -eq 1 ]
then
  use_vnc=true
fi


# Process run_id
# if it doesn't end in #, make sure that there is not another instance currently running with this same id
# If it does end in #, find the right number to fill in for the #
run_id_base="${run_id%+}"
run_id_has_plus="${run_id#"${run_id_base}"}"
if [ -z "${run_id_has_plus}" ]
then
  matching=$(ps ax | sed -e "/sed/d" -e "/ldex.*-id ${run_id_base}/p" -e "/ldesdl.*-id ${run_id_base}/p" -e d)
  if [ -n "${matching}" ]
  then
    err_msg="Another instance of Medley Interlisp is already running with the id \"${run_id}\".
Only a single instance with a given id can be run at the same time.
Please retry using the \"--id <name>\" argument to give this new instance a different id.
Exiting"
    output_error_msg "${err_msg}"
    exit 3
  fi
else
  matching=$( \
      ps ax | \
      sed -e "/ldex.*-id ${run_id_base}[0-9]/s/^.*-id ${run_id_base}\([0-9]*\).*$/\\1/p" \
          -e "/ldesdl.*-id ${run_id_base}[0-9]/s/^.*-id ${run_id_base}\([0-9]*\).*$/\\1/p" \
          -e d \
    )
  max=0
  for n in $matching
  do
    if [ "$n" -gt "$max" ]; then max=$n; fi
  done
  max=$(( max + 1 ))
  run_id="${run_id_base}${max}"
fi

# Run medley
# shellcheck source=./medley_run.sh
# . "${SCRIPTDIR}/medley_run.sh"
# shellcheck shell=sh
# shellcheck disable=SC2154,SC2164,SC2086
###############################################################################
#
#    medley_run.sh - script for processing actually running maiko/medley
#                    for the medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2024-04-21 Frank Halasz
#
#   Copyright 2024 Interlisp.org
#
###############################################################################

# Figure out LOGINDIR situation
if [ -z "${logindir_arg}" ]
then
  LOGINDIR="${HOME}/il"
else
  LOGINDIR="${logindir_arg}"
fi
export LOGINDIR

if [ ! -e "${LOGINDIR}" ];
then
  mkdir -p "${LOGINDIR}"
elif [ ! -d "${LOGINDIR}" ];
then
  echo "ERROR: Medley requires a directory named ${LOGINDIR}."
  echo "But ${LOGINDIR} exists but appears not be a directory."
  echo "Exiting"
  exit 2
fi
mkdir -p "${LOGINDIR}"/vmem

# Set LDEDESTSYSOUT env variable based on id
# if LDEDESRTSYSOUT has not already been set
# during arg processing
if [ -z "${vmem_arg}" ]
then
  if [ "${run_id}" = "default" ]
  then
    LDEDESTSYSOUT="${LOGINDIR}/vmem/lisp.virtualmem"
  else
    LDEDESTSYSOUT="${LOGINDIR}/vmem/lisp_${run_id}.virtualmem"
  fi
else
  LDEDESTSYSOUT="${vmem_arg}"
fi
export LDEDESTSYSOUT

# Figure out the sysout situation

loadups_dir="${MEDLEYDIR}/loadups"
if [ -z "${sysout_arg}" ]
then
  if [ -f "${LDEDESTSYSOUT}" ]
  then
    src_sysout="${LDEDESTSYSOUT}"
  else
    src_sysout="${loadups_dir}/full.sysout"
  fi
else
  case "${sysout_arg}" in
    lisp | full | apps)
      if [ ! -d "${loadups_dir}" ]
      then
        err_msg="Error: The sysout argument --${sysout_arg} was specified in ${sysout_stage},
but the directory \"${loadups_dir}\" where ${sysout_arg}.sysout is supposed to be located
cannot be found.
Exiting."
        output_error_msg "${err_msg}"
        exit 62
      fi
      src_sysout="${loadups_dir}/${sysout_arg}.sysout"
      ;;
    *)
      src_sysout="${sysout_arg}"
      ;;
  esac
fi
if [ ! -f "${src_sysout}" ]
then
    err_msg="Error: Cannot find the specified sysout file \"${src_sysout}\".
Exiting."
    output_error_msg "${err_msg}"
fi

# Figure out screensize and geometry based on arguments
# shellcheck source=./medley_geometry.sh
# . "${SCRIPTDIR}/medley_geometry.sh"
# shellcheck shell=sh
# shellcheck disable=SC2154,SC2269
###############################################################################
#
#    medley_geometry.sh - script for computing the geometry and screensize
#                         parameters for a medley session
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-17 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################

if [ "${noscroll}" = false ];
then
  scroll=22
else
  scroll=0
fi
if [ -n "${geometry}" ] && [ -n "${screensize}" ]
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [ -z "${gw}" ] || [ -z "${gh}" ]
  then
    err_msg="Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    usage "${err_msg}"
  fi
  geometry="${geometry}"
  #
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [ -z "${sw}" ] || [ -z "${sh}" ]
  then
    err_msg="Error: Improperly formed -screensize argument: ${screensize}"
    usage "${err_msg}"
  fi
  screensize="${screensize}"
elif [ -n "${geometry}" ]
then
  gw=$(expr "${geometry}" : "\([0-9]*\)x[0-9]*$")
  gh=$(expr "${geometry}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${gw}" ] && [ -n "${gh}" ]
  then
    sw=$(( (((31+gw)/32)*32)-scroll ))
    sh=$(( gh - scroll ))
    geometry="${gw}x${gh}"
    screensize="${sw}x${sh}"
  else
    err_msg="Error: Improperly formed -geometry or -dimension argument: ${geometry}"
    usage "${err_msg}"
  fi
elif [ -n "${screensize}" ]
then
  sw=$(expr "${screensize}" : "\([0-9]*\)x[0-9]*$")
  sh=$(expr "${screensize}" : "[0-9]*x\([0-9]*\)$")
  if [ -n "${sw}" ] && [ -n "${sh}" ]
  then
    sw=$(( (31+sw)/32*32 ))
    gw=$(( scroll+sw ))
    gh=$(( scroll+sh ))
    geometry="${gw}x${gh}"
    screensize="${sw}x${sh}"
  else
    err_msg="Error: Improperly formed -screensize argument: ${screensize}"
    usage "${err_msg}"
  fi
else
  screensize="1440x900"
  if [ "${noscroll}" = false ];
  then
    geometry="1462x922"
  else
    geometry="1440x900"
  fi
fi

# Figure out border width situation
borderwidth_flag=""
borderwidth_value=""
if [ -n "${borderwidth_arg}" ]
then
  borderwidth_flag="-bw"
  borderwidth_value="${borderwidth_arg}"
fi

# Figure out pixelscale situation
pixelscale_flag=""
pixelscale_value=""
if [ -n "${pixelscale_arg}" ]
then
  pixelscale_flag="-pixelscale"
  pixelscale_value="${pixelscale_arg}"
fi

# figure out greet files situation
if [ -z "${greet_arg}" ]
then
  if [ "${sysout_arg}" = "apps" ]
  then
    LDEINIT="${MEDLEYDIR}/greetfiles/APPS-INIT.LCOM"
  else
    LDEINIT="${MEDLEYDIR}/greetfiles/MEDLEYDIR-INIT.LCOM"
  fi
else
 if [ "${greet_arg}" = "--nogreet--" ]
  then
    LDEINIT="${MEDLEYDIR}/greetfiles/NOGREET"
  else
    LDEINIT="${greet_arg}"
  fi
fi
export LDEINIT

# figure out noscroll situation
noscroll_arg=""
if [ "${noscroll}" = true ]
then
  noscroll_arg="-noscroll"
fi

# figure out -m situatiom
mem_flag=""
mem_value=""
if [ -n "${mem_arg}" ]
then
  mem_flag="-m"
  mem_value="${mem_arg}"
fi

# figure out the nethub situation
nh_host_flag=""
nh_host_value=""
nh_port_flag=""
nh_port_value=""
nh_mac_flag=""
nh_mac_value=""
nh_debug_flag=""
nh_debug_value=""
if [ -n "${nh_host_arg}" ]
then
  nh_host_flag="-nh-host"
  nh_host_value="${nh_host_arg}"
  if [ -n "${nh_port_arg}" ]
  then
    nh_port_flag="-nh-port"
    nh_port_value="${nh_port_arg}"
  fi
  if [ -n "${nh_mac_arg}" ]
  then
    nh_mac_flag="-nh-mac"
    nh_mac_value="${nh_mac_arg}"
  fi
  if [ -n "${nh_debug_arg}" ]
  then
    nh_debug_flag="-nh-loglevel"
    nh_debug_value="${nh_debug_arg}"
  fi
fi

# figure out the keyboard type
if [ -z "${LDEKBDTYPE}" ]; then
    export LDEKBDTYPE="X"
fi

# figure out title situation
if [ -z "${title}" ]
then
  title="Medley Interlisp %i"
fi
if [ ! "${run_id}" = default ]
then
  title="$(printf %s "${title}" | sed -e "s/%i/:: ${run_id}/")"
else
  title="$(printf %s "${title}" | sed -e "s/%i//")"
fi


# Figure out the maiko executable name
# used for loadups (ldeinit)
if [ -z "${maikoprog_arg}" ]
then
  maikoprog_arg="lde"
fi

# Figure out the maiko directory maiko
check_if_maiko_dir () {
  if [ -d "$1" ] \
     && [ -d "$1/bin" ] \
     && [ -x "$1/bin/osversion" ] \
     && [ -x "$1/bin/machinetype" ]
  then
    maiko_exe_subdir="$("$1/bin/osversion").$("$1/bin/machinetype")"
    return 0
  fi
  return 1
}

check_for_maiko_exe () {
  if ! check_if_maiko_dir "$1"
  then
    return 1
  fi
  maiko_exe="$1/${maiko_exe_subdir}/${maikoprog_arg}"
  if [ -x "${maiko_exe}" ]
  then
    return 0
  else
    maiko_exe=""
    return 1
  fi
}

if [ -z "${maikodir_arg}" ]
then
  if check_for_maiko_exe "${MEDLEYDIR}/maiko"
  then
    maikodir_arg="${MEDLEYDIR}/maiko"
  elif check_for_maiko_exe "${MEDLEYDIR}/../maiko"
  then
    maikodir_arg="$(cd "${MEDLEYDIR}/../maiko"; pwd)"
  else
    if ! check_if_maiko_dir "${MEDLEYDIR}/maiko" && ! check_if_maiko_dir "${MEDLEYDIR}/../maiko"
    then
      err_msg="ERROR: Cannot find the Maiko directory at either
\"${MEDLEYDIR}/maiko\" or \"${MEDLEYDIR}/../maiko\".
You can use the --maikodir argument to specify the Maiko directory.
Exiting."
      output_error_msg "${err_msg}"
      exit 53
    else
      err_msg="ERROR: Cannot find the Maiko executable (${maiko_exe_subdir}/${maikoprog_arg}) in either
\"${MEDLEYDIR}/maiko\" or \"${MEDLEYDIR}/../maiko\".
Exiting."
      output_error_msg "${err_msg}"
      exit 54
    fi
  fi
elif ! check_if_maiko_dir "${maikodir_arg}" || ! check_for_maiko_exe "${maikodir_arg}"
then
  err_msg="In ${maikodir_stage}:
ERROR: The value of the --maikodir argument is not in fact a directory containing
the Maiko emulator (${maiko_exe_subdir}/${maikoprog_arg}).
Exiting."
  output_error_msg "${err_msg}"
  exit 53
fi

maiko="${maiko_exe}"

# Define function to start up maiko given all arguments
# Arg to this function should be "$@", the main args
# array that at this point should just include the pass-on args
start_maiko() {
  echo \
  \"${maiko}\" \"${src_sysout}\"                      \
             -id \"${run_id}\"                        \
             -title \"${title}\"                      \
             -g ${geometry}                           \
             -sc ${screensize}                        \
             ${borderwidth_flag} ${borderwidth_value} \
             ${pixelscale_flag} ${pixelscale_value}   \
             ${noscroll_arg}                          \
             ${mem_flag} ${mem_value}                 \
             ${nh_host_flag} ${nh_host_value}         \
             ${nh_port_flag} ${nh_port_value}         \
             ${nh_mac_flag} ${nh_mac_value}           \
             ${nh_debug_flag} ${nh_debug_value}       \
             ${nofork_arg}                            \
             "$@"                                     ;
  echo "MEDLEYDIR: \"${MEDLEYDIR}\""
  echo "LOGINDIR: \"${LOGINDIR}\""
  echo "GREET FILE: \"${LDEINIT}\""
  echo "VMEM FILE: \"${LDEDESTSYSOUT}\""
  #
  # Temp workaround for issues in Maiko sysout arg
  # processing. See Issue #1702.  FGH 2024-05-09
  #
  LDESOURCESYSOUT="${src_sysout}"
  export LDESOURCESYSOUT
  #
  # End work around
  #
  "${maiko}" "${src_sysout}"                          \
             -id "${run_id}"                          \
             -title "${title}"                        \
             -g "${geometry}"                         \
             -sc "${screensize}"                      \
             ${borderwidth_flag} ${borderwidth_value} \
             ${pixelscale_flag} ${pixelscale_value}   \
             ${noscroll_arg}                          \
             ${mem_flag} ${mem_value}                 \
             ${nh_host_flag} ${nh_host_value}         \
             ${nh_port_flag} ${nh_port_value}         \
             ${nh_mac_flag} ${nh_mac_value}           \
             ${nh_debug_flag} ${nh_debug_value}       \
             ${nofork_arg}                            \
             "$@"                                     ;
  exit_code=$?
}


# temp fix for cygwin to workaround issue #1685
# 2024-04-29
if [ "${cygwin}" = true ]
then
  MEDLEYDIR="${MEDLEYDIR}/"
fi


# Run maiko either directly or with vnc
if [ "${wsl}" = true ] && [ "${use_vnc}" = true ]
then
  # do the vnc thing on wsl (if called for)
  # shellcheck source=./medley_vnc.sh
#   . "${SCRIPTDIR}/medley_vnc.sh"
# shellcheck shell=sh
# shellcheck disable=SC2154,SC2162
###############################################################################
#
#    medley_vnc.sh - script for running Medley Interlisp on WSL using Xvnc
#                on the Linux side and a vncviewer on the Windows side.
#                This script run under Linux will start the right apps
#                on both the Linux and Windows sides.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-12 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################

  ip_addr() {
    ip -4 -br address show dev eth0 | awk '{print $3}' | sed 's-/.*$--'
  }

  find_open_display() {
    local_ctr=1
    local_result=-1
    while [ ${local_ctr} -lt 64 ];
    do
      if [ ! -e /tmp/.X${local_ctr}-lock ];
      then
        local_result=${local_ctr}
        break
      else
        local_ctr=$(( local_ctr+1 ))
      fi
    done
    echo ${local_result}
  }

  find_open_port() {
    local_ctr=5900
    local_result=-1
    while [ ${local_ctr} -lt 6000 ];
    do
      if [ "${wsl}" = true ] && [ "${wsl_ver}" -eq 1 ]
      then
        netstat.exe -a -n | awk '{ print $2 }' | grep -q ":${local_ctr}\$"
      else
        ss -a | grep -q "LISTEN.*:${local_ctr}[^0-9]"
      fi
      if [ $? -eq 1 ];
      then
        local_result=${local_ctr}
        break
      else
        local_ctr=$(( local_ctr+1 ))
      fi
    done
    echo ${local_result}
  }

  #
  # Make sure prequisites for vnc support in wsl are in place
  #
  if [ "${use_vnc}" = "true" ];
  then
    win_userprofile="$(cmd.exe /c "<nul set /p=%UserProfile%" 2>/dev/null)"
    vnc_dir="$(wslpath "${win_userprofile}")/AppData/Local/Interlisp"
    vnc_exe="vncviewer64-1.12.0.exe"
    if [ "$(which Xvnc)" = "" ] || [ "$(Xvnc -version 2>&1 | grep -iq tigervnc; echo $?)" -eq 1 ]
    then
      echo "Error: The -v or --vnc flag was set."
      echo "But it appears that that TigerVNC \(Xvnc\) has not been installed."
      echo "Please install TigerVNC using \"sudo apt install tigervnc-standalone-server tigervnc-xorg-extension\""
      echo "Exiting."
      exit 4
    elif [ ! -e "${vnc_dir}/${vnc_exe}" ];
    then
      if [ -e "${IL_DIR}/wsl/${vnc_exe}" ];
      then
        # make sure TigerVNC viewer is in a Windows (not Linux) directory.  If its in a Linux directory
        # there will be a long delay when it starts up
        mkdir -p "${vnc_dir}"
        cp -p "${IL_DIR}/wsl/${vnc_exe}" "${vnc_dir}/${vnc_exe}"
      else
        loop_done=false
        while [ "${loop_done}" = "false" ]
        do
          echo "TigerVnc viewer is required by the -vnc option but is not installed."
          echo "Ok to download from SourceForge? [y, Y, n or N, default n]  "
          read resp
          if [ -z "${resp}" ]; then resp=n; fi
          case "${resp}" in
            n* | N* )
              echo "Ok.  You can download the Tiger VNC viewer \(v1.12.0\) .exe yourself and "
              echo "place it in ${vnc_dir}/${vnc_exe}.  Then retry."
              echo "Exiting."
              exit 5
              ;;
            y* | Y* )
              wget -P "${vnc_dir}" https://sourceforge.net/projects/tigervnc/files/stable/1.12.0/vncviewer64-1.12.0.exe
              loop_done=true
              ;;
            * )
              echo "Answer not one of Y, y, N, or n.  Retry."
              ;;
          esac
        done
      fi
    fi
  fi
  #
  #  Start the log file so we can trace any issues with vnc, etc
  #
  LOG="${LOGINDIR}/logs/medley_${run_id}.log"
  mkdir -p "$(dirname -- "${LOG}")"
  echo "START" >"${LOG}"
  #
  #
  #set -x
  # are we running in background - used for pretty-fying the echos
  case $(ps -o stat= -p $$) in
    *+*) bg=false ;;
    *) bg=true ;;
  esac
  #
  #    find an unused display and an available port
  #
  #set -x
  OPEN_DISPLAY="$(find_open_display)"
  if [ "${OPEN_DISPLAY}" -eq -1 ];
  then
    echo "Error: cannot find an unused DISPLAY between 1 and 63"
    echo "Exiting"
    exit 33
  else
    if [ "${bg}" = true ]; then echo; fi
    echo "Using DISPLAY=:${OPEN_DISPLAY}"
  fi
  DISPLAY=":${OPEN_DISPLAY}"
  export DISPLAY
  VNC_PORT="$(find_open_port)"
  export VNC_PORT
  if [ "${VNC_PORT}" -eq -1 ];
  then
    echo "Error: cannot find an unused port between 5900 and 5999"
    echo "Exiting"
    exit 33
  else
    echo "Using VNC_PORT=${VNC_PORT}"
  fi
  #
  #  Start the Xvnc server
  #
  mkdir -p "${LOGINDIR}"/logs
  /usr/bin/Xvnc "${DISPLAY}" \
                -rfbport "${VNC_PORT}" \
                -geometry "${geometry}" \
                -SecurityTypes None \
                -NeverShared \
                -DisconnectClients=0 \
                -desktop "${title}" \
                --MaxDisconnectionTime=10 \
                >> "${LOG}" 2>&1 &

  sleep .5
  #
  # Run Maiko in background, handing over the pass-on args which are all thats left in the main args array
  #
  {
    start_maiko "$@"
    if [ -n "$(pgrep -f "${vnc_exe}.*:${VNC_PORT}")" ]; then vncconfig -disconnect; fi
  } &

  #
  #  Start the vncviewer on the windows side
  #

  #  First give medley time to startup
  #  sleep .25
  #  SLeep appears not to be needed, but faster/slower machines ????
  #  FGH 2023-02-08

  #  Then start vnc viewer on Windows side
  vncv_loc=$(( OPEN_DISPLAY * 50 ))
  start_time=$(date +%s)
  "${vnc_dir}"/${vnc_exe}                           \
               -geometry "+${vncv_loc}+${vncv_loc}" \
               -ReconnectOnError=off                \
               −AlertOnFatalError=off               \
               "$(ip_addr)":"${VNC_PORT}"           \
               >>"${LOG}" 2>&1                      &
  wait $!
  if [ $(( $(date +%s) - start_time )) -lt 5 ]
  then
    if [ -z "$(pgrep -f "Xvnc ${DISPLAY}")" ]
    then
      echo "Xvnc server failed to start."
      echo "See log file at ${LOG}"
      echo "Exiting"
      exit 3
    else
      echo "VNC viewer failed to start.";
      echo "See log file at ${LOG}";
      echo "Exiting" ;
      exit 4;
    fi
  fi
  #
  #  Done, "Go back" to medley_run.sh
  #
  true

#######################################
else
  # If not using vnc, just exec maiko directly
  # handing over the pass-on args which are all thats left in the main args array
  start_maiko "$@"
fi
exit ${exit_code}
