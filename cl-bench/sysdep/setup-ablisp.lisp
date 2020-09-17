;;; setup file for running cl-bench in ArmedBear Lisp

(load "defpackage")
(in-package :cl-bench)


(defun bench-gc () (ext:gc))

(defmacro with-spawned-thread (&body body)
  `(progn ,@body))


;; as of 2003-12-05, this is not quite ready yet. In support.lisp we compile
;; various ABL internal packages and the cl-bench packages using
;; JVM::JVM-COMPILE-PACKAGE
#+nil (setq jvm:*auto-compile* t)


(eval-when (:load-toplevel :execute)
  (format *debug-io* "Loading JVM compiler ...~%")
  (load "/opt/src/cvs-armedbear/j/src/org/armedbear/lisp/jvm.lisp")
  (dolist (p '("CL" "SYS" "EXT" "PRECOMPILER"))
    (jvm::jvm-compile-package p))
  (format *debug-io* "Compiling all cl-bench packages ...~%")
  (dolist (p (list-all-packages))
    (when (eql 0 (search "CL-BENCH" (package-name p)))
      (jvm::jvm-compile-package p))))


;; EOF
