#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

scr="-sc 1024x768 -g 1042x790"


./run-medley $scr -greet $MEDLEYDIR/sources/YREM.CM tmp/init-mid.sysout

echo ----- created: -------
ls -l loadups/lisp.sysout
echo ----------------------

