#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

./scripts/cpv ${LOADUP_WORKDIR}/fuller.database loadups
./scripts/cpv ${LOADUP_WORKDIR}/fuller.dribble loadups

