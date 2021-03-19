#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

cp -p tmp/full.sysout tmp/lisp.sysout tmp/*.dribble tmp/whereis.hash loadups/
cp -p tmp/exports.all tmp/RDSYS tmp/RDSYS.LCOM library/

