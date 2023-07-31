#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

echo '" (IL:MEDLEY-INIT-VARS)(IL:LOAD(QUOTE MEDLEY-UTILS))(IL:MAKE-EXPORTS-ALL)(IL:MAKE-WHEREIS-HASH)(IL:LOGOUT T)"' > ${LOADUP_WORKDIR}/loadup-aux.cm

./run-medley $scr -loadup "${LOADUP_WORKDIR}/loadup-aux.cm ${LOADUP_WORKDIR}/full.sysout

loadup_finish "loadup-aux" "whereis.hash" "whereis.hash" "exports.all"
