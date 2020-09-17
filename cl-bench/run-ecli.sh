#!/bin/sh
#
# ECL in interpreted mode

ECL=ecl

make clean optimize-files
${ECL} <<EOF
(load "sysdep/setup-ecl.lisp")
(load "do-interpret-script.lisp")
(quit)
EOF
