#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

mkdir -p "$MEDLEYDIR/tmp"

rm -f ~/rem.cm ~/lisp.virtualmem ./tmp/* loadups/init*~

cp sources/XREM.CM ~/rem.cm

prog=../maiko/linux.x86_64/ldeinit
if [ ! -x $prog ] ; then
    prog=../maiko/darwin.aarch64/ldeinit
fi
if [ ! -x $prog ] ; then
    prog=../maiko/linux.armv7l/ldeinit
fi


$prog -sc 1000x900 -g 1000x900 loadups/init.dlinit

echo -
echo --- init run --
ls -l ~


cp ~/lisp.virtualmem tmp/init-mid.sysout

