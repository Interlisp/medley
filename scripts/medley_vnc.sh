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
   local ctr=11
   while [ `DISPLAY=":${ctr}" /usr/bin/xlsclients >/dev/null 2>/dev/null; echo \$?` -eq 0 ]
   do
     ((ctr++))
     if [ ${ctr} -gt 33 ];
     then
       echo "Error: cannot find an unused DISPLAY between 11 and 33"
       echo "Exiting"
       exit 33
     fi
   done
   echo "Using DISPLAY=":${ctr}"
  }

  screen_dimensions() {
    local dims="1440x900"
    while (( "$#" ))
    do
      case "$1" in
        "--dimensions" | "-dimensions" | "--geometry" | "-geometry" | "-g")
          dims=$2
          shift
          shift
          break
          ;;
        *)
          shift
          ;;
      esac
    done
    echo ${dims}
  }

  #
  # Make sure prequisites for vnc support are in place
  #
  vnc_dir="$(wslpath $(wslvar USERPROFILE))/AppData/Local/Interlisp"
  vnc_exe="vncviewer64-1.12.0.exe"
  if [[ $(which Xvnc) = "" || $(Xvnc -version |& grep -iq tigervnc; echo $?) -eq 1 ]];
  then
    echo "Error: The -v or --vnc flag was set."
    echo "But it appears that that TigerVNC (Xvnc) has not been installed."
    echo "Please install TigerVNC using \"sudo apt install tigervnc-standalone-server tigervnc-xorg-extension\""
    echo "Exiting."
    exit 4
  elif [ ! -e ${vnc_dir}/${vnc_exe} ];
  then
    if [ -e /usr/local/interlisp/wsl/${vnc_exe} ]
      # make sure TigerVNC viewer is in a Windows (not Linux) directory.  If its in a Linux directory
      # there will be a long delay when it starts up
      mkdir -p ${vnc_dir}
      cp -p /usr/local/interlisp/wsl/${vnc_exe} ${vnc_dir}/${vnc_exe}
    else
      echo "TigerVnc viewer is required by the -vnc option but is not installed."
      echo -n "Ok to download from SourceForge? [y, Y, n or N, default n]  "
      read resp
      if [ -z ${resp} ]; then resp=n; else resp=${resp:0:1}; fi
      if [[ ${resp} = 'n' || ${resp} = 'N' ]];
      then
        echo "Ok.  You can download the Tiger VNC viewer (v1.12.0) .exe yourself and "
        echo "place it in ${vnc_dir}/${vnc_exe}.  Then retry."
        echo "Exiting."
        exit 5
      else
        pushd ${vnc_dir} >/dev/null
        wget https://sourceforge.net/projects/tigervnc/files/stable/1.12.0/vncviewer64-1.12.0.exe
        popd >/dev/null
      fi
    fi
  fi


  #
  #  Find an unused display, startx/run-medley, then start the vnc viewer on the windows side
  #
  OPEN_DISPLAY=`find_open_display`
  PORT_FOR_DISPLAY=$((5900+OPEN_DISPLAY))
  export DISPLAY=":${OPEN_DISPLAY}"
  /usr/bin/startx ${MEDLEY_DIR}/run-medley $@ -- \
                  /usr/bin/Xvnc ":${OPEN_DISPLAY}" -geometry `screen_dimensions "$@"` -SecurityTypes None &
  #                2>/dev/null >/dev/null &
  sleep 2
  pushd ${vnc_dir} >/dev/null
  ./${vnc_exe} -ReconnectOnError=off −AlertOnFatalError=off `ip_addr`:${PORT_FOR_DISPLAY} >/dev/null 2>/dev/null &
  popd >/dev/null
