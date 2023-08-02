#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
(* "make init files; this file is loaded as a 'greet' file by scripts/loadup-init.sh")

(LOAD (CONCAT (UNIX-GETENV "MEDLEYDIR") "/sources/MEDLEYDIR.LCOM"))
(CNDIR (UNIX-GETENV "LOADUP_WORKDIR"))
(DRIBBLE "init.dribble")

(UNADVISE)
(ADVISE 'PAGEFULLFN '(RETURN))
(ADVISE '(ERROR IN \DO-DEFINE-FILE-INFO) '(RETURN))
(MOVD? 'NILL 'SETTEMPLATE)
(DEFINEQ (RRE (LAMBDA (X Y) Y)))
(MOVD? 'RRE 'READ-READER-ENVIRONMENT)

(LOAD (MEDLEYDIR "sources" "MAKEINIT.LCOM"))
(MAKEINITGREET)
(DRIBBLE)
(LOGOUT T)
STOP
EOF

./run-medley $scr -loadup "${cmfile}" loadups/starter.sysout

loadup_finish "init.dlinit" "init.*" "RDSYS*" "I-NEW*"
