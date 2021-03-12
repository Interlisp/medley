#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

./scripts/loadup-init.sh && \
    ./scripts/loadup-mid-from-init.sh && \
    ./scripts/loadup-lisp-from-mid.sh && \
    ./scripts/loadup-full.sh && \
    ./scripts/loadup-aux.sh

echo tada!
