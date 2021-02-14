#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

export LOADUPDIR="$MEDLEYDIR"
mkdir -p "$MEDLEYDIR/tmp"

rm -f ~/rem.cm ~/lisp.virtualmem ./tmp/* loadups/init*~

cp sources/XREM.CM ~/rem.cm

prog=../maiko/linux.x86_64/ldeinit
if [ ! -x $prog ] ; then
    echo $prog not found
    prog=../maiko/darwin.aarch64/ldeinit
fi

$prog -sc 1000x900 -g 1000x900 loadups/init.dlinit
echo init run

cp ~/lisp.virtualmem tmp/init-mid.sysout
echo '"' > ~/rem.cm

echo '(PROGN(LOAD(QUOTE {DSK}'$MEDLEYDIR'/sources/LOADUP.LISP))(HARDRESET))' >> ~/rem.cm
echo 'SHH(PROGN (IL:ENDLOADUP) (IL:SPECVARS . T) (IL:MAKESYS (QUOTE {DSK}'$MEDLEYDIR'/loadups/lisp.sysout)))' >> ~/rem.cm
echo '(IL:LOGOUT)' >> ~/rem.cm

echo '"' >> ~/rem.cm

echo -----rem.cm
cat ~/rem.cm
echo -----
./run-medley -greet $MEDLEYDIR/sources/LOADUP-GREET tmp/init-mid.sysout
rm ~/rem.cm

echo ----- created: -------
ls -l loadups/lisp.sysout
echo ----------------------

