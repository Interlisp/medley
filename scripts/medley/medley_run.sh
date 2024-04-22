#!/bin/sh
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
# xshellcheck disable=

# Figure out the maiko directory maiko
check_if_maiko_dir () {
  command -v "$1"/bin/osversion
  return $?
}

if [ -n "${maikodir_arg}" ] && [ ! check_if_maiko_dir "${maikodir_arg}" ]
then
  err_msg="In ${maikodir_stage}:
ERROR: The value of the --maikodir argument is not in fact a directory containing
the Maiko emulator. Exiting."
  output_error_msg "${err_msg}"
  exit 53
elif [ -n "${MAIKODIR}" ]
then
  if [ ! -d "${MAIKODIR}" ] || [ ! check_if_maiko_dir "${MAIKODIR}" ]
  then
    err_msg="ERROR: The value of the MAIKODIR environment variable is not in fact
a directory containing the Maiko emulator.
Exiting."
    output_error_msg "${err_msg}"
    exit 53
  fi
elif [ -d "${MEDLEYDIR}/maiko" ] && [ check_if_maiko_dir "${MEDLEYDIR}/maiko" ]
then
  MAIKODIR="${MEDLEYDIR}/maiko"
elif [ -d "${MEDLEYDIR}/../maiko" ] && [ check_if_maiko_dir "${MEDLEYDIR}/../maiko" ]
  MAIKODIR="$(cd "${MEDLEYDIR}/../maiko"; pwd)"
else
   err_msg="ERROR: Cannot find the directory containing the Maiko emulator.
Please use the --maikodir argument to specify the correct Maiko directory.
Exiting."
    output_error_msg "${err_msg}"
    exit 53
fi












# Figure out the sysout situation
if [ "${sysout_arg}" = "apps" ];
then
  export LDESRCESYSOUT="${MEDLEYDIR}/loadups/apps.sysout"
  if [ "${greet_specified}" = "false" ];
  then
    export LDEINIT="${MEDLEYDIR}/greetfiles/APPS-INIT.LCOM"
  fi
else
  # pass on to run-medley
  unset LDESRCESYSOUT
  if [ -n "${sysout_arg}" ]
  then
    run_args="${run_args} \"${sysout_arg}\""
  fi
fi


