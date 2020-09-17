;;; setup file for running cl-bench in CLISP

(load "defpackage")
(in-package :cl-bench)


(setq custom:*warn-on-floating-point-contagion* nil)


(defun bench-gc () (gc))

(defmacro with-spawned-thread (&body body)
  `(progn ,@body))



(defun bench-time (fun times name)
  (declare (ignore name))
  (labels ((merge-2-values (val1 val2)
                (if (< internal-time-units-per-second 1000000)
                    (dpb val1 (byte 16 16) val2) ; TIME_1: AMIGA, DOS, OS/2, UNIX_TIMES
                  (+ (* val1 internal-time-units-per-second) val2))) ; TIME_2: UNIX sonst, WIN32
           (secs (v1 v2 v3 v4)
                 (/ (- (merge-2-values v1 v2)
                       (merge-2-values v3 v4))
                    internal-time-units-per-second)))
    (multiple-value-bind (new-real1
                          new-real2
                          new-run1
                          new-run2
                          new-gc1
                          new-gc2
                          new-space1
                          new-space2
                          new-gccount)
        (sys::%%time)
      (dotimes (i times) (funcall fun))
      (multiple-value-bind (old-real1
                            old-real2
                            old-run1
                            old-run2
                            old-gc1
                            old-gc2
                            old-space1
                            old-space2
                            old-gccount)
          (sys::%%time)
        ;; returns real user sys consed
        (values (secs old-real1 old-real2 new-real1 new-real2)
                (secs old-run1 old-run2 new-run1 new-run2)
                0.0
                (- old-gccount new-gccount))))))


;; EOF
