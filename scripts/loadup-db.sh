#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

./scripts/loadup-db-from-full.sh && ./scripts/copy-db.sh

if [ $? -eq 0 ];
then
  echo "+++++ loadup-db.sh: SUCCESS +++++"
else
  echo "----- loadup-db.sh: FAILURE -----"
fi





