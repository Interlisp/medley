
export MEDLEYDIR=`pwd`

# echo "%%%%%%%%%%%%%%%%%%%%%%%%%%%%%${LOADUP_WORKDIR}============="

if [ -z "${LOADUP_WORKDIR}" ];
then
  export LOADUP_WORKDIR=/tmp/loadups-$$
fi

mkdir -p "${LOADUP_WORKDIR}"

scr="-sc 1024x768 -g 1042x790"

touch "${LOADUP_WORKDIR}"/loadup.timestamp

loadup_finish () {
  echo "===== ${1}"
  if [ "${LOADUP_WORKDIR}/${2}" -nt "${LOADUP_WORKDIR}"/loadup.timestamp ];
  then
    echo "+++++ SUCCESS +++++"
    exit_code=0
  else
    echo "----- FAILURE -----"
    exit_code=1
  fi
  echo "===== files created ======"
    shift; shift
    for f in ${*};
    do
      ls -l "${LOADUP_WORKDIR}"/$f 2>/dev/null
    done
  echo "======================================="
  exit ${exit_code}
}



