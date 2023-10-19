#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

echo ">>>>> START ${script_name}"

./scripts/cpv "${LOADUP_WORKDIR}"/full.sysout "${LOADUP_OUTDIR}"  | sed -e "s#${MEDLEYDIR}/##g"
./scripts/cpv "${LOADUP_WORKDIR}"/lisp.sysout "${LOADUP_OUTDIR}"  | sed -e "s#${MEDLEYDIR}/##g"

./scripts/cpv "${LOADUP_WORKDIR}"/init.dribble "${LOADUP_OUTDIR}" | sed -e "s#${MEDLEYDIR}/##g"
./scripts/cpv "${LOADUP_WORKDIR}"/lisp.dribble "${LOADUP_OUTDIR}" | sed -e "s#${MEDLEYDIR}/##g"
./scripts/cpv "${LOADUP_WORKDIR}"/full.dribble "${LOADUP_OUTDIR}" | sed -e "s#${MEDLEYDIR}/##g"

./scripts/cpv "${LOADUP_WORKDIR}"/RDSYS library | sed -e "s#${MEDLEYDIR}/##g"
./scripts/cpv "${LOADUP_WORKDIR}"/RDSYS.LCOM library | sed -e "s#${MEDLEYDIR}/##g"

echo "<<<<< END ${script_name}"
echo ""
exit 0
