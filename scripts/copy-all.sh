#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

echo ">>>>> START ${script_name}"

# was
# cp -p tmp/full.sysout tmp/lisp.sysout tmp/*.dribble tmp/whereis.hash loadups/
# cp -p tmp/exports.all tmp/RDSYS tmp/RDSYS.LCOM library/
# just copy the files that are released

./scripts/cpv "${LOADUP_WORKDIR}"/full.sysout loadups
./scripts/cpv "${LOADUP_WORKDIR}"/lisp.sysout loadups
if [ "${1}" = "-apps" ]; then
    ./scripts/cpv "${LOADUP_WORKDIR}"/apps.sysout loadups
fi

./scripts/cpv "${LOADUP_WORKDIR}"/whereis.hash loadups
./scripts/cpv "${LOADUP_WORKDIR}"/exports.all loadups

./scripts/cpv "${LOADUP_WORKDIR}"/init.dribble loadups
./scripts/cpv "${LOADUP_WORKDIR}"/lisp.dribble loadups
./scripts/cpv "${LOADUP_WORKDIR}"/full.dribble loadups
./scripts/cpv "${LOADUP_WORKDIR}"/whereis.dribble loadups

./scripts/cpv "${LOADUP_WORKDIR}"/RDSYS library
./scripts/cpv "${LOADUP_WORKDIR}"/RDSYS.LCOM library

echo "<<<<< END ${script_name}"
echo ""
exit 0
