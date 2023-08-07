#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
"

(PROG
  ((WORKDIR (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV (QUOTE LOADUP_WORKDIR)) (QUOTE /)))
   (LOADUP-SOURCE-DIR (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV (QUOTE LOADUP_SOURCEDIR)) (QUOTE /)))
  )
  (IL:MEDLEY-INIT-VARS)
  (IL:FILESLOAD MEDLEY-UTILS)
  (SETQ IL:DIRECTORIES (CONS LOADUP-SOURCE-DIR IL:DIRECTORIES))
  (IL:MAKE-FULLER-DB
    (IL:CONCAT WORKDIR (IL:L-CASE (QUOTE fuller.dribble)))
    (IL:CONCAT WORKDIR (IL:L-CASE (QUOTE fuller.database)))
    (IL:CONCAT WORKDIR (IL:L-CASE (QUOTE fuller.sysout)))
  )
  (IL:LOGOUT T)
)

"
EOF

./run-medley ${scr} -loadup "${cmfile}" -full

loadup_finish "fuller.database" "fuller*"

#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

./scripts/loadup-db-from-full.sh && ./scripts/copy-db.sh

if [ $? -eq 0 ];
then
  echo "+++++ loadup-db.sh: SUCCESS +++++"
else
  echo "----- loadup-db.sh: FAILURE -----"
fi





