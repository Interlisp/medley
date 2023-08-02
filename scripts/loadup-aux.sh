#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
"
  (IL:MEDLEY-INIT-VARS)
  (IL:LOAD(QUOTE MEDLEY-UTILS))
  (IL:MAKE-EXPORTS-ALL)
  (IL:MAKE-WHEREIS-HASH (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV(QUOTE LOADUP_WORKDIR))(IL:L-CASE (QUOTE /whereis.dribble))))
  (IL:LOGOUT T)
"
EOF

./run-medley ${scr} -loadup "${cmfile}" "${LOADUP_WORKDIR}"/full.sysout

loadup_finish "whereis.hash" "whereis.hash" "exports.all"
