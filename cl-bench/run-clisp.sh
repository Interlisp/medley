#!/bin/bash

CLISP_OPT="-q -norc -ansi -m 200MB -E iso-8859-1"
CLISP=${CLISP:-"clisp"}

make clean optimize-files
ulimit -s 8192
${CLISP} ${CLISP_OPT} -i sysdep/setup-clisp.lisp -i do-compilation-script.lisp -x '(quit)'
${CLISP} ${CLISP_OPT} -i sysdep/setup-clisp.lisp -i do-execute-script.lisp -x '(quit)'
