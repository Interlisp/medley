;;; setup file for cl-bench running in CMUCL

(load "defpackage")
(in-package :cl-bench)


(setq ext:*bytes-consed-between-gcs* 25000000)

;; to avoid problems when running the bignum code (the default of
;; 40000 is too low for some of the tests)
(setq ext:*intexp-maximum-exponent* 100000)


#+(and mp experimental)
;; run BODY inside a new thread
(defmacro with-spawned-thread (&body body)
  `(mp:make-process (lambda () ,@body) :name "cl-bench"))

;; #-mp
(defmacro with-spawned-thread (&body body)
  `(progn ,@body))


(defun bench-gc ()
  (ext:gc #+gencgc :full #+gencgc t))



;; internals stuff that is mostly for stress-testing CMUCL

;; disable the byte compiler
#+nil (setq ext:*byte-compile-default* nil)
#+nil (setq ext:*block-compile-default* t)

;; testing the dynamic-extent support
#+nil 
(setq ext:*trust-dynamic-extent-declarations* t
      *suppress-dynamic-extent-safe-closures* t)


#+gencgc
(progn
  (alien:def-alien-variable ("gencgc_verbose" gencgc-verbose) c-call::int)
  (alien:def-alien-variable ("verify_gens" gencgc-verify-gens) c-call::int)    
  (alien:def-alien-variable ("pre_verify_gen_0" gencgc-pre-verify-gen0) c-call::int)
  (alien:def-alien-variable ("verify_after_free_heap" gencgc-verify-after-free-heap) c-call::int)
  (alien:def-alien-variable ("verify_dynamic_code_check" gencgc-verify-dynamic-code-check) c-call::int)
  (alien:def-alien-variable ("check_code_fixups" gencgc-check-code-fixups) c-call::int)
  (alien:def-alien-variable ("gencgc_zero_check" gencgc-zero-check) c-call::int)
  (alien:def-alien-variable ("gencgc_enable_verify_zero_fill" gencgc-enable-verify-zero-fill) c-call::int)
  (alien:def-alien-variable ("gencgc_zero_check_during_free_heap"
                       gencgc-zero-check-during-free-heap) c-call::int)

  (defun gencgc-enable-checking ()
    (setf gencgc-verify-gens 0)
    (dolist (check '(gencgc-pre-verify-gen0
                     gencgc-verify-after-free-heap
                     gencgc-verify-dynamic-code-check
                     gencgc-check-code-fixups
                     gencgc-zero-check
                     gencgc-enable-verify-zero-fill
                     gencgc-zero-check-during-free-heap))
      (setf check 1))))


;; enable as much internal checking as possible
(defun ecm-paranoid ()
  #+gencgc (gencgc-enable-checking)
  (setf c::*check-consistency* t)
  (setf c::*always-clear-stack* t)
  (setf (gethash "Target for ~S isn't complementary write-p." c::*ignored-errors*) t)
  (setf pcl::*check-cache-p* t))


#+nil (ecm-paranoid)


;; adapted from code pulled from src/code/time.lisp
#-(and sparc-v9 performance-counters)
(defun bench-time (fun times name)
  (declare (ignore name))
  (let (old-run-utime
        new-run-utime
        old-run-stime
        new-run-stime
        old-real-time
        new-real-time
        old-page-faults
        new-page-faults
        real-time-overhead
        run-utime-overhead
        run-stime-overhead
        old-bytes-consed
        new-bytes-consed
        cons-overhead)
    ;; Calculate the overhead...
    (multiple-value-setq
        (old-run-utime old-run-stime old-page-faults old-bytes-consed)
      (lisp::time-get-sys-info))
    ;; Do it a second time to make sure everything is faulted in.
    (multiple-value-setq
        (old-run-utime old-run-stime old-page-faults old-bytes-consed)
      (lisp::time-get-sys-info))
    (multiple-value-setq
        (new-run-utime new-run-stime new-page-faults new-bytes-consed)
      (lisp::time-get-sys-info))
    (setq run-utime-overhead (- new-run-utime old-run-utime))
    (setq run-stime-overhead (- new-run-stime old-run-stime))
    (setq old-real-time (get-internal-real-time))
    (setq old-real-time (get-internal-real-time))
    (setq new-real-time (get-internal-real-time))
    (setq real-time-overhead (- new-real-time old-real-time))
    (setq cons-overhead (- new-bytes-consed old-bytes-consed))
    ;; Now get the initial times.
    (multiple-value-setq
        (old-run-utime old-run-stime old-page-faults old-bytes-consed)
      (lisp::time-get-sys-info))
    (setq old-real-time (get-internal-real-time))
    (dotimes (i times)
      (funcall fun))
    (multiple-value-setq
        (new-run-utime new-run-stime new-page-faults new-bytes-consed)
      (lisp::time-get-sys-info))
    (setq new-real-time (- (get-internal-real-time) real-time-overhead))
    ;; returns real user sys consed
    (values
     (max (/ (- new-real-time old-real-time)
             (float internal-time-units-per-second))
          0.0)
     (max (/ (- new-run-utime old-run-utime) 1000000.0) 0.0)
     (max (/ (- new-run-stime old-run-stime) 1000000.0) 0.0)
     (max (- new-bytes-consed old-bytes-consed) 0))))


#+(and sparc-v9 performance-counters)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (require :cpc))

#+(and sparc-v9 performance-counters)
(defun bench-time (function times name)
  (declare (ignore times))
  (with-open-file (dis "/tmp/cmucl-disassembly.txt"
                       :direction :output
                       :if-exists :append
                       :if-does-not-exist :create)
    (format dis "~%~% === Disassembly for ~A~%" function)
    (disassemble function :stream dis))
  (let* ((cpi (cpc::calculate-cpi function))
         (icache-miss (cpc::calculate-icache-miss function))
         (ecache-miss (cpc::calculate-ecache-miss function))
         (stall-icache (cpc::calculate-instruction-stall function))
         ;; (stall-mispredict (cpc::calculate-mispredict-stall function))
         (stall-load  (cpc::calculate-load-stall function)))
    (with-open-file (out "/tmp/cmucl-cpc.txt"
                         :direction :output
                         :if-exists :append
                         :if-does-not-exist :create)
      (format out
              ";; ~25a ~5,2f   [i: ~4,1f ~4,1f ]  [e: ~4,1f]  ~4,1f~%"
              name cpi
              (* 100 icache-miss) (* 100 stall-icache)
              (* 100 ecache-miss) (* 100 stall-load)))))

;; EOF
