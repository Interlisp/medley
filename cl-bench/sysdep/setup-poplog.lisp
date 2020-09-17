;;; setup file for cl-bench running in Poplog CL

(in-package :common-lisp-user)

;; see <URL:http://www.cs.bham.ac.uk/research/poplog/doc/lisphelp/storeutils>
;; this is to allow the heap to grow as needed
(cl:require :storeutils)
(setq *max-store-size* nil)
(setf *default-pathname-defaults* #p"temp.lisp")


;; increase the maximum recursion level
(poplog:pop11)

section $-lisp;

uses pop_callstack_lim;
pop_callstack_lim * 10 -> pop_callstack_lim;
endsection;

lisp


(in-package :cl)

(defun compile-file-pathname (pathname)
  pathname)

(export 'compile-file-pathname (find-package "CL"))


(load "defpackage")
(in-package :cl-bench)

(defmacro with-spawned-thread (&body body)
  `(progn ,@body))

(defun bench-gc () (poplog:gc))


;; EOF
