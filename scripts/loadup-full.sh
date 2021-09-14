#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi

# Keep (GREET) from finding an init file
mkdir -p $MEDLEYDIR/tmp/logindir
export HOME=$MEDLEYDIR/tmp/logindir
export LOGINDIR=$MEDLEYDIR/tmp/logindir

scr="-sc 1024x768 -g 1042x790"

touch tmp/loadup.timestamp

./run-medley $scr -loadup "$MEDLEYDIR/sources/LOADUP-FULL.CM" "$MEDLEYDIR/loadups/lisp.sysout"

if [ tmp/full.sysout -nt tmp/loadup.timestamp ]; then
    
    echo ---- made ----
    ls -l tmp/full.*
    echo --------------

else
    echo XXXXX FAILURE XXXXX
    ls -l tmp/full.*
    exit 1
fi
