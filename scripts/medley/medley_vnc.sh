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
    local ctr=1
    local result=-1
    while [ ${ctr} -lt 64 ];
    do
      ss -a | grep -q "tmp/.X11-unix/X${ctr}[^0-9]"
      if [ $? -ne 0 ];
      then
        result=${ctr}
        break
      else
        (( ctr++ ))
      fi
    done
    echo ${result}
  }

  find_open_port() {
    local ctr=5900
    local result=-1
    while [ ${ctr} -lt 6000 ];
    do
      ss -a | grep -q "LISTEN.*:${ctr}[^0-9]"
      if [ $? -ne 0 ];
      then
        result=${ctr}
        break
      else
        (( ctr++ ))
      fi
    done
    echo ${result}
  }

  #
  # Make sure prequisites for vnc support in wsl are in place
  #
  if [ "${use_vnc}" = "true" ];
  then
    win_userprofile="$(cmd.exe /c "<nul set /p=%UserProfile%" 2>/dev/null)"
    vnc_dir="$(wslpath ${win_userprofile})/AppData/Local/Interlisp"
    vnc_exe="vncviewer64-1.12.0.exe"
    if [[ $(which Xvnc) = "" || $(Xvnc -version |& grep -iq tigervnc; echo $?) -eq 1 ]];
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
        mkdir -p ${vnc_dir}
        cp -p "${IL_DIR}/wsl/${vnc_exe}" "${vnc_dir}/${vnc_exe}"
      else
        echo "TigerVnc viewer is required by the -vnc option but is not installed."
        echo -n "Ok to download from SourceForge? [y, Y, n or N, default n]  "
        read resp
        if [ -z ${resp} ]; then resp=n; else resp=${resp:0:1}; fi
        if [[ ${resp} = 'n' || ${resp} = 'N' ]];
        then
          echo "Ok.  You can download the Tiger VNC viewer \(v1.12.0\) .exe yourself and "
          echo "place it in ${vnc_dir}/${vnc_exe}.  Then retry."
          echo "Exiting."
          exit 5
        else
          pushd "${vnc_dir}" >/dev/null
          wget https://sourceforge.net/projects/tigervnc/files/stable/1.12.0/vncviewer64-1.12.0.exe
          popd >/dev/null
        fi
      fi
    fi
  fi
  #
  #  Start the log file so we can trace any issues with vnc, etc
  #
  LOG=${LOGINDIR}/logs/medley_${run_id}.log
  mkdir -p $(dirname -- ${LOG})
  echo "START" >${LOG}
  #
  # If we're running under docker:
  #    set the VNC_PORT to the value of the --port flag (or its default value)
  #    set DISPLAY to :0
  #
  if [ "${docker}" = "true" ];
  then
     VNC_PORT=5900
     export DISPLAY=:0
  else
    #  For not docker (i.e., for wsl/vnc)
    #    find an unused display and an available port
    #
    #set -x
    OPEN_DISPLAY=`find_open_display`
    if [ ${OPEN_DISPLAY} -eq -1 ];
    then
      echo "Error: cannot find an unused DISPLAY between 1 and 63"
      echo "Exiting"
      exit 33
    else
      echo "Using DISPLAY=${OPEN_DISPLAY}"
    fi
    export DISPLAY=":${OPEN_DISPLAY}"
    VNC_PORT=`find_open_port`
    if [ ${VNC_PORT} -eq -1 ];
    then
      echo "Error: cannot find an unused port between 5900 and 5999"
      echo "Exiting"
      exit 33
    else
      echo "Using VNC_PORT=${VNC_PORT}"
    fi
  fi
  #
  #  Start the Xvnc server
  #
  mkdir -p ${LOGINDIR}/logs
  /usr/bin/Xvnc "${DISPLAY}" \
                -rfbport ${VNC_PORT} \
                -geometry "${geometry#-g }" \
                -SecurityTypes None \
                -NeverShared \
                -DisconnectClients=0 \
                >> ${LOG} 2>&1 &
  xvnc_pid=""
  while [ -z ${xvnc_pid} ];
  do
    sleep .25
    xvnc_pid=$(ps h -C Xvnc -o pid,command | grep "Xvnc ${DISPLAY}" | awk '{print $1}')
  done
  # echo "XVNC_PID is ${xvnc_pid}"
  #
  # Run Medley in foreground if docker, else in background
  #
  cat >/tmp/run-medley_$$  <<-....EOF
    #!/bin/bash
    ${MEDLEYDIR}/run-medley -id "${run_id}" ${geometry} ${screensize} "${run_args[@]}" 2>>${LOG}
    kill -9 ${xvnc_pid} >>${LOG} 2>&1
....EOF
  chmod +x /tmp/run-medley_$$
  if [ "${docker}" = "true" ];
  then
    /tmp/run-medley_$$
  else
    /tmp/run-medley_$$ &
    #
    #  If not docker (i.e., if wsl/vnc), start the vncviewer on the windows side
    #
    #  First give medley time to startup
    sleep 2
    #  Then start vnc viewer on Windows side
    pushd ${vnc_dir} >/dev/null
    ( ./${vnc_exe} -geometry "+50+50" \
                   -ReconnectOnError=off \
                   −AlertOnFatalError=off \
                   $(ip_addr):${VNC_PORT} \
                   >>${LOG} 2>&1 \
      ; \
      kill -9 ${xvnc_pid} >>${LOG} 2>&1 \
    ) &
    popd >/dev/null
  fi
  #
  #  That's all
  #
