;;; setup file for running cl-bench in GCL

(load "defpackage.lisp")
(in-package :cl-bench)


(defun bench-gc () (lisp:gbc t))


(defmacro with-spawned-thread (&body body)
  `(progn ,@body))


#+older-gcl
(defmacro with-standard-io-syntax (&body body)
  `(progn ,@body))


;; EOF
