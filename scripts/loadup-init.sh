#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

scr="-sc 1024x768 -g 1042x790"

mkdir -p "$MEDLEYDIR/tmp"
rm -f ~/rem.cm

./run-medley $scr -greet "$MEDLEYDIR"/sources/LOADUP-INIT.LISP -full

echo ---- made ----
ls -l tmp loadups/init*
echo --------------
