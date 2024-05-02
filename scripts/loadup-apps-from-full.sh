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

export ROOMSDIR="${MEDLEYDIR}/rooms"
export CLOSDIR="${MEDLEYDIR}/clos"

export NOTECARDSDIR="${MEDLEYDIR}/notecards"
if [ ! -e "${NOTECARDSDIR}" ]
then
    NOTECARDSDIR=$(cd "${MEDLEYDIR}/../" && pwd)/notecards
    if [ ! -e "${NOTECARDSDIR}" ]
    then
        NOTECARDSDIR=$(cd "${MEDLEYDIR}/../../" && pwd)/notecards
        if [ ! -e "${NOTECARDSDIR}" ]
        then
            NOTECARDSDIR=""
        fi
    fi
fi

if [ -z "${NOTECARDSDIR}" ]
then
    echo "Error: Cannot find the Notecards directory"
    echo "It should be located at ${MEDLEYDIR}/../notecards or"
    echo "${MEDLEYDIR}/../../notecards.  But its not."
    echo "Exiting"
    exit 1
fi

cat >"${cmfile}" <<"EOF"
"

(PROGN
   (IL:MEDLEY-INIT-VARS 'IL:GREET)
   (IL:DRIBBLE (IL:CONCAT (QUOTE {DSK})(IL:UNIX-GETENV(QUOTE LOADUP_WORKDIR))(IL:L-CASE (QUOTE /apps.dribble))))
   (IL:LOAD (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV(QUOTE ROOMSDIR))(QUOTE /ROOMS)) 'IL:SYSLOAD)
   (IL:LOAD (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV(QUOTE NOTECARDSDIR))(QUOTE |/system/NOTECARDS.LCOM|)) 'IL:SYSLOAD)
   (IL:LOAD (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV(QUOTE CLOSDIR))(QUOTE /DEFSYS.DFASL)) 'IL:SYSLOAD)
   (IL:LOAD (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV(QUOTE MEDLEYDIR))(QUOTE |lispusers/BUTTONS.LCOM|)) 'IL:SYSLOAD)
   (IL:LOAD
       (IL:CONCAT (QUOTE {DSK}) (IL:UNIX-GETENV (QUOTE LOADUP_SOURCEDIR)) (QUOTE /LOADUP-APPS.LCOM))
       'IL:SYSLOAD
   )
   (IL:HARDRESET)
)
SHH
(PROGN
   (IL:ENDLOADUP)
   (CLOS::LOAD-CLOS)
   (IL:|Apps.LOADUP|)
   (IL:DRIBBLE)
   (IL:MAKESYS
       (IL:CONCAT (QUOTE {DSK})(IL:UNIX-GETENV(QUOTE LOADUP_WORKDIR))(IL:L-CASE (QUOTE /apps.sysout)))
       :APPS)
)
(IL:LOGOUT T)

"
EOF

run_medley "${LOADUP_WORKDIR}/full.sysout"

loadup_finish "apps.sysout" "apps.*"
