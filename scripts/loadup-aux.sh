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
(PROG
  ((WORKDIR (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV (QUOTE LOADUP_WORKDIR)) (QUOTE /))))
  (IL:MEDLEY-INIT-VARS)
  (IL:LOAD(QUOTE MEDLEY-UTILS))
  (IL:MAKE-EXPORTS-ALL (IL:CONCAT WORKDIR (IL:L-CASE (QUOTE exports.all))))
  (IL:MAKE-WHEREIS-HASH
    (IL:CONCAT WORKDIR (IL:L-CASE (QUOTE whereis.dribble)))
    (IL:CONCAT WORKDIR (IL:L-CASE (QUOTE whereis.hash-tmp)))
    (IL:CONCAT WORKDIR (IL:L-CASE (QUOTE whereis.hash)))
  )
  (IL:LOGOUT T)
)
"
EOF

run_medley "${LOADUP_WORKDIR}/full.sysout"

loadup_finish "whereis.hash" "whereis.hash" "exports.all"
