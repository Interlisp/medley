;;; setup file for running cl-bench in Lispworks

(load "defpackage")
(in-package :cl-bench)

(hcl:toggle-source-debugging nil)


(defun bench-gc () (hcl:gc-if-needed))

(defmacro with-spawned-thread (&body body)
  `(progn ,@body))


;; EOF
