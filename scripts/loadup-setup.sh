
export MEDLEYDIR=`pwd`

if [ -z "${LOADUP_WORKDIR}" ];
then
  export LOADUP_WORKDIR=/tmp/loadups-$$
fi

if [ -z "${LOADUP_SOURCEDIR}" ];
then
  export LOADUP_SOURCEDIR="${MEDLEYDIR}"/internal/loadups
fi

if [ -z "${LOADUP_OUTDIR}" ];
then
  export LOADUP_OUTDIR="${MEDLEYDIR}"/loadups
fi

if [ ! -d "${LOADUP_OUTDIR}" ];
then
  if [ ! -e "${LOADUP_OUTDIR}" ];
  then
    mkdir -p "${LOADUP_OUTDIR}"
  else
    "Error: ${LOADUP_OUTDIR} exists but is not a directory. Exiting."
  fi
fi

if [ ! -d "${LOADUP_WORKDIR}" ];
then
  if [ ! -e "${LOADUP_WORKDIR}" ];
  then
    mkdir -p "${LOADUP_WORKDIR}"
  else
    "Error: ${LOADUP_WORKDIR} exists but is not a directory. Exiting."
  fi
fi


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
  if [ "${LOADUP_WORKDIR}"/loadup.timestamp -nt "${LOADUP_WORKDIR}/${1}"  ];
  then
    echo "----- FAILURE -----"
    exit_code=1
  else
    echo "+++++ SUCCESS +++++"
    exit_code=0
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


