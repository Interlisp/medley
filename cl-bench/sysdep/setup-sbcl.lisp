;;; setup file for running cl-bench in SBCL

(load "defpackage")
(in-package :cl-bench)

(setf (sb-ext:bytes-consed-between-gcs) 25000000)


(setq sb-ext:*intexp-maximum-exponent* 100000)


(defun bench-gc ()
  (sb-ext:gc #+gencgc :full #+gencgc t))





;; (condition-wait queue lock)
;; (condition-notify queue)


;; run BODY inside a new thread
;; #+sb-thread
;; (defmacro with-spawned-thread (&body body)
;;   `(sb-thread:make-thread (lambda () ,@body)))
;; 
;; #-sb-thread
(defmacro with-spawned-thread (&body body)
  `(progn ,@body))

;; EOF
