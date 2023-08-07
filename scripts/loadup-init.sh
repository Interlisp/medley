#!/bin/sh

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
(* "make init files; this file is loaded as a 'greet' file by scripts/loadup-init.sh")

(SETQ MEDLEYDIR NIL)
(LOAD (CONCAT (UNIX-GETENV "MEDLEYDIR") "/sources/MEDLEYDIR.LCOM"))
(MEDLEY-INIT-VARS)
(CNDIR (UNIX-GETENV "LOADUP_WORKDIR"))
(DRIBBLE "init.dribble")

(UNADVISE)
(ADVISE 'PAGEFULLFN '(RETURN))
(ADVISE '(ERROR IN \DO-DEFINE-FILE-INFO) '(RETURN))
(MOVD? 'NILL 'SETTEMPLATE)
(DEFINEQ (RRE (LAMBDA (X Y) Y)))
(MOVD? 'RRE 'READ-READER-ENVIRONMENT)

(LOAD (CONCAT "{DSK}" (UNIX-GETENV "LOADUP_SOURCEDIR") "/" "MAKEINIT.LCOM"))
(PROG
  ((WORKDIR (CONCAT "{DSK}" (UNIX-GETENV "LOADUP_WORKDIR") "/"))
   (LOADUP-SOURCE-DIR (CONCAT "{DSK}" (UNIX-GETENV "LOADUP_SOURCEDIR") "/"))
  )
  (SETQ DIRECTORIES (CONS LOADUP-SOURCE-DIR DIRECTORIES))
  (RESETLST (RESETSAVE OK.TO.MODIFY.FNS T)
    (MAKEINITGREET (CONCAT WORKDIR "init.sysout") (CONCAT WORKDIR "init.dlinit"))
  )
)
(DRIBBLE)
(LOGOUT T)
STOP
EOF

./run-medley $scr -loadup "${cmfile}" "${LOADUP_SOURCEDIR}"/starter.sysout

loadup_finish "init.dlinit" "init.*" "RDSYS*" "I-NEW*"
