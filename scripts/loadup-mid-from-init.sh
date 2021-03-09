#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

mkdir -p "$MEDLEYDIR/tmp"
scr="-sc 1024x768 -g 1042x790"

./run-medley -prog ldeinit -greet $MEDLEYDIR/sources/XREM.CM $scr -vmem tmp/init-mid.sysout tmp/init.dlinit

echo ---- made ----
ls -l tmp/
echo --------------
