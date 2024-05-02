#!/bin/sh

if [ ! -h ./medley ] || [ ! -d ./lispusers ]
then
    echo "*** ERROR ***"
    echo "You must run $(basename $0) while the cwd is a Medley top-level directory."
    echo "The cwd ($(pwd)) is not a Medley top-level directory."
    echo "Exiting."
    exit 1
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


