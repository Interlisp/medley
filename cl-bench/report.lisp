;;; report.lisp
;;
;; Author: Eric Marsden  <emarsden@laas.fr>
;; Time-stamp: <2004-02-29 emarsden>
;;
;;
;; When loaded into CMUCL, this should generate a report comparing the
;; performance of the different CL implementations which have been
;; tested. Reads the /var/tmp/CL-benchmark* files to obtain data from
;; previous runs.
;;
;; FIXME could create graphical version using ploticus


(in-package :cl-user)

(defconstant +implementation+
  (concatenate 'string
               (lisp-implementation-type) " "
               (lisp-implementation-version)))

(defun bench-analysis ()
  (let (data implementations benchmarks)
    (dolist (f (directory "/var/tmp/CL-benchmark*.*"))
      (ignore-errors
        (with-open-file (f f :direction :input)
          (let ((*read-eval* nil))
            (push (read f) data)))))
    (setq implementations (delete +implementation+ (mapcar #'car data) :test #'string=))
    (setq benchmarks (reverse (mapcar #'first (cdr (first data)))))
    (format t "~25a~10@a" "Benchmark" "Reference")
    (dolist (impl implementations)
      (format t "~7@a" (subseq impl 0 5)))
    (format t "~%-------------------------------------------------------------------------------------~%")
    (dolist (b benchmarks)
      (format t "~&~25a" b)
      (let* ((reference-data (cdr (assoc +implementation+ data :test #'string=)))
             (reference-user (third (assoc b reference-data :test #'string=))))
        ;; user time spent by reference implementation, in seconds
        (format t "[~10,2f]" reference-user)
        (dolist (i implementations)
          (let* ((id (cdr (assoc i data :test #'string=)))
                 (ir (third (assoc b id :test #'string=))))
            (format t "~7,2f" (handler-case (/ ir reference-user) (error () -1)))))))
    (terpri)
    (format t "Reference time in first column is in seconds; other columns are relative~%")
    (format t "Reference implementation: ~a~%" +implementation+)
    (dolist (impl implementations)
      (format t "~&Impl ~a: ~a~%" (subseq impl 0 5) impl))
    (format t "=== Test machine ===~%")
    (format t "   Machine-type: ~A~%" (machine-type))
    (format t "   Machine-version: ~A~%" (machine-version))
    #+cmu
    (run-program "uname" '("-a") :output t)
    (terpri)
    (force-output)))

(bench-analysis)
(quit)

;; EOF
