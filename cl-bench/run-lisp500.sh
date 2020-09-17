#!/bin/sh

L500=lisp500

make clean optimize-files
${L500} <<EOF
(load "sysdep/setup-lisp500.lisp")
(load "do-compilation-script.lisp")
(quit)
EOF

${L500} <<EOF
(load "sysdep/setup-lisp500.lisp")
(load "do-execute-script.lisp")
(quit)
EOF
