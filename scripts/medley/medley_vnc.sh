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
    local locked_pid=0
    while [ ${ctr} -lt 64 ];
    do
      if [ ! -e /tmp/.X${ctr}-lock ];
      then
        result=${ctr}
        break
      else
        locked_pid=$(cat /tmp/.X${ctr}-lock)
        ps lax | awk '{print $3}' | grep --quiet ${locked_pid} >/dev/null
        if [ $? -eq 1 ];
        then
          result=${ctr}
          break
        else
          (( ctr++ ))
        fi
      fi
    done
    echo ${result}
  }

  find_open_port() {
    local ctr=5900
    local result=-1
    while [ ${ctr} -lt 6000 ];
    do
      if [[ ${wsl} = true && ${wsl_ver} -eq 1 ]];
      then
        netstat.exe -a -n | awk '{ print $2 }' | grep -q ":${ctr}\$"
      else
        ss -a | grep -q "LISTEN.*:${ctr}[^0-9]"
      fi
      if [ $? -eq 1 ];
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
  #set -x
  if [ "${docker}" = "true" ];
  then
     export VNC_PORT=5900
     export DISPLAY=:0
  else
    # are we running in background - used for pretty-fying the echos
    case $(ps -o stat= -p $$) in
      *+*) bg=false ;;
      *) bg=true ;;
    esac
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
      if [ ${bg} = true ]; then echo; fi
      echo "Using DISPLAY=:${OPEN_DISPLAY}"
    fi
    export DISPLAY=":${OPEN_DISPLAY}"
    export VNC_PORT=`find_open_port`
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
                -desktop "${title}" \
                --MaxDisconnectionTime=10 \
                >> ${LOG} 2>&1 &

  # Leaving pid wait for all but docker,
  # which seems to need it.  For all others
  # it seems like its not needed but we'll have
  # to see how it runs on slower/faster machines
  # FGH 2023-02-16
  if [ ${docker} = true ];
  then
    xvnc_pid=""
    end_time=$(expr $(date +%s) + 10)
    while [ -z "${xvnc_pid}" ];
    do
      if [ $(date +%s) -gt $end_time ];
      then
         echo "Xvnc server failed to start."
         echo "See log file at ${LOG}"
         echo "Exiting"
         exit 3
      fi
      sleep .125
      xvnc_pid=$(pgrep -f "Xvnc ${DISPLAY}")
    done
    # echo "XVNC_PID is ${xvnc_pid}"
  fi
  #
  # Run Medley in foreground if docker, else in background
  #
  tmp_dir=$(if [[ -d /run/shm && ! -h /run/shm ]]; then echo "/run/shm"; else echo "/tmp"; fi)
  medley_run=$(mktemp --tmpdir=${tmp_dir} medley-XXXXX)
  cat > ${medley_run} <<..EOF
    #!/bin/bash
    ${MEDLEYDIR}/run-medley -id '${run_id}' ${geometry} ${screensize} ${run_args[@]} \
         2>&1 | tee -a ${LOG} | grep -v "broken (explicit kill"
    if [ -n "\$(pgrep -f "${vnc_exe}.*:${VNC_PORT}")" ]; then vncconfig -disconnect; fi
..EOF
  #cat ${medley_run}
  chmod +x ${medley_run}
  if [ "${docker}" = "true" ];
  then
    ${medley_run}; rm ${medley_run}
  else
    (${medley_run}; rm ${medley_run}) &
    #
    #  If not docker (i.e., if wsl/vnc), start the vncviewer on the windows side
    #

    #  First give medley time to startup
    #  sleep .25
    #  SLeep appears not to be needed, but faster/slower machines ????
    #  FGH 2023-02-08

    #  Then start vnc viewer on Windows side
    start_time=$(date +%s)
    ${vnc_dir}/${vnc_exe} \
                 -geometry "+50+50" \
                 -ReconnectOnError=off \
                 −AlertOnFatalError=off \
                 $(ip_addr):${VNC_PORT} \
                 >>${LOG} 2>&1 &
    wait $!
    if [ $( expr $(date +%s) - ${start_time} ) -lt 5 ];
    then
      if [ -z "$(pgrep -f "Xvnc ${DISPLAY}")" ];
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
  fi
  #
  #  Done, "Go back" to medley.sh
  #
  true

#######################################
