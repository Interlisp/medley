#!to_be_sourced_only
# shellcheck shell=sh

MEDLEYDIR=$(cd "${LOADUP_SCRIPTDIR}/.."; pwd)
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
    echo "Error: ${LOADUP_OUTDIR} exists but is not a directory. Exiting."
    exit 1
  fi
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




scr="-sc 1024x768 -g 1042x790"
geometry=1024x768

touch "${LOADUP_WORKDIR}"/loadup.timestamp

script_name=$(basename "$0" ".sh")
cmfile="${LOADUP_WORKDIR}/${script_name}.cm"

# look thru args looking to see if oldschool was specified in args
j=1
jmax=$#
while [ "$j" -le "$jmax" ]
do
  if [ "$(eval "printf %s \${${j}}")" = "-os" ] || [ "$(eval "printf %s \${${j}}")" = "--oldschool" ]
  then
    LOADUP_OLDSCHOOL=true
    export LOADUP_OLDSCHOOL
    break
  else
    j=$(( j + 1 ))
  fi
done


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
  rm -f "${cmfile}"
# 2024-05-05 FGH
# Can't use exit code for now since on MacOS exit codes appear to be inverted
# Will restore once MacOS exit code are figured out
#  if [ "${exit_code}" -ne 0 ] || [ ! -f "${LOADUP_WORKDIR}/$1" ]
  if [ ! -f "${LOADUP_WORKDIR}/$1" ]
  then
    echo "----- FAILURE -----"
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
        ls -l "${ff}" 2>/dev/null | grep -v "^.*~[0-9]\+~$"
      done
    done
  fi
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
  if [ ! "${LOADUP_OLDSCHOOL}" = true ]
  then
    /bin/sh "${MEDLEYDIR}/scripts/medley/medley.command"  \
             --config -                                          \
             --id loadup_+                                       \
             --geometry "${geometry}"                            \
             --noscroll                                          \
             --logindir "${LOADUP_LOGINDIR}"                     \
             --greet "${cmfile}"                                 \
             --sysout "$1"                                       \
             "$2" "$3" "$4" "$5" "$6" "$7"                       ;
    exit_code=$?
  else
    # shellcheck disable=SC2086
    "${MEDLEYDIR}/run-medley" ${scr} $2 $3 $4 $5 $6 $7 -loadup "${cmfile}" "$1"
    exit_code=$?
  fi

}

######################################################################


