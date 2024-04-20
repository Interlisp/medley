#!/bin/sh
###############################################################################
#
#    medley.sh - script for running Medley Interlisp on Linux/WSL.
#                On Linux and WSL when using X Windows it just sets
#                up directories and environment variables and then calls
#                run-medley.  On WSL, there is an option to run without
#                or around X Windows by using the XVnc and a VNC viewer
#                on the Windows side.  This script will start this VNC viewer
#                on the Windows side.
#
#   2023-01-12 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################
# shellcheck disable=SC2164,SC2181,SC2009,SC2034

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
. "${SCRIPTDIR}"/medley_utils.sh

MEDLEYDIR="$(cd "${SCRIPTDIR}/../.."; pwd)"
export MEDLEYDIR
IL_DIR="$(cd "${MEDLEYDIR}/.."; pwd)"
export LOGINDIR="${HOME}/il"

# Are we running under Docker or WSL or Darwin or Cygwin?
#
docker=false
wsl=false
darwin=false

if [ "$(uname)" = "Darwin" ];
then
  darwin=true
elif [ -n "${MEDLEY_DOCKER_BUILD_DATE}" ];
then
  docker='true'
elif [ "$(uname -s | head --bytes 6)" != "CYGWIN" ];
then
  wsl_ver=0
  # WSL2
  grep --ignore-case --quiet wsl /proc/sys/kernel/osrelease
  if [ $? -eq 0 ];
  then
    wsl='true'
    wsl_ver=2
  else
    # WSL1
    grep --ignore-case --quiet microsoft /proc/sys/kernel/osrelease
    if [ $? -eq 0 ];
    then
      if [ "$(uname -m)" = "x86_64" ]
      then
        wsl='true'
        wsl_ver=1
      else
        echo "ERROR: Running Medley on WSL1 requires an x86_64-based PC."
        echo "This is not an x86_64-based PC."
        echo "Exiting"
        exit 23
      fi
    fi
  fi
fi

# process args
. "${SCRIPTDIR}"/medley_args.sh

# Make sure that there is not another instance currently running with this same id
ps ax | grep ldex | grep --quiet "\-id ${run_id}"
if [ $? -eq 0 ]
then
  echo "Another instance of Medley Interlisp is already running with the id \"${run_id}\"."
  echo "Only a single instance with a given id can be run at the same time."
  echo "Please retry using the \"--id <name>\" argument to give this new instance a different id."
  echo "Exiting"
  exit 3
fi

# Set LDEDESTSYSOUT env variable based on id
if [ -z "${LDEDESTSYSOUT}" ]
then
  if [ "${run_id}" = "default" ]
  then
    export LDEDESTSYSOUT="${LOGINDIR}/vmem/lisp.virtualmem"
  else
    export LDEDESTSYSOUT="${LOGINDIR}/vmem/lisp_${run_id}.virtualmem"
  fi
fi

# Create LOGINDIR if necessary
if [ ! -e "${LOGINDIR}" ];
then
  mkdir -p "${LOGINDIR}"
elif [ ! -d "${LOGINDIR}" ];
then
  echo "ERROR: Medley requires a directory named ${LOGINDIR}."
  echo "But ${LOGINDIR} exists appears not be a directory."
  echo "Exiting"
  exit 2
fi
mkdir -p "${LOGINDIR}"/vmem

# Call run-medley with or without vnc
if [ "${darwin}" = true ] || { { [ "${wsl}" = false ] || [ "${use_vnc}" = false ] ; } && [ "${docker}" = false ] ; }
then
  # If not using vnc, just call run-medley
  run="\"${MEDLEYDIR}/run-medley\" -id \"${run_id}\" -title \"${title}\" ${geometry} ${screensize} $run_args"
  eval "${run}"
else
  # do the vnc thing on wsl or docker
  . "${SCRIPTDIR}"/medley_vnc.sh
fi

