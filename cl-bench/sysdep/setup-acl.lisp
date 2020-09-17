;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;; setup file for cl-bench running in ACL 6.2
;;;
;;; contributed by Kevin Layer

(eval-when (compile eval load) (load "defpackage"))

;; disable for the same tests as Lispworks Personal edition (limited heap size)
(when (search "Trial Edition" (lisp-implementation-type))
  (push :lispworks-personal-edition *features*))

(in-package :cl-bench)

(defmacro with-spawned-thread (&body body)
  ;; run BODY inside a new thread
  ;;
  ;; KL: what's the point of running them in a separate process?   It sure
  ;; makes debugging problems harder...
  #+ignore
  `(mp:process-run-function "cl-bench"
     (lambda () ,@body))
  #-ignore
  `(progn ,@body))

(defun bench-gc () (gc t))

(setq excl:*record-source-file-info* nil)
(setq excl:*load-source-file-info* nil)
(setq excl:*record-xref-info* nil)
(setq excl:*load-xref-info* nil)
(setq excl:*global-gc-behavior* nil)

;; disabled by emarsden: I don't consider this fair
;; (setq excl::*default-rehash-size* 2.0)
;; (setq *print-pretty* nil)

;; for debugging:
#+ignore
(progn
  (setf (sys:gsgc-switch :print) t)
  (setf (sys:gsgc-switch :verbose) t))

;; EOF
