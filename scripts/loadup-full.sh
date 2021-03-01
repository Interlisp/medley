#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi
scr="-sc 1024x768 -g 1042x790"

rm -f ~/rem.cm

./run-medley $scr -greet $MEDLEYDIR/sources/LOADUP-FULL.LCOM $MEDLEYDIR/loadups/lisp.sysout


echo ----- made ----
ls -l loadups/full.sysout
echo ---------------
