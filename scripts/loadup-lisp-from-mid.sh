#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

scr="-sc 1024x768 -g 1042x790"

echo '"' > ~/rem.cm
echo '(PROGN(LOAD(QUOTE {DSK}'$MEDLEYDIR'/sources/LOADUP.LISP))(HARDRESET))' >> ~/rem.cm
echo 'SHH(PROGN (IL:ENDLOADUP) (IL:SPECVARS . T) (IL:MAKESYS (QUOTE {DSK}'$MEDLEYDIR'/loadups/lisp.sysout)))' >> ~/rem.cm
echo '(IL:LOGOUT T)' >> ~/rem.cm
echo '"' >> ~/rem.cm

echo -----rem.cm -----
cat ~/rem.cm
echo ----------------

./run-medley $scr -greet $MEDLEYDIR/sources/LOADUP-GREET tmp/init-mid.sysout

rm ~/rem.cm

echo ----- created: -------
ls -l loadups/lisp.sysout
echo ----------------------

