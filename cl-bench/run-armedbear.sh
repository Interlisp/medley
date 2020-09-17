#!/bin/bash

ABLISP=${ABLISP:-ablisp}
HERE=`pwd`

make clean optimize-files
$ABLISP <<EOF
:cd $HERE
(load "sysdep/setup-ablisp.lisp")
(load "do-compilation-script.lisp")
:exit
EOF
$ABLISP <<EOF
:cd $HERE
(load "sysdep/setup-ablisp.lisp")
(load "do-execute-script")
:exit
EOF
