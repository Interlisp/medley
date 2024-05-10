#!/bin/sh
# shellcheck disable=SC2164,SC2181,SC2009,SC2034,SC2154
. ./medley_header.sh
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
. "${SCRIPTDIR}/medley_utils.sh"

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
. "${SCRIPTDIR}/medley_configfile.sh"
# shellcheck source=./medley_args.sh
. "${SCRIPTDIR}/medley_args.sh"

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
. "${SCRIPTDIR}/medley_run.sh"
