#!/bin/sh

if [ ! -x run-medley ] ; then
    echo must run from MEDLEYDIR ;
    exit 1 ;
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
"

(PROGN
  (IL:LOAD (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV (QUOTE LOADUP_SOURCEDIR))(QUOTE /LOADUP-FULL.LCOM)))
  (IL:LOADUP-FULL (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV(QUOTE LOADUP_WORKDIR))(IL:L-CASE (QUOTE /full.dribble))))
  (IL:HARDRESET)
)
SHH
(PROGN
  (IL:ENDLOADUP)
  (IL:MAKESYS (IL:CONCAT (QUOTE {DSK})(IL:UNIX-GETENV(QUOTE LOADUP_WORKDIR))(IL:L-CASE (QUOTE /full.sysout))) :FULL))
  (IL:LOGOUT T)
)

"
EOF

./run-medley ${scr} -loadup "${cmfile}" "${LOADUP_WORKDIR}/lisp.sysout"

loadup_finish "full.sysout" "full.*"

