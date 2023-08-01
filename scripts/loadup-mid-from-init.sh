#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start "loadup-mid-from-init"

./run-medley -prog "ldeinit" -NF -loadup $MEDLEYDIR/sources/XREM.CM $scr -vmem ${LOADUP_WORKDIR}/init-mid.sysout ${LOADUP_WORKDIR}/init.dlinit

loadup_finish "loadup-mid-from-init" "init-mid.sysout" "init-mid.sysout"
