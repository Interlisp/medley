#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

echo ">>>>> START ${script_name}"

./scripts/cpv "${LOADUP_WORKDIR}"/fuller.database loadups
./scripts/cpv "${LOADUP_WORKDIR}"/fuller.dribble loadups

echo "<<<<< END ${script_name}"
echo ""
exit 0
