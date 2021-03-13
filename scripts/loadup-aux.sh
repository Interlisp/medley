#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

scr="-sc 1024x768 -g 1042x790"

echo '" (IL:MEDLEY-INIT-VARS)(IL:LOAD(QUOTE MEDLEY-UTILS))(IL:MAKE-EXPORTS-ALL)(IL:MAKE-WHEREIS-HASH)(IL:LOGOUT T)"' > tmp/loadup-aux.cm
./run-medley $scr -greet "$MEDLEYDIR"/tmp/loadup-aux.cm tmp/full.sysout

echo ---- made ----
ls -l tmp/exports.all tmp/whereis.hash
echo --------------
