#!/bin/sh

if [ ! -h ./medley ] || [ ! -d ./lispusers ]
then
    echo "*** ERROR ***"
    echo "You must run $(basename $0) while the cwd is a Medley top-level directory."
    echo "The cwd ($(pwd)) is not a Medley top-level directory."
    echo "Exiting."
    exit 1
fi

. scripts/loadup-setup.sh

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

if [ $? -eq 0 ];
then
  echo "+++++ loadup-all.sh: SUCCESS +++++"
else
  echo "----- loadup-all.sh: FAILURE -----"
fi





