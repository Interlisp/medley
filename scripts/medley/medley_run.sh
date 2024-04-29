#!/bin/sh
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
# shellcheck disable=SC2154,SC2164,SC2086

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

# Figure out the sysout situation

loadups_dir="${MEDLEYDIR}/loadups"
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
fi

# Figure out screensize and geometry based on arguments
. "${SCRIPTDIR}/medley_geometry.sh"

# Figure out border with situation
borderwidth_flag=""
borderwidth_value=""
if [ -n "${borderwidth_arg}" ]
then
  borderwidth_flag="-bw"
  borderwidth_value="${borderwidth_arg}"
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
  nh_host_flag="-nethub-host"
  nh_host_value="${nh_host_arg}"
  if [ -n "${nh_port_arg}" ]
  then
    nh_port_flag="-nethub-port"
    nh_port_value="${nh_port_arg}"
  fi
  if [ -n "${nh_mac_arg}" ]
  then
    nh_mac_flag="-nethub-mac"
    nh_mac_value="${nh_mac_arg}"
  fi
  if [ -n "${nh_debug_arg}" ]
  then
    nh_debug_flag="-nethub-loglevel"
    nh_debug_value="${nh_debug_arg}"
  fi
fi

# Figure out the maiko executable name
# used for loadups (ldeinit)
if [ -z "${maikoprog_arg}" ]
then
  maikoprog_arg="lde"
fi

# Figure out the maiko directory maiko
check_if_maiko_dir () {
  if  { !  command -v "$1"/bin/osversion || ! command -v "$1"/bin/machinetype ; } >/dev/null || \
      [ ! -x "$1"/"$("$1"/bin/osversion)"."$("$1"/bin/machinetype)"/"${maikoprog_arg}" ]
  then
    return 1
  else
    return 0
  fi
}

if [ -z "${maikodir_arg}" ]
then
  if [ -d "${MEDLEYDIR}/maiko" ] && check_if_maiko_dir "${MEDLEYDIR}/maiko"
  then
    maikodir_arg="${MEDLEYDIR}/maiko"
  elif [ -d "${MEDLEYDIR}/../maiko" ] && check_if_maiko_dir "${MEDLEYDIR}/../maiko"
  then
    maikodir_arg="$(cd "${MEDLEYDIR}/../maiko"; pwd)"
  else
    err_msg="ERROR: Cannot find the directory containing the Maiko emulator in either
\"${MEDLEYDIR}/maiko\" or \"${MEDLEYDIR}/../maiko\".
Please use the --maikodir argument to specify the correct Maiko directory.
Exiting."
    output_error_msg "${err_msg}"
    exit 53
  fi
elif ! check_if_maiko_dir "${maikodir_arg}"
then
  err_msg="In ${maikodir_stage}:
ERROR: The value of the --maikodir argument is not in fact a directory containing
the Maiko emulator. Exiting."
  output_error_msg "${err_msg}"
  exit 53
fi

maiko="${maikodir_arg}/$("${maikodir_arg}"/bin/osversion).$("${maikodir_arg}"/bin/machinetype)/${maikoprog_arg}"


# Define function to start up maiko given all arguments
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
             ${maiko_args}                            ;
  echo "MEDLEYDIR: \"${MEDLEYDIR}\""
  echo "LOGINDIR: \"${LOGINDIR}\""
  echo "GREET FILE: \"${LDEINIT}\""
  echo "VMEM FILE: \"${LDEDESTSYSOUT}\""
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
             ${maiko_args}                            ;
}

# Run maiko either directly or with vnc
if [ "${wsl}" = true ] && [ "${use_vnc}" = true ]
then
  # do the vnc thing on wsl (if called for)
  . "${SCRIPTDIR}"/medley_vnc.sh
else
  # If not using vnc, just exec maiko directly
  start_maiko
fi
