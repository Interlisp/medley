#!/bin/sh

if [ ! -x run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi

. scripts/loadup-setup.sh

./run-medley $scr -loadup "$MEDLEYDIR/sources/LOADUP-FULL.CM" "${LOADUP_WORKDIR}/lisp.sysout"

loadup_finish "loadup-full-from-lisp" "full.sysout" "full.*"

