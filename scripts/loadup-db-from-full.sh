#!/bin/sh

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

. scripts/loadup-setup.sh

loadup_start

cat >"${cmfile}" <<"EOF"
"

(IL:MEDLEY-INIT-VARS)
(IL:FILESLOAD MEDLEY-UTILS)
(IL:MAKE-FULLER-DB)
(IL:LOGOUT T)

"
EOF

./run-medley ${scr} -loadup "${cmfile}" -full

loadup_finish "fuller.database" "fuller*"

