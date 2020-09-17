;;; setup file for running cl-bench in lisp500

(load "defpackage")
(in-package :cl-bench)


(defun bench-gc () (cl:gc))

(defmacro with-spawned-thread (&body body)
  `(progn ,@body))


;; EOF
