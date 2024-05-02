#!/bin/sh

if [ ! -h ./medley ] || [ ! -d ./lispusers ]
then
    echo "*** ERROR ***"
    echo "You must run $(basename $0) while the cwd is a Medley top-level directory."
    echo "The cwd ($(pwd)) is not a Medley top-level directory."
    echo "Exiting."
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

run_medley "${LOADUP_WORKDIR}/init-mid.sysout"

loadup_finish "lisp.sysout" "lisp.*"
