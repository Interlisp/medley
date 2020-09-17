#!/bin/bash
#
# contributed by Kevin Layer

ACL=${ACL:-"alisp -qq"}

make clean optimize-files

$ACL -L sysdep/setup-acl.lisp -L do-compilation-script.lisp -kill
$ACL -L sysdep/setup-acl.lisp -L do-execute-script.lisp -kill
