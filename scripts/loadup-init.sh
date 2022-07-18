#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

scr="-sc 1024x768 -g 1042x790"

mkdir -p tmp
touch tmp/loadup.timestamp

./run-medley $scr -loadup "$MEDLEYDIR"/sources/LOADUP-INIT.LISP loadups/starter.sysout

if [ tmp/init.dlinit -nt tmp/loadup.timestamp ]; then
    
    echo ---- made ----
    ls -l tmp/init.* tmp/RDSYS* tmp/I-NEW*
    echo --------------

else
    echo XXXXX FAILURE XXXXX
    exit 1
fi
