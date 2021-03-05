;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;;. Copyright (c) 1991 by Venue

(in-package "CLOS")


(eval-when (compile load eval)
       (fix-early-generic-functions)
       (setq *boot-state* 'complete))

(defun print-std-instance (instance stream depth)
       (declare (ignore depth))
       (print-object instance stream))
