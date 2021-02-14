#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi

./run-medley -greet $MEDLEYDIR/sources/LOADUP-FULL.LCOM $MEDLEYDIR/loadups/lisp.sysout


