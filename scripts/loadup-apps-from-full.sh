#!/bin/sh

if [ ! -x run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi

. scripts/loadup-setup.sh

export ROOMSDIR=${MEDLEYDIR}/rooms
export CLOSDIR=${MEDLEYDIR}/clos

export NOTECARDSDIR=${MEDLEYDIR}/notecards
if [ ! -e ${NOTECARDSDIR} ]; then
    NOTECARDSDIR=$(cd ${MEDLEYDIR}/../ && pwd)/notecards
    if [ ! -e ${NOTECARDSDIR} ]; then
        NOTECARDSDIR=$(cd ${MEDLEYDIR}/../../ && pwd)/notecards
        if [ ! -e ${NOTECARDSDIR} ]; then
            NOTECARDSDIR=""
        fi
    fi
fi

./run-medley $scr -loadup "${MEDLEYDIR}/sources/LOADUP-APPS.CM" "${LOADUP_TMP}/full.sysout"

loadup_finish "loadup-apps-from-full" "apps.sysout" "apps.*"


