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
export MEDLEYDIR=$(cd ${SCRIPTDIR}; cd ../..; pwd)
IL_DIR=$(cd ${MEDLEYDIR}; cd ..; pwd)
export LOGINDIR=${HOME}/il

# Are we running under WSL?
grep --ignore-case --quiet wsl /proc/sys/kernel/osrelease
if [ $? -eq 0 ];
then
  wsl='true'
else
  wsl='false'
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

# Set the LDEDESTSYSOUT env variable based on id
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

# Call run-medley with or without vnc
if [[ ${wsl} = false || ${use_vnc} = false ]];
then
  # If not using vnc, just call run-medley
  ${MEDLEYDIR}/run-medley -id "${run_id}" ${geometry} ${screensize} "${run_args[@]}"
else
  # do the vnc thing on wsl
  source ${SCRIPTDIR}/medley_vnc.sh
fi


