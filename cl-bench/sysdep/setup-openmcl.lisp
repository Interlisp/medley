;;; setup file for cl-bench running in OpenMCL

(load "defpackage")
(in-package :cl-bench)

;; 20 MB heap
(ccl:set-lisp-heap-gc-threshold (ash 2 20))

(defun bench-gc () (ccl:gc))



(setq ccl:*request-terminal-input-via-break* t)

(defvar *thread-pool-lock*
  (ccl:make-lock "cl-bench thread pool lock"))

(defvar *thread-pool-semaphore* (ccl:make-semaphore))

(defvar *thread-pool* (list))

(ccl:with-lock-grabbed (*thread-pool-lock*)
  (dotimes (i 3)
    (push (ccl:make-process "cl-bench") *thread-pool*)
    (ccl:signal-semaphore *thread-pool-semaphore*)))


;; run BODY inside a new thread
#+nil
(defmacro with-spawned-thread (&body body)
  `(let ((thread nil))
     (ccl:wait-on-semaphore *thread-pool-semaphore*)
     (ccl:with-lock-grabbed (*thread-pool-lock*)
        (setq thread (pop *thread-pool*)))
     (format *debug-io* "Acquired process ~A~%" thread)
     (assert (ccl::processp thread))
     (ccl:process-preset thread
       (lambda ()
         ,@body
         (ccl:process-reset ccl:*current-process*)
         (ccl:with-lock-grabbed (*thread-pool-lock*)
            (push ccl:*current-process* *thread-pool*)
            (ccl:signal-semaphore *thread-pool-semaphore*))))
    (ccl:process-enable thread)))


(defmacro with-spawned-thread (&body body)
  `(progn ,@body))

;; EOF
