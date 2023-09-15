#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

echo ">>>>> START ${script_name}"

./scripts/cpv "${LOADUP_WORKDIR}"/fuller.database "${LOADUP_OUTDIR}"
./scripts/cpv "${LOADUP_WORKDIR}"/fuller.dribble "${LOADUP_OUTDIR}"

echo "<<<<< END ${script_name}"
echo ""
exit 0
