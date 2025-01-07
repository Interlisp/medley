#!to_be_sourced_only
# shellcheck shell=sh


MEDLEY_SCRIPTDIR="$(cd "${MEDLEYDIR}/scripts" && pwd)"

if [ -z "${APP_DIR}" ]
then
  export APP_DIR="$(cd "${LOADUP_SCRIPTDIR}/../" && pwd)"
fi

if [ ! -d "${APP_DIR}" ]
then
  echo "Error: Cannot find the LFG directory: ${APP_DIR}"
  exit 1
fi

if [ -z "${APP_LOADUPSDIR}" ]
then
  export APP_LOADUPSDIR="${APP_DIR}/loadups"
fi

if [ ! -d "${APP_LOADUPSDIR}" ]
then
  if [ -e "${APP_LOADUPSDIR}" ]
  then
    echo "Error: the lfg loadups dir (${APP_LOADUPSDIR}) exists, but it is not a directory."
    echo "Exiting."
    exit 1
  else
    mkdir -p "${APP_LOADUPSDIR}"
  fi
fi

if [ -z "${APP_WORKDIR}" ]
then
  export APP_WORKDIR="${APP_LOADUPSDIR}/build"
fi

if [ ! -d "${APP_WORKDIR}" ]
then
  if [ -e "${APP_WORKDIR}" ]
  then
    echo "Error: the lfg loadups work dir (${APP_WORKDIR}) exists, but it is not a directory."
    echo "Exiting."
    exit 1
  else
    mkdir -p "${APP_WORKDIR}"
  fi
fi

HAS_GIT= [ -f $(which git) ] && [ -x $(which git) ]
export HAS_GIT

git_commit_ID () {
  if ${HAS_GIT};
  then
    # This does NOT indicate if there are any modified files!
    COMMIT_ID=$(git -C "$1" rev-parse --short HEAD 2>/dev/null)
  fi
}

git_commit_ID "${MEDLEYDIR}"
MEDLEY_COMMIT_ID="${COMMIT_ID}"
export MEDLEY_COMMIT_ID

git_commit_ID "${APP_DIR}"
APP_COMMIT_ID="${COMMIT_ID}"
export APP_COMMIT_ID


scr="-sc 1024x768 -g 1042x790"
geometry=1024x768

touch "${APP_WORKDIR}"/loadup.timestamp

script_name=$(basename "$0" ".sh")
cmfile="${APP_WORKDIR}/${script_name}.cm"


######################################################################

loadup_start () {
  echo ">>>>> START ${script_name}"
}

loadup_finish () {
  rm -f "${cmfile}"
# 2024-05-05 FGH
# Can't use exit code for now since on MacOS exit codes appear to be inverted
# Will restore once MacOS exit code are figured out
#  if [ "${exit_code}" -ne 0 ] || [ ! -f "${LOADUP_WORKDIR}/$1" ]
  if [ ! -f "${APP_WORKDIR}/$1" ]
  then
    echo "----- FAILURE -----"
    exit_code=1
  else
    echo
    echo "..... files copied into loadups ....."
    for f in "$@"
    do
      # shellcheck disable=SC2045,SC2086
      for ff in $(ls -1 "${APP_WORKDIR}"/$f);
      do
        /bin/sh "${MEDLEY_SCRIPTDIR}/cpv" "${ff}" "${APP_LOADUPSDIR}"       \
                | sed -e "s#${APP_DIR}/##g"
      done
    done
    echo "....................................."
    echo
    echo "+++++ SUCCESS +++++"
    exit_code=0
  fi
  echo "<<<<< END ${script_name}"
  echo ""
  exit ${exit_code}
}

run_medley () {
    /bin/sh "${MEDLEYDIR}/scripts/medley/medley.command"  \
             --config -                                          \
             --id loadup_+                                       \
             --geometry "${geometry}"                            \
             --noscroll                                          \
             --logindir "${APP_WORKDIR}"                         \
             --greet "${cmfile}"                                 \
             --sysout "$1"                                       \
             "$2" "$3" "$4" "$5" "$6" "$7"                       ;
    exit_code=$?

}

######################################################################


