#!to_be_sourced_only
# shellcheck shell=sh

MEDLEYDIR=$(cd "${LOADUP_SCRIPTDIR}/../.." || exit; pwd)
export MEDLEYDIR

export LOADUP_CPV="${MEDLEYDIR}/scripts/cpv"

if [ -z "${LOADUP_SOURCEDIR}" ]
then
  LOADUP_SOURCEDIR="${MEDLEYDIR}/internal/loadups"
  export LOADUP_SOURCEDIR
fi

git_commit_info () {
  if [ -f "$(command -v git)" ] && [ -x "$(command -v git)" ]
  then
    if git -C "$1" rev-parse >/dev/null 2>/dev/null
    then
      # This does NOT indicate if there are any modified files!
      COMMIT_ID="$(git -C "$1" rev-parse --short HEAD)"
      BRANCH="$(git -C "$1" rev-parse --abbrev-ref HEAD)"
    fi
  fi
}

git_commit_info "${LOADUP_SOURCEDIR}"
export LOADUP_COMMIT_ID="${COMMIT_ID}"
export LOADUP_BRANCH="${BRANCH}"

slash_branch=""
if [ -n "${LOADUP_BRANCH}" ] && [ "${use_branch}" = true ]
then
  slash_branch="/branches/${LOADUP_BRANCH}"
fi


if [ -z "${LOADUP_OUTDIR}" ]
then
    export LOADUP_OUTDIR="${MEDLEYDIR}/loadups${slash_branch}"
fi

if [ ! -d "${LOADUP_OUTDIR}" ];
then
  if [ ! -e "${LOADUP_OUTDIR}" ];
  then
    mkdir -p "${LOADUP_OUTDIR}"
  else
    echo "Error: ${LOADUP_OUTDIR} exists but is not a directory. Exiting."
    exit 1
  fi
fi

if [ -z "${LOADUP_WORKDIR}" ]
then
  LOADUP_WORKDIR="${LOADUP_OUTDIR}/build"
  export LOADUP_WORKDIR
fi

if [ ! -d "${LOADUP_WORKDIR}" ];
then
  if [ ! -e "${LOADUP_WORKDIR}" ];
  then
    mkdir -p "${LOADUP_WORKDIR}"
  else
    echo "Error: ${LOADUP_WORKDIR} exists but is not a directory. Exiting."
    exit 1
  fi
fi

if [ -z "${LOADUP_LOGINDIR}" ]
then
  LOADUP_LOGINDIR="${LOADUP_WORKDIR}/logindir"
  export LOADUP_LOGINDIR
fi

if [ ! -d "${LOADUP_LOGINDIR}" ];
then
  if [ ! -e "${LOADUP_LOGINDIR}" ];
  then
    mkdir -p "${LOADUP_LOGINDIR}"
  else
    echo "Error: ${LOADUP_LOGINDIR} exists but is not a directory. Exiting."
    exit 1
  fi
fi

# obsolete? scr="-sc 1024x768 -g 1042x790"
geometry=1024x768

touch "${LOADUP_WORKDIR}"/loadup.timestamp

script_name=$(basename "$0" ".sh")
cmfile="${LOADUP_WORKDIR}/${script_name}.cm"
initfile="${LOADUP_WORKDIR}/${script_name}.init"


# Select whether we use NLSETQ or ERSETQ to wrap the loadup
# cm files depending on whether we want to allow breaks or not.
# shellcheck disable=SC2034
if [ -n "${LOADUP_NOBREAK}" ]
then
  HELPFLAG=NIL
  NL_ER_SETQ=IL:NLSETQ
else
  HELPFLAG="(QUOTE IL:BREAK!)"
  NL_ER_SETQ=IL:ERSETQ
fi

######################################################################

loadup_start () {
  touch "${LOADUP_WORKDIR}"/timestamp
  sleep 1
  echo ">>>>> START ${script_name}"
}

loadup_finish () {

  if [ ! "${cmfile}" = "-" ]; then rm -f "${cmfile}"; fi
  if [ ! "${initfile}" = "-" ]; then rm -f "${initfile}"; fi

  if [ "${exit_code}" -ne 0 ] || [ ! -f "${LOADUP_WORKDIR}/$1" ] \
     || [ ! "$( find "${LOADUP_WORKDIR}/$1" -newer "${LOADUP_WORKDIR}"/timestamp )" ]
  then
    output_error_msg "----- FAILURE ${script_name}-----"
    exit_code=1
  else
    echo "+++++ SUCCESS +++++"
    exit_code=0
  fi
  echo "..... files created ....."
  if [ -f "${LOADUP_WORKDIR}/$1" ]
  then
    shift;
    for f in "$@"
    do
      # shellcheck disable=SC2045,SC2086
      for ff in $(ls -1 "${LOADUP_WORKDIR}"/$f);
      do
        # shellcheck disable=SC2010
        if [ "$( find "${ff}" -newer "${LOADUP_WORKDIR}"/timestamp )" ]
        then
          ls -l "${ff}" 2>/dev/null | grep -v "^.*~[0-9]\+~$"
        fi
      done
    done
  fi
  echo "<<<<< END ${script_name}"
  echo ""

  exit ${exit_code}
}

force_vnc="-"
run_medley () {
    /bin/sh "${MEDLEYDIR}/scripts/medley/medley.command"         \
             --config -                                          \
             --id loadup_+                                       \
             --geometry "${geometry}"                            \
             --noscroll                                          \
             --logindir "${LOADUP_LOGINDIR}"                     \
             --rem.cm "${cmfile}"                                \
             --greet "${initfile}"                               \
             --sysout "$1"                                       \
             --vnc "${LOADUP_USE_VNC}"                           \
             --automation                                        \
             "$2" "$3" "$4" "$5" "$6" "$7"                       ;
    exit_code=$?
}

is_tput="$(command -v tput)"
if [ -z "${is_tput}" ]
then
  is_tput="$(command -v true)"
fi


EOL="
"
output_error_msg() {
  local_oem_file="${TMPDIR:-/tmp}"/oem_$$
  echo "$1" >"${local_oem_file}"
  while read -r line
  do
      echo "$(${is_tput} setab 1)$(${is_tput} setaf 7)${line}$(${is_tput} sgr0)"
  done <"${local_oem_file}"
  rm -f "${local_oem_file}"
}

output_warn_msg() {
  local_oem_file="${TMPDIR:-/tmp}"/oem_$$
  echo "$1" >"${local_oem_file}"
  while read -r line
  do
      echo "$(${is_tput} setab 3)$(${is_tput} setaf 4)${line}$(${is_tput} sgr0)"
  done <"${local_oem_file}"
  rm -f "${local_oem_file}"
}

exit_if_failure() {
  if [ "$1" -ne 0 ]
  then
    if [ ! "$2" = "true" ]
    then
      output_error_msg  "----- ${script_name}: FAILURE -----${EOL}"
    fi
    remove_run_lock
    exit 1
  fi
}

process_maikodir() {
        # process --maikodir argument.  Only use when --maikodir is only possible argument
        while [ "$#" -ne 0 ];
      	do
          case "$1" in
            -d | -maikodir | --maikodir)
              if [ -n "$2" ]
              then
                maikodir=$(cd "$2" 2>/dev/null && pwd)
                if [ -z "${maikodir}" ] || [ ! -d "${maikodir}" ]
                then
                  output_error_msg "Error: In --maikodir (-d) command line argument, \"$2\" is not an existing directory.${EOL}Exiting"
                  exit 1
                fi
              else
                output_error_msg "Error: Missing value for the --maikodir (-d) command line argument.${EOL}Exiting"
                exit 1
              fi
              export MAIKODIR="${maikodir}"
              shift
              ;;
            *)
              output_error_msg "Error: unknown flag: $1${EOL}Exiting"
              exit 1
              ;;
          esac
          shift
	done
}

export LOADUP_LOCKFILE="${LOADUP_WORKDIR}"/lock
LOADUP_LOCK=""
override_lock=false
ignore_lock=false

check_run_lock() {
  if [ "${ignore_lock}" = false ]
  then
    if [ -e "${LOADUP_LOCKFILE}" ]
    then
      output_warn_msg "Warning: Another loadup is already running with PID $(cat "${LOADUP_LOCKFILE}")"
      if [ "${override_lock}" = true ]
      then
	output_warn_msg "Overriding lock preventing simultaneous loadups due to command line argument --override${EOL}Continuing."
      else
        loop_done=false
        while [ "${loop_done}" = "false" ]
        do
          output_warn_msg "Do you want to override the lock guarding against simultaneous loadups?"
          output_warn_msg "Answer [y, Y, n or N, default n] followed by RETURN"
          read resp
          if [ -z "${resp}" ]; then resp=n; fi
          case "${resp}" in
            n* | N* )
              output_error_msg "Ok.  Exiting"
              exit 5
              ;;
            y* | Y* )
              output_warn_msg "Ok. Overriding lock and continuing"
              loop_done=true
              ;;
            * )
              output_warn_msg "Answer not one of Y, y, N, or n.  Retry."
              ;;
          esac
        done
      fi
    fi
    echo "$$" > "${LOADUP_LOCKFILE}"
    LOADUP_LOCK="$$"
  fi
}

remove_run_lock() {
  if [ -n "${LOADUP_LOCK}" ]
  then
    rm -f "${LOADUP_LOCKFILE}"
  fi
}


######################################################################


