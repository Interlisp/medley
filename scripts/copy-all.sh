#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

# was
# cp -p tmp/full.sysout tmp/lisp.sysout tmp/*.dribble tmp/whereis.hash loadups/
# cp -p tmp/exports.all tmp/RDSYS tmp/RDSYS.LCOM library/
# just copy the files that are released

./scripts/cpv tmp/full.sysout loadups
./scripts/cpv cpv tmp/lisp.sysout loadups
./scripts/cpv tmp/whereis.hash loadups
./scripts/cpv tmp/exports.all library

