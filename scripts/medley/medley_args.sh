#!/bin/sh
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
# shellcheck disable=SC2034,SC2154,SC2164

# load usage function
. "${SCRIPTDIR}/medley_usage.sh"
args_stage="config file"

# Defaults
geometry=""
greet_specified=false
noscroll=false
pass_args=false
run_args=""
run_id="default"
screensize=""
sysout_arg=""
sysout_stage=""
title="Medley Interlisp"
use_vnc=false
windows=false
maikodir_arg=""
maikodir_stage=""
maikoprog="lde"

# Loop thru args and process
while [ "$#" -ne 0 ];
do
  if [ ${pass_args} = false ];
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
        check_for_dash_or_end "$1" "$2"
        run_args="${run_args} -d \"$2\""
        shift
        ;;
      -e | --interlisp)
        export MEDLEY_EXEC="inter"
        ;;
      -f | --full)
        sysout_arg="full"
        sysout_stage="${args_stage}"
        ;;
      -g | --geometry)
        check_for_dash_or_end "$1" "$2"
        geometry="$2"
        shift
        ;;
      -h | --help)
        usage
        ;;
      -i | --id)
        if [ "$2" = "-" ];
        then
          run_id=$( basename "${MEDLEYDIR}" )
        elif [ "$2" = "--" ];
        then
          run_id=$(cd "${MEDLEYDIR}/.."; basename "$(pwd)")
        else
          check_for_dash_or_end "$1" "$2"
          run_id=$(echo "$2" | sed "s/[^A-Za-z0-9]//g")
        fi
        shift
        ;;
      -k | --vmem)
        check_for_dash_or_end "$1" "$2"
        check_file_writeable_or_creatable "$1" "$2"
        export LDEDESTSYSOUT="$2"
        shift
        ;;
      -l | --lisp)
        sysout_arg="lisp"
        sysout_stage="${args_stage}"
        ;;
      -m | --mem)
        check_for_dash_or_end "$1" "$2"
        run_args="${run_args} -m \"$2\""
        shift
        ;;
      -n | --noscroll)
        noscroll=true
        run_args="${run_args} -noscroll"
        ;;
      -r | --greet)
        if [ "$2" = "-" ] || [ "$2" = "--" ]
        then
          run_args="${run_args} --nogreet"
        else
          check_for_dash_or_end "$1" "$2"
          check_file_readable "$1" "$2"
          run_args="${run_args} -greet \"$2\""
        fi
        greet_specified='true'
        shift
        ;;
      -s | --screensize)
        check_for_dash_or_end "$1" "$2"
        screensize="$2"
        shift
        ;;
      -t | --title)
        check_for_dash_or_end "$1" "$2"
        if [ -n "$2" ]; then title="$2"; fi
        shift
        ;;
      -u | --continue)
        sysout_arg=""
        sysout_stage="${args_stage}"
        ;;
      -v | --vnc)
        if [ "${wsl}" = true ] && [ "$(uname -m)" = x86_64 ]
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
      -x | --logindir)
        if [ "$2" = "-" ] || [ "$2" = "--" ]
        then
          check_dir_writeable_or_creatable "$1" "${MEDLEYDIR}/logindir"
          LOGINDIR="${MEDLEYDIR}/logindir"
        else
          check_for_dash_or_end "$1" "$2"
          check_dir_writeable_or_creatable "$1" "$2"
          LOGINDIR="$2"
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
      --maikodir)
        check_for_dash_or_end "$1" "$2"
        check_dir_exists "$1" "2"
        maikodir_arg="$2"
        maikodir_stage="${args_stage}"
        shift;
        ;;
      --maikoprog)
        check_for_dash_or_end "$1" "$2"
        maikoprog="$2"
        shift
        ;;
      --windows)
        # internal:  called from Windows medley.ps1 (via docker)
        windows=true
        ;;
      --start_cl_args)
        # internal: used to separate config file args from command line args
        args_stage="command line arguments"
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
    run_args="${run_args} \"$1\""
  fi
  shift
done

# Figure out screensize and geometry based on arguments
. "${SCRIPTDIR}/medley_geometry.sh"

# if running on WSL1, force use_vnc
if [ "${wsl}" = true ] && [ "${wsl_ver}" -eq 1 ]
then
  use_vnc=true
fi

