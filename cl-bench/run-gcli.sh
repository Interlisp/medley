#!/bin/sh

# GCL in interpreted mode

GCL_ANSI=1
export GCL_ANSI
GCL=${GCL:-gclcvs}

make clean optimize-files
${GCL} -load sysdep/setup-gcl.lisp -load do-interpret-script.lisp -eval '(quit)'
