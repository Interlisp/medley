#!/bin/sh

ECL=ecl

${ECL} <<EOF
(load "sysdep/setup-ecl.lisp")
(load "do-compilation-script.lisp")
(quit)
EOF

${ECL} <<EOF
(load "sysdep/setup-ecl.lisp")
(load "do-execute-script.lisp")
(quit)
EOF
