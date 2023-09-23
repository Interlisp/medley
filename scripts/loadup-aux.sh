#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

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

./run-medley ${scr} -loadup "${cmfile}" "${LOADUP_WORKDIR}"/full.sysout

loadup_finish "whereis.hash" "whereis.hash" "exports.all"
