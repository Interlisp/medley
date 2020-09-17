#!/bin/sh

OPENMCL=${OPENMCL:-openmcl}
OPENMCL_OPT="--batch --no-init"

make clean optimize-files
${OPENMCL} ${OPENMCL_OPT} --load sysdep/setup-openmcl.lisp --load do-compilation-script.lisp --eval '(ccl:quit)'
${OPENMCL} ${OPENMCL_OPT} --load sysdep/setup-openmcl.lisp --load do-execute-script.lisp --eval '(ccl:quit)'
