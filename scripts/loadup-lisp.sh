#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

export LOADUPDIR=$MEDLEYDIR

./run-medley -greet $MEDLEYDIR/sources/LOADUP-LISP.LCOM $MEDLEYDIR/loadups/lisp.venuesysout
