#!/bin/bash

SBCL=${SBCL:-sbcl}
SBCL_OPT="--disable-debugger --userinit /dev/null"

make clean optimize-files
$SBCL ${SBCL_OPT} --load sysdep/setup-sbcl.lisp --load do-compilation-script.lisp --eval '(quit)'
$SBCL ${SBCL_OPT} --load sysdep/setup-sbcl.lisp --load do-execute-script.lisp --eval '(quit)'
