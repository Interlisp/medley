#!only-to-be-sourced
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
. "${SCRIPTDIR}/medley_usage.sh"
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

