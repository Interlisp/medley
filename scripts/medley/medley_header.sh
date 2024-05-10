#!only-to-be-sourced
# shellcheck shell=sh
###############################################################################
#
#    medley.sh - script for running Medley Interlisp on
#                Linux/WSL/Cygwin/MacOS. On all platforms it just sets
#                up directories and environment variables and then calls
#                maiko with the right arguments.  On WSL, there is an option to
#                run without or around X Windows by using the XVnc and a VNC viewer
#                on the Windows side.  This script will start this VNC viewer
#                on the Windows side.
#
#   NOTE:  This script is "compiled" using compile.sh (and inline.sh) from the
#          component scripts (medley_*.sh).  The top-level component is
#          medley_main.sh.  The other components are sourced (directly or
#          indirectly) from medley_main.sh.
#
#          Do not edit this script directly.  Edit the component scripts and
#          then recompile to get this "combined" script.  You can also run
#          the scripts by exec-ing the medley_main.sh script.  This will allow
#          testing of component modifications without having to compile.
#
#   2023-01-12 Frank Halasz
#   2024-04-29 Frank Halasz: Major overhaul
#
#   Copyright 2023-2024 Interlisp.org
#
###############################################################################
