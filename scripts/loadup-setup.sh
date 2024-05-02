
MEDLEYDIR="$(pwd)"
export MEDLEYDIR

if [ -z "${LOADUP_WORKDIR}" ]
then
  LOADUP_WORKDIR=/tmp/loadups-$$
  export LOADUP_WORKDIR
fi

if [ -z "${LOADUP_SOURCEDIR}" ]
then
  LOADUP_SOURCEDIR="${MEDLEYDIR}/internal/loadups"
  export LOADUP_SOURCEDIR
fi

if [ -z "${LOADUP_OUTDIR}" ]
then
  LOADUP_OUTDIR="${MEDLEYDIR}/loadups"
  export LOADUP_OUTDIR
fi

if [ -z "${LOADUP_LOGINDIR}" ]
then
  LOADUP_LOGINDIR="${LOADUP_WORKDIR}/logindir"
  export LOADUP_LOGINDIR
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
geometry=1024x768

touch "${LOADUP_WORKDIR}"/loadup.timestamp

script_name=$(basename "$0" ".sh")
cmfile="${LOADUP_WORKDIR}/${script_name}.cm"


######################################################################

loadup_start () {
  echo ">>>>> START ${script_name}"
  if [ -d "${MEDLEYDIR}/tmp" ];
    then
      TMP_PRE_EXISTS="true"
      if [ -d "${MEDLEYDIR}/tmp/logindir" ];
      then
        LOGINDIR_PRE_EXISTS="true"
      else
        LOGINDIR_PRE_EXISTS="false"
      fi
    else
      LOGINDIR_PRE_EXISTS="false"
      TMP_PRE_EXISTS="false"
  fi
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
  if [ "${TMP_PRE_EXISTS}" = "false" ];
  then
    rm -rf "${MEDLEYDIR}/tmp"
  else
    if [ "${LOGINDIR_PRE_EXISTS}" = "false" ];
    then
      rm -rf "${MEDLEYDIR}/tmp/logindir"
    fi
  fi
  echo "<<<<< END ${script_name}"
  echo ""
  exit ${exit_code}
}

run_medley () {

  ./medley --geometry "${geometry}"                   \
           --noscroll                                 \
           --logindir "${LOADUP_LOGINDIR}"            \
           --greet "${cmfile}"                        \
           --sysout "$1"                              \
           "$2" "$3" "$4" "$5" "$6" "$7"              ;

  #./run-medley ${scr} $2 $3 $4 $5 $6 $7 -loadup "${cmfile}" "$1"

}


######################################################################


