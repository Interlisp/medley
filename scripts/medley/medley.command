#!/bin/bash
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

#set -x

# functions to discover what directory this script is being executed from
get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

get_script_dir() {

    # call this with ${BASH_SOURCE[0]:-$0} as its (only) parameter

    # set -x

    local SCRIPT_PATH="$( get_abs_filename "$1" )";

    pushd . > '/dev/null';

    while [ -h "$SCRIPT_PATH" ];
    do
        cd "$( dirname -- "$SCRIPT_PATH"; )";
        SCRIPT_PATH="$( readlink -f -- "$SCRIPT_PATH"; )";
    done

    cd "$( dirname -- "$SCRIPT_PATH"; )" > '/dev/null';
    SCRIPT_PATH="$( pwd; )";

    popd  > '/dev/null';

    # set +x

    echo "${SCRIPT_PATH}"
}

SCRIPTDIR=$(get_script_dir "${BASH_SOURCE[0]:-$0}")
#  Define some generally useful functions
source ${SCRIPTDIR}/medley_utils.sh

export MEDLEYDIR=$(cd ${SCRIPTDIR}; cd ../..; pwd)
IL_DIR=$(cd ${MEDLEYDIR}; cd ..; pwd)
export LOGINDIR=${HOME}/il

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
elif [ $(uname -s | head --bytes 6) != "CYGWIN" ];
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
      if [ $(uname -m) = x86_64 ];
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
source ${SCRIPTDIR}/medley_args.sh

# Make sure that there is not another instance currently running with this same id
ps ax | grep ldex | grep --quiet "\-id ${run_id}"
if [ $? -eq 0 ];
then
  echo "Another instance of Medley Interlisp is already running with the id \"${run_id}\"."
  echo "Only a single instance with a given id can be run at the same time."
  echo "Please retry using the \"--id <name>\" argument to give this new instance a different id."
  echo "Exiting"
  exit 3
fi

# Set LDEDESTSYSOUT env variable based on id
if [ -z ${LDEDESTSYSOUT} ];
then
  if [ "${run_id}" = "default" ];
  then
    export LDEDESTSYSOUT=${LOGINDIR}/vmem/lisp.virtualmem
  else
    export LDEDESTSYSOUT=${LOGINDIR}/vmem/lisp_${run_id}.virtualmem
  fi
fi

# Create LOGINDIR if necessary
if [ ! -e ${LOGINDIR} ];
then
  mkdir -p ${LOGINDIR}
elif [ ! -d ${LOGINDIR} ];
then
  echo "ERROR: Medley requires a directory named ${LOGINDIR}."
  echo "But ${LOGINDIR} exists appears not be a directory."
  echo "Exiting"
  exit 2
fi
mkdir -p ${LOGINDIR}/vmem

# temp fix for cygwin to workaround issue #1685
# 2024-04-29
MEDLEYDIR_BASE="${MEDLEYDIR}"
if [ "$(uname -s | head --bytes 6)" = "CYGWIN" ]
then
  MEDLEYDIR="${MEDLEYDIR}/"
fi

# Call run-medley with or without vnc
if [[ ( ${darwin} = true ) || (( ${wsl} = false || ${use_vnc} = false ) && ${docker} = false) ]];
then
  # If not using vnc, just call run-medley
  ${MEDLEYDIR_BASE}/run-medley -id "${run_id}" -title "${title}" ${geometry} ${screensize} ${run_args[@]}
else
  # do the vnc thing on wsl or docker
  source ${SCRIPTDIR}/medley_vnc.sh
fi



