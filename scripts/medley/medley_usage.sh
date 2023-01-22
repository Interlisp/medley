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


usage() {
   cat <<EOF
Usage: medley [flags] [sysout] [--] [pass_args ...]

flags:
    -h | --help                : print this usage information

    -f | --full                : start Medley from the "full" sysout

    -l | --lisp                : start Medley from the "lisp" sysout

    -a | --apps                : start Medley  from the "apps" sysout

    -e | --interlisp           : (for apps.sysout only) Start in the Interlisp exec

    -n | --noscroll            : do not use scroll bars in Medley window

    -g WxH | --geometry WxH    : set the window geometry to Width x Height.

    -s WxH | --screensize WxH  : set the Medley screen size to be Width x Height

    -t STRING | --title STRING : use STRING as title of window

    -d :N | --display :N       : use X display :N

    -v | --vnc                 : (WSL only) Use a VNC window instead of an X window

    -i STRING | --id STRING    : use STRING as the id for this run of Medley (default: default)

    -i - | --id -              : use the basename of the current directory as the id

    -m N | --mem N             : set Medley memory size to N

    -p FILE | --vmem FILE      : use FILE as the Medley virtual memory store

    -r FILE | --greet FILE     : use FILE as the Medley greetfile

    -r - | --greet -           : do not use a greetfile


sysout:
    The name of the file to use as a sysout for Medley to start from.  If sysout is not
    provided and none of the flags [-a, -f & -l] is used, then Medley will start from
    the saved virtual memory file for the id for this run.

pass_args:
    All arguments after the "--" flag, are passed unaltered to lde via run-medley.

EOF

exit 1

}

check_for_dash() {
  if [ "${2:0:1}" = "-" ];
  then
     echo "Error: either the value for argument \"${1}\" is missing OR"
     echo "the value begins with a \"-\", which is not allowed."
     echo
     usage
  fi
}

