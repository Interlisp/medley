#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi

export LOADUPDIR=$MEDLEYDIR

./run-medley -greet $MEDLEYDIR/makesysout/MAKEFULLSYSOUT.LCOM $MEDLEYDIR/loadups/xlisp.sysout


