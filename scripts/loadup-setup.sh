
export MEDLEYDIR=`pwd`

if [ -z "${LOADUP_WORKDIR}" ];
then
  export LOADUP_WORKDIR=/tmp/loadups-$$
fi

mkdir -p "${LOADUP_WORKDIR}"

scr="-sc 1024x768 -g 1042x790"

touch "${LOADUP_WORKDIR}"/loadup.timestamp


loadup_start () {
  echo ">>>>> START ${1}"
}

loadup_finish () {
  local script_name=${1}
  if [ "${LOADUP_WORKDIR}/${2}" -nt "${LOADUP_WORKDIR}"/loadup.timestamp ];
  then
    echo "+++++ SUCCESS +++++"
    exit_code=0
  else
    echo "----- FAILURE -----"
    exit_code=1
  fi
  echo "..... files created ....."
    shift; shift
    for f in ${*};
    do
      ls -l "${LOADUP_WORKDIR}"/$f 2>/dev/null
    done
  echo "<<<<< END ${script_name}"
  echo ""
  exit ${exit_code}
}



