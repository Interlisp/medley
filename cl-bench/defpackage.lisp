;;; defpackage.lisp -- DEFPACKAGE forms for the cl-bench modules
;;
;; Time-stamp: <2004-01-01 emarsden>


(defpackage :cl-bench
  (:use :common-lisp
        #+cmu :ext
        #+clisp :ext
        #+allegro :excl))

(defpackage :cl-bench.gabriel
  (:use :common-lisp)
  (:export #:boyer
           #:browse
           #:dderiv-run
           #:deriv-run
           #:run-destructive
           #:run-div2-test1
           #:run-div2-test2
           #:div2-l
           #:run-fft
           #:run-frpoly/fixnum
           #:run-frpoly/bignum
           #:run-frpoly/float
           #:run-puzzle
           #:run-tak
           #:run-ctak
           #:run-trtak
           #:run-takl
           #:run-stak
           #:fprint/pretty
           #:fprint/ugly
           #:run-traverse
           #:run-triangle))

(defpackage :cl-bench.math
  (:use :common-lisp)
  (:export #:run-factorial
           #:run-fib
           #:run-fib-ratio
           #:run-ackermann
           #:run-mandelbrot/complex
           #:run-mandelbrot/dfloat
           #:run-mrg32k3a))

(defpackage :cl-bench.crc
  (:use :common-lisp)
  (:export #:run-crc40))

(defpackage :cl-bench.bignum
  (:use :common-lisp)
  (:export #:run-elem-100-1000
           #:run-elem-1000-100
           #:run-elem-10000-1
           #:run-pari-100-10
           #:run-pari-200-5
           #:run-pari-1000-1
           #:run-pi-decimal/small
           #:run-pi-decimal/big
           #:run-pi-atan))

(defpackage :cl-bench.ratios
  (:use :common-lisp)
  (:export #:run-pi-ratios))

(defpackage :cl-bench.hash
  (:use :common-lisp)
  (:export #:run-slurp-lines
           #:hash-strings
           #:hash-integers))

(defpackage :cl-bench.boehm-gc
  (:use :common-lisp)
  (:export #:gc-benchmark))

(defpackage :cl-bench.deflate
  (:use :common-lisp)
  (:export #:run-deflate-file))

(defpackage :cl-bench.arrays
  (:use :common-lisp)
  (:export #:bench-1d-arrays
           #:bench-2d-arrays
           #:bench-3d-arrays
           #:bench-bitvectors
           #:bench-strings
           #:bench-strings/adjustable
           #:bench-string-concat
           #:bench-search-sequence))

(defpackage :cl-bench.richards
  (:use :common-lisp)
  (:export #:richards))

(defpackage :cl-bench.clos
  (:use :common-lisp)
  (:export #:run-defclass
           #:run-defmethod
           #:make-instances
           #:make-instances/simple
           #:methodcalls/simple
           #:methodcalls/simple+after
           #:methodcalls/complex
           #:run-eql-fib))

(defpackage :cl-bench.misc
  (:use :common-lisp)
  (:export #:run-compiler
           #:run-fasload
           #:run-permutations
           #:walk-list/seq
           #:walk-list/mess))

(defpackage :cl-ppcre-test
  (:use :common-lisp)
  (:export #:test))

;; EOF
