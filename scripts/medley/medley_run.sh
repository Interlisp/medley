#!only-to-be-sourced
# shellcheck shell=sh
# shellcheck disable=SC2154,SC2164,SC2086
###############################################################################
#
#    medley_run.sh - script for processing actually running maiko/medley
#                    for the medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2024-04-21 Frank Halasz
#
#   Copyright 2024 Interlisp.org
#
###############################################################################

# Figure out LOGINDIR situation
if [ -z "${logindir_arg}" ]
then
  LOGINDIR="${HOME}/il"
else
  LOGINDIR="${logindir_arg}"
fi
export LOGINDIR

if [ ! -e "${LOGINDIR}" ];
then
  mkdir -p "${LOGINDIR}"
elif [ ! -d "${LOGINDIR}" ];
then
  echo "ERROR: Medley requires a directory named ${LOGINDIR}."
  echo "But ${LOGINDIR} exists but appears not be a directory."
  echo "Exiting"
  exit 2
fi
mkdir -p "${LOGINDIR}"/vmem

# Set LDEDESTSYSOUT env variable based on id
# if LDEDESRTSYSOUT has not already been set
# during arg processing
if [ -z "${vmem_arg}" ]
then
  if [ "${run_id}" = "default" ]
  then
    LDEDESTSYSOUT="${LOGINDIR}/vmem/lisp.virtualmem"
  else
    LDEDESTSYSOUT="${LOGINDIR}/vmem/lisp_${run_id}.virtualmem"
  fi
else
  LDEDESTSYSOUT="${vmem_arg}"
fi
export LDEDESTSYSOUT

# expand on use_branch, if needed

if [ "${use_branch}" = "-" ]
then
  git_commit_info "${MEDLEYDIR}"
  use_branch="${BRANCH}"
  if [ -z "${use_branch}" ]
  then
    output_warn_msg "A \"--branch -\" (\"-br -\") argument was given on the command line.${EOL}But either there is no git installed on this system or MEDLEYDIR (\"${MEDLEYDIR}\") is not a git directory.${EOL}Ignoring --branch argument.${EOL}"
  fi
fi

# clean use_branch of no alphanumeric chars

if [ -n "${use_branch}" ]
then
  use_branch="$(printf %s "${use_branch}" | sed "s/[^a-zA-Z0-9_.-]/_/g")"
fi

# Figure out the branch/loadupsdir situation

slash_branch=""
if [ -n "${use_branch}" ]
then
  branches_dir="${MEDLEYDIR}/loadups/branches"
  mkdir -p "${branches_dir}"
  matches="$(cd "${branches_dir}" && ls -d "${use_branch}"*)"
  echo ${matches}
  if [ -z "${matches}" ]
  then
    output_error_msg "The \"--branch ${use_branch}\" argument was given on the command line${EOL}but a directory matching \"${branches_dir}/${use_branch}*\" does not exist.${EOL}Exiting."
    exit 1
  else
    count=0
    new_branch=""
    for match in ${matches}
    do
      if [ "${match}" = "${use_branch}" ]
      then
        new_branch="${match}"
        count=1
        break
      else
        new_branch="${match}"
        count=$((count + 1))
      fi
    done
    if [ "${count}" -ge 2 ]
    then
      output_error_msg "The \"--branch ${use_branch}\" argument was given on the command line${EOL}but more than one subdirectory in \"${branches_dir}\" matches \"${use_branch}*\".${EOL}Exiting."
      exit 1
    else
      use_branch="${new_branch}"
    fi
    slash_branch="/branches/${use_branch}"
  fi
fi

loadups_dir="${MEDLEYDIR}/loadups${slash_branch}"
export MEDLEY_LOADUPS_DIR="${loadups_dir}"

# Figure out the sysout situation

if [ -z "${sysout_arg}" ]
then
  if [ -f "${LDEDESTSYSOUT}" ]
  then
    src_sysout="${LDEDESTSYSOUT}"
  else
    src_sysout="${loadups_dir}/full.sysout"
  fi
else
  case "${sysout_arg}" in
    lisp | full | apps)
      if [ ! -d "${loadups_dir}" ]
      then
        err_msg="Error: The sysout argument --${sysout_arg} was specified in ${sysout_stage},
but the directory \"${loadups_dir}\" where ${sysout_arg}.sysout is supposed to be located
cannot be found.
Exiting."
        output_error_msg "${err_msg}"
        exit 1
      fi
      src_sysout="${loadups_dir}/${sysout_arg}.sysout"
      ;;
    *)
      src_sysout="${sysout_arg}"
      ;;
  esac
fi
if [ ! -f "${src_sysout}" ]
then
    err_msg="Error: Cannot find the specified sysout file \"${src_sysout}\".
Exiting."
    output_error_msg "${err_msg}"
    exit 1
fi

# Figure out screensize and geometry based on arguments
# shellcheck source=./medley_geometry.sh
. "${SCRIPTDIR}/medley_geometry.sh"

# Figure out border width situation
borderwidth_flag=""
borderwidth_value=""
if [ -n "${borderwidth_arg}" ]
then
  borderwidth_flag="-bw"
  borderwidth_value="${borderwidth_arg}"
fi

# Figure out pixelscale situation
pixelscale_flag=""
pixelscale_value=""
if [ -n "${pixelscale_arg}" ]
then
  pixelscale_flag="-pixelscale"
  pixelscale_value="${pixelscale_arg}"
fi

# figure out greet files situation
if [ -z "${greet_arg}" ]
then
  if [ "${sysout_arg}" = "apps" ]
  then
    LDEINIT="${MEDLEYDIR}/greetfiles/APPS-INIT.LCOM"
  else
    LDEINIT="${MEDLEYDIR}/greetfiles/MEDLEYDIR-INIT.LCOM"
  fi
else
 if [ "${greet_arg}" = "--nogreet--" ]
  then
    LDEINIT="${MEDLEYDIR}/greetfiles/NOGREET"
  else
    LDEINIT="${greet_arg}"
  fi
fi
export LDEINIT

# figure out rem.cm and repeat.cm situation
export LDEREMCM="${remcm_arg}"
export LDEREPEATCM="${repeat_cm}"

# figure out noscroll situation
noscroll_arg=""
if [ "${noscroll}" = true ]
then
  noscroll_arg="-noscroll"
fi

# figure out -m situatiom
mem_flag=""
mem_value=""
if [ -n "${mem_arg}" ]
then
  mem_flag="-m"
  mem_value="${mem_arg}"
fi

# figure out the nethub situation
nh_host_flag=""
nh_host_value=""
nh_port_flag=""
nh_port_value=""
nh_mac_flag=""
nh_mac_value=""
nh_debug_flag=""
nh_debug_value=""
if [ -n "${nh_host_arg}" ]
then
  nh_host_flag="-nh-host"
  nh_host_value="${nh_host_arg}"
  if [ -n "${nh_port_arg}" ]
  then
    nh_port_flag="-nh-port"
    nh_port_value="${nh_port_arg}"
  fi
  if [ -n "${nh_mac_arg}" ]
  then
    nh_mac_flag="-nh-mac"
    nh_mac_value="${nh_mac_arg}"
  fi
  if [ -n "${nh_debug_arg}" ]
  then
    nh_debug_flag="-nh-loglevel"
    nh_debug_value="${nh_debug_arg}"
  fi
fi

# figure out the keyboard type
if [ -z "${LDEKBDTYPE}" ]; then
    export LDEKBDTYPE="X"
fi

# figure out title situation
if [ -z "${title}" ]
then
  title="Medley%b%i"
fi
if [ "${run_id}" = default ]
then
  title="$(printf %s "${title}" | sed -e "s/%i//")"
else
  title="$(printf %s "${title}" | sed -e "s/%i/::${run_id}/")"
fi
if [ -n "${use_branch}" ]
then
  short_branch="$(printf "%0.16s" "${use_branch}")"
  title="$(printf %s "${title}" | sed -e "s/%b/::${short_branch}/")"
else
  title="$(printf %s "${title}" | sed -e "s/%b//")"
fi

# Figure out the maiko executable name
# used for loadups (ldeinit)
if [ -z "${maikoprog_arg}" ]
then
  maikoprog_arg="lde"
fi

# Figure out the maiko directory maiko
check_if_maiko_dir () {
  if [ -d "$1" ] \
     && [ -d "$1/bin" ] \
     && [ -x "$1/bin/osversion" ] \
     && [ -x "$1/bin/machinetype" ]
  then
    maiko_exe_subdir="$("$1/bin/osversion").$("$1/bin/machinetype")"
    return 0
  fi
  return 1
}

check_for_maiko_exe () {
  if ! check_if_maiko_dir "$1"
  then
    return 1
  fi
  maiko_exe="$1/${maiko_exe_subdir}/${maikoprog_arg}"
  if [ -x "${maiko_exe}" ]
  then
    return 0
  else
    maiko_exe=""
    return 1
  fi
}

if [ -z "${maikodir_arg}" ]
then
  # No MAIKODIR specified.  But is lde (or ldeinit) on the PATH?
  # If so, use it.
  maiko_exe="$(command -v "${maikoprog_arg}")"
  if [ -z "${maiko_exe}" ]
  then
    # Lde (or ledinit) is not on the PATH, check in MEDLEYDIR/maiko and in MEDLEYDIR/../maiko
    if check_for_maiko_exe "${MEDLEYDIR}/maiko"
    then
      maikodir_arg="${MEDLEYDIR}/maiko"
    elif check_for_maiko_exe "${MEDLEYDIR}/../maiko"
    then
      maikodir_arg="$(cd "${MEDLEYDIR}/../maiko"; pwd)"
    else
      # Not in MEDLEYDIR/maiko and in MEDLEYDIR/../maiko, put out the appropriate error msg and exit
      if ! check_if_maiko_dir "${MEDLEYDIR}/maiko" && ! check_if_maiko_dir "${MEDLEYDIR}/../maiko"
      then
        err_msg="ERROR: The maiko executable ($maikoprog_arg) is not on the PATH and cannot find
the Maiko directory at either \"${MEDLEYDIR}/maiko\"
or \"${MEDLEYDIR}/../maiko\".
You can use the --maikodir argument or the MAIKODIR env variable
to specify the Maiko directory.
Exiting."
        output_error_msg "${err_msg}"
        exit 53
      else
        err_msg="ERROR: The maiko executable ($maikoprog_arg) is not on the PATH and cannot find
the Maiko executable (${maiko_exe_subdir}/${maikoprog_arg}) in either \"${MEDLEYDIR}/maiko\"
or \"${MEDLEYDIR}/../maiko\".
Exiting."
        output_error_msg "${err_msg}"
        exit 54
      fi
    fi
  fi
elif ! check_if_maiko_dir "${maikodir_arg}" || ! check_for_maiko_exe "${maikodir_arg}"
then
  # MAIKODIR is specified but lde (or ldeinit) is not in fact there.  Error exit.
  err_msg="In ${maikodir_stage}:
ERROR: The value provided by \$MAIKODIR or by the  --maikodir argument (${maikodir_arg}) is not
in fact a directory containing the Maiko emulator (${maiko_exe_subdir}/${maikoprog_arg}).
Exiting."
  output_error_msg "${err_msg}"
  exit 53
fi

maiko="${maiko_exe}"

# Define function to start up maiko given all arguments
# Arg to this function should be "$@", the main args
# array that at this point should just include the pass-on args
start_maiko() {
  echo \
  \"${maiko}\" \"${src_sysout}\"                      \
             -id \"${run_id}\"                        \
             -title \"${title}\"                      \
             -g ${geometry}                           \
             -sc ${screensize}                        \
             ${borderwidth_flag} ${borderwidth_value} \
             ${pixelscale_flag} ${pixelscale_value}   \
             ${noscroll_arg}                          \
             ${mem_flag} ${mem_value}                 \
             ${nh_host_flag} ${nh_host_value}         \
             ${nh_port_flag} ${nh_port_value}         \
             ${nh_mac_flag} ${nh_mac_value}           \
             ${nh_debug_flag} ${nh_debug_value}       \
             ${nofork_arg}                            \
             "$@"                                     ;
  echo "MEDLEYDIR: \"${MEDLEYDIR}\""
  echo "LOGINDIR: \"${LOGINDIR}\""
  echo "GREET FILE: \"${LDEINIT}\""
  echo "REM.CM FILE: \"${LDEREMCM}\""
  echo "VMEM FILE: \"${LDEDESTSYSOUT}\""
  #
  # Temp workaround for issues in Maiko sysout arg
  # processing. See Issue #1702.  FGH 2024-05-09
  #
  LDESOURCESYSOUT="${src_sysout}"
  export LDESOURCESYSOUT
  #
  # End work around
  #
  "${maiko}" "${src_sysout}"                          \
             -id "${run_id}"                          \
             -title "${title}"                        \
             -g "${geometry}"                         \
             -sc "${screensize}"                      \
             ${borderwidth_flag} ${borderwidth_value} \
             ${pixelscale_flag} ${pixelscale_value}   \
             ${noscroll_arg}                          \
             ${mem_flag} ${mem_value}                 \
             ${nh_host_flag} ${nh_host_value}         \
             ${nh_port_flag} ${nh_port_value}         \
             ${nh_mac_flag} ${nh_mac_value}           \
             ${nh_debug_flag} ${nh_debug_value}       \
             ${nofork_arg}                            \
             "$@"                                     ;
  exit_code=$?
}


# temp fix for cygwin to workaround issue #1685
# 2024-04-29
if [ "${cygwin}" = true ]
then
  MEDLEYDIR="${MEDLEYDIR}/"
fi


# Repeatedly run medley as long as there is a repeat_cm file called for and it exists and is not zero length
# In most cases, there will be no repeat_cm and hence medley will only run once

loop_ctr=0
while [ ${loop_ctr} -eq 0 ] || { [ -n "${repeat_cm}" ] && [ -f "${repeat_cm}" ] && [ -s "${repeat_cm}" ] ; }
do
  if [ ${loop_ctr} -eq 1 ]
  then
    LDEREMCM="${repeat_cm}"
  fi
  loop_ctr=1

  # Run maiko either directly or with vnc
  if [ "${use_vnc}" = true ]
  then
    # do the vnc thing - if called for
    # shellcheck source=./medley_vnc.sh
    . "${SCRIPTDIR}/medley_vnc.sh"
  else
    # If not using vnc, just exec maiko directly
    # handing over the pass-on args which are all thats left in the main args array
    start_maiko "$@"
  fi
  if [ -n "${exit_code}" ] && [ ${exit_code} -ne 0 ]
  then
    exit ${exit_code}
  fi

done
exit ${exit_code}
