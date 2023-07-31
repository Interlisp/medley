#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

DBCM="${LOADUP_WORKDIR}"/db.cm

echo '" (IL:MEDLEY-INIT-VARS)(IL:FILESLOAD MEDLEY-UTILS)(IL:MAKE-FULLER-DB)(IL:LOGOUT T)"' > ${DBCM}

./run-medley $scr -loadup "${DBCM}" -full

loadup_finish "loadup-db" "fuller.database" "fuller*"

