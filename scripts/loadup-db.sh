#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

touch tmp/loadup.timestamp

scr="-sc 1024x768 -g 1042x790"

echo '" (IL:MEDLEY-INIT-VARS)(IL:FILESLOAD MEDLEY-UTILS)(IL:MAKE-FULLER-DB)(IL:LOGOUT T)"' > tmp/loadup-db.cm
./run-medley $scr -loadup "$MEDLEYDIR"/tmp/loadup-db.cm tmp/full.sysout

if [ tmp/fuller.database -nt tmp/loadup.timestamp ]; then
    
    echo ---- made ----
    ls -l tmp/fuller*
    echo --------------

else
    echo XXXXX FAILURE XXXXX
    ls -l tmp/fuller*
    exit 1
fi
