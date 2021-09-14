#!/bin/sh

export MEDLEYDIR=`pwd`

if [ ! -f run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

touch tmp/loadup.timestamp

# Keep (GREET) from finding an init file
mkdir -p $MEDLEYDIR/tmp/logindir
export HOME=$MEDLEYDIR/tmp/logindir
export LOGINDIR=$MEDLEYDIR/tmp/logindir

scr="-sc 1024x768 -g 1042x790"

echo '" (IL:MEDLEY-INIT-VARS)(IL:LOAD(QUOTE MEDLEY-UTILS))(IL:MAKE-EXPORTS-ALL)(IL:MAKE-WHEREIS-HASH)(IL:LOGOUT T)"' > tmp/loadup-aux.cm
./run-medley $scr -loadup "$MEDLEYDIR"/tmp/loadup-aux.cm tmp/full.sysout

if [ tmp/whereis.hash -nt tmp/loadup.timestamp ]; then
    
    echo ---- made ----
    ls -l tmp/whereis.hash tmp/exports.all
    echo --------------

else
    echo XXXXX FAILURE XXXXX
    ls -l tmp/whereis.hash tmp/exports.all
    exit 1
fi
