#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
"

(PROGN
  (LOAD (CONCAT (QUOTE {DSK}) (UNIX-GETENV (QUOTE MEDLEYDIR)) (QUOTE /sources/MEDLEYDIR.LCOM)))
  (MEDLEY-INIT-VARS)
  (LOAD (CONCAT (QUOTE {DSK}) (UNIX-GETENV (QUOTE LOADUP_SOURCEDIR)) (QUOTE /LOADUP-LISP.LCOM)))
  (LOADUP-LISP (CONCAT (QUOTE {DSK}) (UNIX-GETENV (QUOTE LOADUP_WORKDIR)) (QUOTE /lisp.dribble)))
  (HARDRESET)
)
SHH
(PROGN
  (IL:ENDLOADUP)
  (IL:MAKESYS (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV(QUOTE LOADUP_WORKDIR)) (IL:L-CASE (QUOTE /lisp.sysout))) :LISP)
  (IL:LOGOUT T)
)

"
EOF

./run-medley ${scr} -loadup "${cmfile}" "${LOADUP_WORKDIR}/init-mid.sysout"

loadup_finish "lisp.sysout" "lisp.*"
