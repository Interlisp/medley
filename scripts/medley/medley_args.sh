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

# Process args
run_args=()
run_id="default"
use_vnc='false'
geometry=""
screensize=""
noscroll='false'
pass_args=false
lisp_flag=false
full_flag=false
apps_flag=false
sysout_flag=false
sysout_arg=""
while [ "$#" -ne 0 ];
do
  if [ ${pass_args} = false ];
  then
    case "$1" in
      -i | --id)
        if [ "$2" = "-" ];
        then
          run_id=$( basename ${MEDLEYDIR} )
        else
          check_for_dash "$1" "$2"
          run_id=$(echo "$2" | sed s/[^A-Za-z0-9]//g)
        fi
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
      -g | --geometry)
        check_for_dash "$1" "$2"
        geometry="$2"
        shift
        ;;
      -s | --screensize)
        check_for_dash "$1" "$2"
        screensize="$2"
        shift
        ;;
      -n | --noscroll)
        noscroll=true
        run_args+=("-noscroll")
        ;;
      -e | --interlisp)
        export MEDLEY_EXEC="inter"
        ;;
      -a | --apps)
        sysout_arg="apps"
        apps_flag=true
        ;;
      -f | --full)
        sysout_arg="-full"
        full_flag=true
        ;;
      -l | --lisp)
        sysout_arg="-lisp"
        lisp_flag=true
        ;;
      -m | --mem)
        check_for_dash "$1" "$2"
        run_args+=(-m $2)
        shift
        ;;
      -t | --title)
        check_for_dash "$1" "$2"
        run_args+=(-title $2)
        shift
        ;;
      -d | --display)
        check_for_dash "$1" "$2"
        run_args+=(-d $2)
        shift
        ;;
      -r | --greet)
        if [[ "$2" = "-n" || "$2" = "--nogreet" ]];
        then
          run_args+=("--nogreet")
        else
          check_for_dash "$1" "$2"
          run_args+=(-greet "$2")
        fi
        ;;
      -p | --vmem)
        check_for_dash "$1" "$2"
        export LDEDESTSYSOUT="$2"
        shift
        ;;
      -h | --help)
        usage
        ;;
      --)
        pass_args=true
        ;;
      -*)
        echo "ERROR: Unknown flag: $1"
        usage
        ;;
      *)
        if [[ $# -eq 1 || "$2" = "--" ]];
        then
          sysout_flag=true
          sysout_arg="$2"
        else
          echo "ERROR: sysout argument must be last argument"
          echo "or last argument before the \"--\" flag"
          usage
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
  echo "Error: only one sysout can be specified.  Two or more sysouts were specified"
  echo "via the -l (--lisp), -f (--full), -a (--apps) flags and/or a sysout filename"
  echo
  usage
fi
if [ "${sysout_arg}" = "apps" ];
then
  export LDESRCESYSOUT="$MEDLEYDIR/loadups/apps.sysout"
  export LDEINIT="$MEDLEYDIR/greetfiles/APPS-INIT.LCOM"
else
  # pass on to run-medley
  run_args+=("${sysout_arg}")
fi


