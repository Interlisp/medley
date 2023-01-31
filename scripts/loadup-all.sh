#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

if [ "$1" = "-apps" ]; then
    apps="./scripts/loadup-apps-from-full.sh"
else
    apps="true"
fi

./scripts/loadup-init.sh && \
    ./scripts/loadup-mid-from-init.sh && \
    ./scripts/loadup-lisp-from-mid.sh && \
    ./scripts/loadup-full-from-lisp.sh && \
    ${apps} && \
    ./scripts/loadup-aux.sh && \
    ./scripts/copy-all.sh $1

echo "**** DONE ****"




