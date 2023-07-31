#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

./run-medley $scr -loadup "$MEDLEYDIR/sources/LOADUP-LISP.CM" ${LOADUP_WORKDIR}/init-mid.sysout

loadup_finish "loadup-lisp-from-mid" "lisp.sysout" "lisp.*"
