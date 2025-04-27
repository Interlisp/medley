#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

./scripts/loadup-all.sh  &&  \
./scripts/copy-all.sh &&     \
./scripts/release-medley.sh

