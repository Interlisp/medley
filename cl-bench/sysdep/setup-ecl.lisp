;;; setup file for cl-bench running in ECL
;;
;; tested with ECL 0.9
;;
;; see <URL:http://ecls.sf.net/>

(load "defpackage")
(in-package :cl-bench)


(defun bench-gc ()
  (si:gc t))

(defmacro with-spawned-thread (&body body)
  `(progn ,@body))


;; to autoload the compiler
(compile 'bench-gc)
(setq c::*cc-flags* (concatenate 'string "-I. " c::*cc-flags*))

;; EOF
