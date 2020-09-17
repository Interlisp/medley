#!/bin/bash
#
#
# See <URL:http://www.poplog.org/>. Poplog compiles while loading, so
# there is no need to load the compilation-script. 

POPLOG=${POPLOG:-"poplog"}

ulimit -s 8192
make clean optimize-files
$POPLOG <<EOF
(load "sysdep/setup-poplog.lisp")
(load "do-execute-script.lisp")
EOF
