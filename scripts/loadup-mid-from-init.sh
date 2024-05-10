#!/bin/sh

if [ ! -h ./medley ] || [ ! -d ./lispusers ]
then
    echo "*** ERROR ***"
    echo "You must run $(basename "$0") while the cwd is a Medley top-level directory."
    echo "The cwd ($(pwd)) is not a Medley top-level directory."
    echo "Exiting."
    exit 1
fi

# shellcheck source=./loadup-setup.sh
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

run_medley "${LOADUP_WORKDIR}/init.dlinit" -NF -prog ldeinit --vmem "${LOADUP_WORKDIR}/init-mid.sysout"

echo " "

loadup_finish "init-mid.sysout" "init-mid.sysout"
