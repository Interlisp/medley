#!only-to-be-sourced
# shellcheck shell=sh
# shellcheck disable=SC2154
###############################################################################
#
#    medley_useage.sh - script defining the "usage" for medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2023-01-21 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################


PAGER=$( if [ -n "$(which more)" ]; then echo "more"; else echo "cat"; fi)

usage() {
   usage_msg_path=/tmp/msg-$$

   if [ "${wsl}" = true ];
   then
     wsl_incl="+w"
     wsl_excl="-w"
   else
     wsl_incl="-w"
     wsl_excl="+w"
   fi

   if [ "${docker}" = true ];
   then
     docker_incl="+d"
     docker_excl="-d"
   else
     docker_incl="-d"
     docker_excl="+d"
   fi

   if [ "${windows}" = true ];
   then
     windows_incl="+W"
     windows_excl="-W"
   else
     windows_incl="-W"
     windows_excl="+W"
   fi

   if [ $# -ne 0 ];
   then
     full_msg="In ${args_stage}:
$1"
     { echo; output_error_msg "${full_msg}"; echo; } >> "${usage_msg_path}"
   else
     touch "${usage_msg_path}"
   fi

   cat "${usage_msg_path}" - <<EOF \
       | sed -e "/^${docker_excl}/d" -e "s/^${docker_incl}/  /" \
       | sed -e "/^${wsl_excl}/d" -e "s/^${wsl_incl}/  /" \
       | sed -e "/^${windows_excl}/d" -e "s/^${windows_incl}/  /" \
       | ${PAGER}
Usage: medley [flags] [sysout] [--] [pass_args ...]

Note: MEDLEYDIR is the directory at the top of the code tree where this script is executed from
      after all symbolic links have been resolved.  For standard installations this will be
      /usr/local/interlisp/medley.  For "local" installations this will be the "medley" sub-directory
      under the directory into which the Medley distribution was installed.

flags:
    -h | --help                : print this usage information

    -z | --man                 : show the man page for medley

    -c FILE | --config FILE    : use FILE as the config file (default: ~/.medley_config)

    -f | --full                : start Medley from the "full" sysout

    -l | --lisp                : start Medley from the "lisp" sysout

    -a | --apps                : start Medley from the "apps" sysout

    -u | --continue            : start Medley from the vmem file from previous Medley run

    -y FILE | --sysout FILE    : start Medley using FILE as sysout

    -e | --interlisp           : (for apps.sysout only) Start in the Interlisp exec

    -n | --noscroll            : do not use scroll bars in Medley window

    -g WxH | --geometry WxH    : set the window geometry to Width x Height.

    -s WxH | --screensize WxH  : set the Medley screen size to be Width x Height

    -ps N | --pixelscale N     : use N as the pixel scale factor - for SDL display only

    -t STRING | --title STRING : use STRING as title of window

    -d :N | --display :N       : use X display :N
+w
+w  -v | --vnc                 : (WSL only) Use a VNC window instead of an X window

    -i STRING | --id STRING    : use STRING as the id for this run of Medley (default: default)

    -m N | --mem N             : set Medley memory size to N

    -k FILE | --vmem FILE      : use FILE as the Medley virtual memory store.

    -r FILE | --greet FILE     : use FILE as the Medley greetfile.

    -r - | --greet -           : do not use a greetfile

    -x DIR | --logindir DIR    : use DIR as LOGINDIR in Medley

    -x - | --logindir -        : use MEDLEYDIR/logindir as LOGINDIR in Medley

sysout:
    The pathname of the file to use as a sysout for Medley to start from.
    If sysout is not provided and none of the flags [-a, -f & -l] is used, then Medley will start from
    the saved virtual memory file for the previous run with the sane id as this run.

pass_args:
    All arguments after the "--" flag, are passed unaltered to the Maiko emulator.

EOF

exit 1

}

