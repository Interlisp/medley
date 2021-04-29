#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

# set timestamp
mkdir -p ./tmp
touch ./tmp/loadup-timestamp

./scripts/loadup-init.sh && \
    ./scripts/loadup-mid-from-init.sh && \
    ./scripts/loadup-lisp-from-mid.sh && \
    ./scripts/loadup-full.sh && \
    ./scripts/loadup-aux.sh && \
    echo "**** DONE ****"



