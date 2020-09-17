;;; support.lisp --- performance benchmarks for Common Lisp implementations
;;
;; Author: Eric Marsden  <emarsden@laas.fr>
;; Time-stamp: <2004-08-01 emarsden>
;;
;;
;; The benchmarks consist of
;;
;;   - the Gabriel benchmarks
;;   - some mathematical operations (factorial, fibonnaci, CRC)
;;   - some bignum-intensive operations
;;   - hashtable and READ-LINE tests
;;   - CLOS tests
;;   - array, string and bitvector exercises
;;


(in-package :cl-bench)

(defvar *version* "20040801")

(defvar *benchmarks* '())
(defvar *benchmark-results* '())

(defvar +implementation+
  (concatenate 'string
               (lisp-implementation-type) " "
               (lisp-implementation-version)))


(defclass benchmark ()
    ((name   :accessor benchmark-name
             :initarg :name)
     (short  :accessor benchmark-short
             :initarg :short
             :type string)
     (long   :accessor benchmark-long
             :initarg :long
             :initform nil
             :type string)
     (group  :accessor benchmark-group
             :initarg :group)
     (runs   :accessor benchmark-runs
             :initarg :runs
             :initform 1
             :type integer)
     (disabled-for :accessor benchmark-disabled-for
                   :initarg :disabled-for
                   :initform nil)
     (setup    :initarg :setup
               :initform nil)
     (function :initarg :function
               :accessor benchmark-function)))

(defmethod print-object ((self benchmark) stream)
  (print-unreadable-object (self stream :type nil)
     (format stream "benchmark ~a for ~d runs"
             (benchmark-short self)
             (benchmark-runs self))))

(defmethod initialize-instance :after ((self benchmark)
                                       &rest initargs
                                       &key &allow-other-keys)
   (declare (ignore initargs))
   (unless (slot-boundp self 'short)
     (setf (benchmark-short self) (string (benchmark-name self))))
   self)

;;    (setf (benchmark-function self)
;;          (compile nil `(lambda ()
;;                         (dotimes (i ,(benchmark-runs self))
;;                           `(funcall ',(benchmark-function ,self))))))


(defmacro defbench (fun &rest args)
  `(push (make-instance 'benchmark :name ',fun ,@args)
         *benchmarks*))



(defvar *benchmark-output*)
(defvar *current-test*)


(defmacro with-bench-output (&body body)
  `(with-open-file (f (benchmark-report-file)
                    :direction :output
                    :if-exists :supersede)
    (let ((*benchmark-output* f)
          (*load-verbose* nil)
          (*print-length* nil)
          (*compile-verbose* nil)
          (*compile-print* nil))
      (bench-report-header)
      (progn ,@body)
      (bench-report-footer))))


(defun bench-run ()
  (with-open-file (f (benchmark-report-file)
                     :direction :output
                     :if-exists :supersede)
     (let ((*benchmark-output* f)
           (*print-length*)
           (*load-verbose* nil)
           (*compile-verbose* nil)
           (*compile-print* nil))
       (bench-report-header)
       (dolist (b (reverse *benchmarks*))
         (bench-gc)
         (with-spawned-thread
             (with-slots (setup function short runs) b
               (when setup (funcall setup))
               (format t "~&=== running ~a~%" b)
               (bench-report function short runs))))
       (bench-report-footer))))


(defun benchmark-report-file ()
  (multiple-value-bind (second minute hour date month year)
      (get-decoded-time)
    (declare (ignore second))
    (format nil "~aCL-benchmark-~d~2,'0d~2,'0dT~2,'0d~2,'0d"
            #+win32 "" #-win32 "/var/tmp/"
            year month date hour minute)))

;; grr, CLISP doesn't implement ~<..~:>

;; CormanLisp bug:
;;; An error occurred in function FORMAT:
;;; Error: Invalid format directive : character #\< in control string ";; -*- lisp -*-  ~a~%;;~%;; Implementation *features*:~%~@<;; ~@;~s~:>~%;;~%"
;;; Entering Corman Lisp debug loop.
(defun bench-report-header ()
  (format *benchmark-output*
          #-(or clisp ecl gcl cormanlisp) ";; -*- lisp -*-  ~a~%;;~%;; Implementation *features*:~%~@<;; ~@;~s~:>~%;;~%"
          #+(or clisp ecl gcl cormanlisp) ";; -*- lisp -*- ~a~%;; Implementation *features*: ~s~%;;~%"
          +implementation+ *features*)
  (format *benchmark-output*
          ";; Function                      real     user     sys       consed~%")
  (format *benchmark-output*
          ";; ----------------------------------------------------------------~%"))

(defun bench-report-footer ()
  (format *benchmark-output* "~%~s~%"
          (cons +implementation+ *benchmark-results*)))

;; generate a report to *benchmark-output* on the calling of FUNCTION
(defun bench-report (function name times)
  (multiple-value-bind (real user sys consed)
      (bench-time function times name)
    (format *benchmark-output*
            #-armedbear ";; ~25a ~8,2f ~8,2f ~8,2f ~12d"
            #+armedbear ";; ~a ~f ~f ~f ~d"
            name real user sys consed)
    (terpri *benchmark-output*)
    (force-output *benchmark-output*)
    (push (cons name (list real user sys consed))
          *benchmark-results*)))


;; a generic timing function, that depends on GET-INTERNAL-RUN-TIME
;; and GET-INTERNAL-REAL-TIME returning sensible results. If a version
;; was defined in sysdep/setup-<impl>, we use that instead
(defun generic-bench-time (fun times name)
  (declare (ignore name))
  (let (before-real after-real before-user after-user)
    (setq before-user (get-internal-run-time))
    (setq before-real (get-internal-real-time))
    (dotimes (i times)
      (funcall fun))
    (setq after-user (get-internal-run-time))
    (setq after-real (get-internal-real-time))
    ;; return real user sys consed
    (values (/ (- after-real before-real) internal-time-units-per-second)
            (/ (- after-user before-user) internal-time-units-per-second)
            0 0)))

(eval-when (:load-toplevel :execute)
  (unless (fboundp 'bench-time)
    ;; GCL as of 20040628 does not implement (setf fdefinition)
    #-gcl (setf (fdefinition 'bench-time) #'generic-bench-time)
    #+gcl (defun bench-time (fun times name) (generic-bench-time fun times name))))


;; EOF
