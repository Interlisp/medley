;;; generate.lisp
;;;
;;; Time-stamp: <2004-01-01 emarsden>
;;
;;
;; Load into a CL implementation that has a working pathname
;; implementation, in order to generate a load-script and a
;; compilation-script, for implementations whose pathname support is
;; suboptimal.



(load #p"defpackage.lisp")
(load #p"support.lisp")
(load #p"tests.lisp")

(in-package :cl-bench)

(with-open-file (run "do-execute-script.lisp"
                        :direction :output
                        :if-exists :supersede
                        :if-does-not-exist :create)
  (with-open-file (compile "do-compilation-script.lisp"
                           :direction :output
                           :if-exists :supersede
                           :if-does-not-exist :create)
    (format run ";;; auto-generated from file ~S~%" *load-pathname*)
    (format compile ";;; auto-generated from file ~S~%" *load-pathname*)
    (format run "(IN-PACKAGE :CL-USER)~%")
    (format compile "(IN-PACKAGE :CL-USER)~%")
    (format run "(LOAD ~S)~%" #p"defpackage.lisp")
    (format compile "(LOAD ~S)~%" #p"defpackage.lisp")
    (dolist (f '("arrays" "bignum" "boehm-gc"
                 "clos" "crc40" "deflate" "gabriel"
                 "hash" "math" "ratios" "richards" "misc")
             #+nil (directory (make-pathname :directory '(:relative "files")
                                             :name :wild
                                             :version :wild
                                             :type "olisp")))
      (let ((p (make-pathname :directory '(:relative "files")
                              :name f
                              :type "olisp")))
        (format compile "(COMPILE-FILE ~S)~%" p)
      (format run "(LOAD (COMPILE-FILE-PATHNAME ~S))~%" p)))

    ;; for CL-PPCRE
    #+nil
    (dolist (name '("packages" "specials" "util" "lexer"
                    "parser" "regex-class" "convert" "optimize"
                    "closures" "repetition-closures" "scanner" "api"
                    "ppcre-tests"))
      (format compile "(COMPILE-FILE ~S)~%"
              (make-pathname :directory '(:relative "files" "cl-ppcre")
                             :name name
                             :type "lisp"))
      (format run "(LOAD (COMPILE-FILE-PATHNAME ~S))~%"
              (make-pathname :directory '(:relative "files" "cl-ppcre")
                             :name name)))

    (format run "(COMPILE-FILE ~S)~%" #p"support.lisp")
    (format run "(LOAD (COMPILE-FILE-PATHNAME ~S))~%" #p"support.lisp")
    (format run "(IN-PACKAGE :CL-BENCH)~%")
     (format run "(defun run-benchmarks ()
 (with-open-file (f (benchmark-report-file)
                    :direction :output
                    :if-exists :supersede)
   (let ((*benchmark-output* f)
         (*print-length* nil)
         (*load-verbose* nil)
         (*compile-verbose* nil)
         (*compile-print* nil))
     (bench-report-header)~%")
   (dolist (b (reverse *benchmarks*))
     (with-slots (setup disabled-for function short runs) b
       (when disabled-for
         (format run "~%#-~S~%" `(or ,@(benchmark-disabled-for b))))
       (format run "(progn~%")
       (format run "  (format t \"=== running ~A~~%\")~%" b)
       (format run "  (force-output)~%") 
       (format run "  (bench-gc)~%")
       (when setup
         (format run "  (funcall '~S)~%" setup))
       (format run "  (bench-report '~S ~S ~S))~%" function short runs)))
   (format run "(bench-report-footer))))~%")
   (format run "(run-benchmarks)~%")))


#+cmu (ext:quit)

;; EOF
