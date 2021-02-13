#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

export LOADUPDIR="$MEDLEYDIR"
mkdir -p "$MEDLEYDIR/tmp"

./run-medley -greet "$MEDLEYDIR"/sources/LOADUP-INIT.LISP -full

ls -l tmp loadups/init*

