#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

./run-medley $scr -loadup "${MEDLEYDIR}"/sources/LOADUP-INIT.LISP loadups/starter.sysout

loadup_finish "loadup-init" "init.dlinit" "init.*" "RDSYS*" "I-NEW*"
