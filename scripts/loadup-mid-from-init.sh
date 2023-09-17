#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
"
(MOVD? (QUOTE NILL) (QUOTE PROMPTPRINT))
(MOVD? (QUOTE NILL) (QUOTE CURSORP))
(MOVD? (QUOTE NILL) (QUOTE CHANGEBACKGROUNDBORDER))
(LOGOUT)
"
EOF

./run-medley -prog "ldeinit" \
             -NF \
             -loadup "${cmfile}" ${scr} -vmem "${LOADUP_WORKDIR}/init-mid.sysout" \
            "${LOADUP_WORKDIR}/init.dlinit"

loadup_finish "init-mid.sysout" "init-mid.sysout"
