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
#

export IL_DIR=/usr/local/interlisp
export MEDLEYDIR=${IL_DIR}/medley
export LOGINDIR=${HOME}/il

# Are we running under WSL?
grep --ignore-case --quiet wsl /proc/sys/kernel/osrelease
if [ $? -eq 0 ];
then
  wsl='true'
else
  wsl='false'
fi

# Process args
run_args=""
run_id="default"
use_vnc='false'
while [ "$#" -ne 0 ]; 
do
  case "$1" in
    -i | --id)
      run_id=$(echo "$2" | sed s/[^A-Za-z0-9]//g)
      shift
      ;;
    -v | --vnc)
      if [[ ${wsl} = true && $(uname -m) = x86_64 ]];
      then
        use_vnc=true
      else
        echo "Warning: The -v or --vnc flag was set."
        echo "But the vnc option is only available when running on "
        echo "Windows System for Linux (wsl) on x86_64 machines."
        echo "Ignoring the -v or --vnc flag."
        use_vnc=false
      fi
      ;;
    *)
      run_args="${run_args} $1"
      ;;
  esac
  shift
done

# Make sure that there is not another instance currently running with this same id
ps ax | grep ldex | grep --quiet "\-id ${run_id}"
if [ $? -eq 0 ];
then
  echo "Another instance of Medley Interlisp is already running with the id \"${run_id}\".
  echo "Only a single instance with a given id can be run at the same time."
  echo "Please retry using the \"-id <name>\" argument to give this new instance a different id."
  echo "Exiting"
  exit 3
fi

# Set the LDEDESTSYSOUT env variable based on id
if [ "${run_id}" = "default" ];
then
  export LDEDESTSYSOUT=${LOGINDIR}/vmem/lisp.virtualmem
else
  export LDEDESTSYSOUT=${LOGINDIR}/vmem/lisp_${run_id}.virtualmem
fi

# Create LOGINDIR if necessary
if [ ! -e ${LOGINDIR} ];
then
  mkdir -p ${LOGINDIR}
elif [ ! -d ${LOGINDIR} ];
  echo "ERROR: Medley requires a directory named ${LOGINDIR}."
  echo "But ${LOGINDIR} exists appears not be a directory."
  echo "Exiting"
  exit 2
fi
mkdir -p ${LOGINDIR}/vmem

if [[ ${wsl} = 'false' || ${use_vnc} = 'false' ];
then
  # If not using vnc, just call run-medley
  ${MEDLEY_DIR}/run-medley -id ${run_id} ${run_args}
else
  # do the vnc thing on wsl
  source ${MEDLEY_DIR}/scripts/medley_vnc.sh
fi


