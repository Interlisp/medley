#!only-to-be-sourced
# shellcheck shell=sh
# shellcheck disable=SC2154,SC2162
###############################################################################
#
#    medley_vnc.sh - script for running Medley Interlisp on WSL using Xvnc
#                on the Linux side and a vncviewer on the Windows side.
#                This script run under Linux will start the right apps
#                on both the Linux and Windows sides.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-12 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################

  ip_addr() {
    ip -4 -br address show dev eth0 | awk '{print $3}' | sed 's-/.*$--'
  }

  find_open_display() {
    local_ctr=1
    local_result=-1
    while [ ${local_ctr} -lt 64 ];
    do
      if [ ! -e /tmp/.X${local_ctr}-lock ];
      then
        local_result=${local_ctr}
        break
      else
        local_ctr=$(( local_ctr+1 ))
      fi
    done
    echo ${local_result}
  }

  find_open_port() {
    local_ctr=5900
    local_result=-1
    while [ ${local_ctr} -lt 6000 ];
    do
      if [ "${wsl}" = true ] && [ "${wsl_ver}" -eq 1 ]
      then
        netstat.exe -a -n | awk '{ print $2 }' | grep -q ":${local_ctr}\$"
      else
        ss -a | grep -q "LISTEN.*:${local_ctr}[^0-9]"
      fi
      if [ $? -eq 1 ];
      then
        local_result=${local_ctr}
        break
      else
        local_ctr=$(( local_ctr+1 ))
      fi
    done
    echo ${local_result}
  }

  #
  # Make sure prequisites for vnc support in wsl are in place
  #
  if [ "${use_vnc}" = "true" ];
  then
    win_userprofile="$(cmd.exe /c "<nul set /p=%UserProfile%" 2>/dev/null)"
    vnc_dir="$(wslpath "${win_userprofile}")/AppData/Local/Interlisp"
    vnc_exe="vncviewer64-1.12.0.exe"
    if [ "$(which Xvnc)" = "" ] || [ "$(Xvnc -version 2>&1 | grep -iq tigervnc; echo $?)" -eq 1 ]
    then
      echo "Error: The -v or --vnc flag was set."
      echo "But it appears that that TigerVNC \(Xvnc\) has not been installed."
      echo "Please install TigerVNC using \"sudo apt install tigervnc-standalone-server tigervnc-xorg-extension\""
      echo "Exiting."
      exit 4
    elif [ ! -e "${vnc_dir}/${vnc_exe}" ];
    then
      if [ -e "${IL_DIR}/wsl/${vnc_exe}" ];
      then
        # make sure TigerVNC viewer is in a Windows (not Linux) directory.  If its in a Linux directory
        # there will be a long delay when it starts up
        mkdir -p "${vnc_dir}"
        cp -p "${IL_DIR}/wsl/${vnc_exe}" "${vnc_dir}/${vnc_exe}"
      else
        loop_done=false
        while [ "${loop_done}" = "false" ]
        do
          echo "TigerVnc viewer is required by the -vnc option but is not installed."
          echo "Ok to download from SourceForge? [y, Y, n or N, default n]  "
          read resp
          if [ -z "${resp}" ]; then resp=n; fi
          case "${resp}" in
            n* | N* )
              echo "Ok.  You can download the Tiger VNC viewer \(v1.12.0\) .exe yourself and "
              echo "place it in ${vnc_dir}/${vnc_exe}.  Then retry."
              echo "Exiting."
              exit 5
              ;;
            y* | Y* )
              wget -P "${vnc_dir}" https://sourceforge.net/projects/tigervnc/files/stable/1.12.0/vncviewer64-1.12.0.exe
              loop_done=true
              ;;
            * )
              echo "Answer not one of Y, y, N, or n.  Retry."
              ;;
          esac
        done
      fi
    fi
  fi
  #
  #  Start the log file so we can trace any issues with vnc, etc
  #
  LOG="${LOGINDIR}/logs/medley_${run_id}.log"
  mkdir -p "$(dirname -- "${LOG}")"
  echo "START" >"${LOG}"
  #
  #
  #set -x
  # are we running in background - used for pretty-fying the echos
  case $(ps -o stat= -p $$) in
    *+*) bg=false ;;
    *) bg=true ;;
  esac
  #
  #    find an unused display and an available port
  #
  #set -x
  OPEN_DISPLAY="$(find_open_display)"
  if [ "${OPEN_DISPLAY}" -eq -1 ];
  then
    echo "Error: cannot find an unused DISPLAY between 1 and 63"
    echo "Exiting"
    exit 33
  else
    if [ "${bg}" = true ]; then echo; fi
    echo "Using DISPLAY=:${OPEN_DISPLAY}"
  fi
  DISPLAY=":${OPEN_DISPLAY}"
  export DISPLAY
  VNC_PORT="$(find_open_port)"
  export VNC_PORT
  if [ "${VNC_PORT}" -eq -1 ];
  then
    echo "Error: cannot find an unused port between 5900 and 5999"
    echo "Exiting"
    exit 33
  else
    echo "Using VNC_PORT=${VNC_PORT}"
  fi
  #
  #  Start the Xvnc server
  #
  mkdir -p "${LOGINDIR}"/logs
  /usr/bin/Xvnc "${DISPLAY}" \
                -rfbport "${VNC_PORT}" \
                -geometry "${geometry}" \
                -SecurityTypes None \
                -NeverShared \
                -DisconnectClients=0 \
                -desktop "${title}" \
                --MaxDisconnectionTime=10 \
                >> "${LOG}" 2>&1 &

  sleep .5
  #
  # Run Maiko in background, handing over the pass-on args which are all thats left in the main args array
  #
  {
    start_maiko "$@"
    if [ -n "$(pgrep -f "${vnc_exe}.*:${VNC_PORT}")" ]; then vncconfig -disconnect; fi
  } &

  #
  #  Start the vncviewer on the windows side
  #

  #  First give medley time to startup
  #  sleep .25
  #  SLeep appears not to be needed, but faster/slower machines ????
  #  FGH 2023-02-08

  #  Then start vnc viewer on Windows side
  vncv_loc=$(( OPEN_DISPLAY * 50 ))
  start_time=$(date +%s)
  "${vnc_dir}"/${vnc_exe}                           \
               -geometry "+${vncv_loc}+${vncv_loc}" \
               -ReconnectOnError=off                \
               −AlertOnFatalError=off               \
               "$(ip_addr)":"${VNC_PORT}"           \
               >>"${LOG}" 2>&1                      &
  wait $!
  if [ $(( $(date +%s) - start_time )) -lt 5 ]
  then
    if [ -z "$(pgrep -f "Xvnc ${DISPLAY}")" ]
    then
      echo "Xvnc server failed to start."
      echo "See log file at ${LOG}"
      echo "Exiting"
      exit 3
    else
      echo "VNC viewer failed to start.";
      echo "See log file at ${LOG}";
      echo "Exiting" ;
      exit 4;
    fi
  fi
  #
  #  Done, "Go back" to medley_run.sh
  #
  true

#######################################
