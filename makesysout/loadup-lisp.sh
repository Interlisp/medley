/bin/sh

export MEDLEYDIR=`pwd`

if [! -e run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

export LOADUPDIR=$MEDLEYDIR

$ ./run-medley -greet $MEDLEYDIR/makesysout/synclispfiles.lcom $MEDLEYDIR/loadups/lisp.venuesysout
