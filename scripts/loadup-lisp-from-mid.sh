#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

touch tmp/loadup.timestamp

scr="-sc 1024x768 -g 1042x790"


./run-medley $scr -greet $MEDLEYDIR/sources/LOADUP-LISP.CM tmp/init-mid.sysout

if [ tmp/lisp.sysout -nt tmp/loadup.timestamp ]; then
    
    echo ---- made ----
    ls -l tmp/lisp.*
    echo --------------
else
    echo XXXXX FAILURE XXXXX
    exit 1
fi
