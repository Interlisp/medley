#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

export LOADUPDIR=$MEDLEYDIR

./run-medley -greet $MEDLEYDIR/makesysout/SYNCLISPFILES.LCOM $MEDLEYDIR/loadups/lisp.venuesysout
