#!/bin/sh

if [ ! -x run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi

. ./scripts/loadup-setup.sh

./scripts/loadup-init.sh && \
./scripts/loadup-mid-from-init.sh && \
./scripts/loadup-lisp-from-mid.sh && \
./scripts/loadup-full-from-lisp.sh && \
./scripts/copy-full.sh

if [ $? -eq 0 ];
then
  echo "+++++ loadup-full.sh: SUCCESS +++++"
else
  echo "----- loadup-full.sh: FAILURE -----"
fi


