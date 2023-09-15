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
source ${SCRIPTDIR}/medley_usage.sh

# Defaults
apps_flag=false
err_msg=""
full_flag=false
geometry=""
greet_specified=false
lisp_flag=false
noscroll=false
pass_args=false
run_args=()
run_id="default"
screensize=""
sysout_flag=false
sysout_arg=""
use_vnc=false
windows=false

# Loop thru args and process
while [ "$#" -ne 0 ];
do
  if [ ${pass_args} = false ];
  then
    case "$1" in
      -a | --apps)
        sysout_arg="apps"
        apps_flag=true
        ;;
      -d | --display)
        check_for_dash_or_end "$1" "$2"
        run_args+=(-d $2)
        shift
        ;;
      -e | --interlisp)
        export MEDLEY_EXEC="inter"
        ;;
      -f | --full)
        sysout_arg="-full"
        full_flag=true
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
          run_id=$( basename ${MEDLEYDIR} )
        elif [ "$2" = "--" ];
        then
          run_id=$(cd ${MEDLEYDIR}; cd ..; basename $(pwd))
        else
          check_for_dash_or_end "$1" "$2"
          run_id=$(echo "$2" | sed s/[^A-Za-z0-9]//g)
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
        sysout_arg="-lisp"
        lisp_flag=true
        ;;
      -m | --mem)
        check_for_dash_or_end "$1" "$2"
        run_args+=(-m $2)
        shift
        ;;
      -n | --noscroll)
        noscroll=true
        run_args+=("-noscroll")
        ;;
      -r | --greet)
        if [[ "$2" = "-" || "$2" = "--" ]];
        then
          run_args+=("--nogreet")
        else
          check_for_dash_or_end "$1" "$2"
          check_file_readable "$1" "$2"
          run_args+=("-greet" "$2")
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
        run_args+=(-title $2)
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
      -x | --logindir)
        if [[ "$2" = "-" || "$2" = "--" ]];
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
      -z | --man)
        /usr/bin/man -l "${MEDLEYDIR}/docs/man-page/medley.1.gz"
        exit 0
        ;;
      --windows)
        # internal:  called from Windows medley.ps1 (via docker)
        windows=true
        ;;
      --)
        pass_args=true
        ;;
      -*)
        err_msg=("ERROR: Unknown flag: $1" )
        usage "${err_msg[@]}"
        ;;
      *)
        if [[ $# -eq 1 || "$2" = "--" ]];
        then
          sysout_flag=true
          sysout_arg="$1"
        else
          err_msg=(
            "ERROR: sysout argument must be last argument"
            "or last argument before the \"--\" flag"
          )
          usage "${err_msg[@]}"
        fi
        ;;
    esac
  else
    run_args+=("$1")
  fi
  shift
done

# Figure out screensize and geometry based on arguments
source ${SCRIPTDIR}/medley_geometry.sh

# Figure out the sysout situation
ctr=0
for x in ${lisp_flag} ${full_flag} ${apps_flag} ${sysout_flag};
do
  if [ "${x}" = "true" ];
  then
    (( ctr++ ))
  fi
done
if [ ${ctr} -gt 1 ];
then
  err_msg=(
    "Error: only one sysout can be specified.  Two or more sysouts were specified"
    "via the -l (--lisp), -f (--full), -a (--apps) flags and/or a sysout filename"
  )
  usage "${err_msg[@]}"
fi
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
  if [ -n "${sysout_arg}" ];
  then
    run_args+=("${sysout_arg}")
  fi
fi

# if running on WSL1, force use_vnc
if [[ ${wsl} = true && ${wsl_ver} -eq 1 ]];
then
  use_vnc=true
fi

