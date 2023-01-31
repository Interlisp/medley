#!/bin/bash

#set -x

# function to discover what directory this script is being executed from
where_am_i() {

    # call this with ${BASH_SOURCE[0]:-$0} as its (only) parameter

    local SCRIPT_PATH="$1";

    pushd . > '/dev/null';

    while [ -h "$SCRIPT_PATH" ];
    do
        cd "$( dirname -- "$SCRIPT_PATH"; )";
        SCRIPT_PATH="$( readlink -f -- "$SCRIPT_PATH"; )";
    done

    cd "$( dirname -- "$SCRIPT_PATH"; )" > '/dev/null';
    SCRIPT_PATH="$( pwd; )";

    popd  > '/dev/null';

    echo "${SCRIPT_PATH}"
}

SCRIPTDIR=$(where_am_i "${BASH_SOURCE[0]:-$0}")
export MEDLEYDIR=$(cd ${SCRIPTDIR} && cd .. && pwd)
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

if [ -z "${SYSOUTDIR}" ]; then
    export SYSOUTDIR=${MEDLEYDIR}/tmp
fi

if [ -z "${FULLSYSOUTPATH}" ]; then
    FULLSYSOUTPATH=${SYSOUTDIR}/full.sysout
    if [ ! -e ${FULLSYSOUTPATH} ]; then
       FULLSYSOUTPATH=${MEDLEYDIR}/loadups/full.sysout
    fi
fi

cd ${MEDLEYDIR}

scr="-sc 1024x768 -g 1042x790"

mkdir -p ${SYSOUTDIR}
touch ${SYSOUTDIR}/loadup.timestamp

./run-medley $scr -loadup "${MEDLEYDIR}/sources/LOADUP-APPS.CM" "${FULLSYSOUTPATH}"

if [ ${SYSOUTDIR}/apps.sysout -nt ${SYSOUTDIR}/loadup.timestamp ]; then
    echo ---- made ----
    ls -l ${SYSOUTDIR}/apps.*
    echo --------------
else
    echo XXXXX FAILURE XXXXX
    ls -l ${SYSOUTDIR}/apps.*
    exit 1
fi

