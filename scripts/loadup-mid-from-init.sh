#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

mkdir -p "$MEDLEYDIR/tmp"
scr="-sc 1024x768 -gr 1042x790"

cp sources/XREM.CM ~/rem.cm

./run-medley -prog ldeinit $scr -vmem tmp/init-mid.sysout loadups/init.dlinit

echo ---- made ----
ls -l tmp/
echo --------------
