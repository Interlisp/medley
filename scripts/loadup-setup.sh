
export MEDLEYDIR=`pwd`

if [ -z "${LOADUP_WORKDIR}" ];
then
  export LOADUP_WORKDIR=/tmp/loadups-$$
fi

mkdir -p "${LOADUP_WORKDIR}"

scr="-sc 1024x768 -g 1042x790"

touch "${LOADUP_WORKDIR}"/loadup.timestamp

script_name=$(basename "$0" ".sh")
cmfile="${LOADUP_WORKDIR}/${script_name}.cm"


######################################################################

loadup_start () {
  echo ">>>>> START ${script_name}"
}

loadup_finish () {
  local exit_code
  rm -f "${cmfile}"
  if [ "${LOADUP_WORKDIR}/${1}" -nt "${LOADUP_WORKDIR}"/loadup.timestamp ];
  then
    echo "+++++ SUCCESS +++++"
    exit_code=0
  else
    echo "----- FAILURE -----"
    exit_code=1
  fi
  echo "..... files created ....."
    shift;
    for f in ${*};
    do
      for ff in $(ls -1 "${LOADUP_WORKDIR}"/$f);
      do
        if [ "${ff}" -nt "${LOADUP_WORKDIR}"/loadup.timestamp ];
        then
          ls -l ${ff} 2>/dev/null | grep -v "^.*~[0-9]\+~$"
        fi
      done
    done
  echo "<<<<< END ${script_name}"
  echo ""
  exit ${exit_code}
}

######################################################################


