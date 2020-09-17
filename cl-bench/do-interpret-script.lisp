;;; auto-generated from file #p"generate.lisp"
(IN-PACKAGE :CL-USER)
(LOAD #p"defpackage.lisp")
(LOAD #p"files/arrays.olisp")
(LOAD #p"files/bignum.olisp")
(LOAD #p"files/boehm-gc.olisp")
(LOAD #p"files/clos.olisp")
(LOAD #p"files/crc40.olisp")
(LOAD #p"files/deflate.olisp")
(LOAD #p"files/gabriel.olisp")
(LOAD #p"files/hash.olisp")
(LOAD #p"files/math.olisp")
(LOAD #p"files/ratios.olisp")
(LOAD #p"files/richards.olisp")
(LOAD #p"files/misc.olisp")
(LOAD #p"support.lisp")
(IN-PACKAGE :CL-BENCH)
(defun run-benchmarks ()
 (with-open-file (f (benchmark-report-file)
                    :direction :output
                    :if-exists :supersede)
   (let ((*benchmark-output* f)
         (*print-length* nil)
         (*load-verbose* nil)
         (*compile-verbose* nil)
         (*compile-print* nil))
     (bench-report-header)

#-(or gcl armedbear)
(progn
  (format t "=== running #<benchmark COMPILER for 3 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.misc:run-compiler "COMPILER" 3))

#-(or gcl armedbear ecl)
(progn
  (format t "=== running #<benchmark LOAD-FASL for 20 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.misc:run-fasload "LOAD-FASL" 20))

#-(or lispworks-personal-edition ecl)
(progn
  (format t "=== running #<benchmark SUM-PERMUTATIONS for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.misc:run-permutations "SUM-PERMUTATIONS" 2))

#-(or lispworks-personal-edition armedbear)
(progn
  (format t "=== running #<benchmark WALK-LIST/SEQ for 2 runs>~%")
  (force-output)
  (bench-gc)
  (funcall 'cl-bench.misc::setup-walk-list/seq)
  (bench-report 'cl-bench.misc:walk-list/seq "WALK-LIST/SEQ" 2))

#-(or lispworks-personal-edition armedbear poplog)
(progn
  (format t "=== running #<benchmark WALK-LIST/MESS for 1 runs>~%")
  (force-output)
  (bench-gc)
  (funcall 'cl-bench.misc::setup-walk-list/mess)
  (bench-report 'cl-bench.misc:walk-list/mess "WALK-LIST/MESS" 1))
(progn
  (format t "=== running #<benchmark BOYER for 30 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:boyer "BOYER" 30))
(progn
  (format t "=== running #<benchmark BROWSE for 10 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:browse "BROWSE" 10))
(progn
  (format t "=== running #<benchmark DDERIV for 50 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:dderiv-run "DDERIV" 50))
(progn
  (format t "=== running #<benchmark DERIV for 60 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:deriv-run "DERIV" 60))
(progn
  (format t "=== running #<benchmark DESTRUCTIVE for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-destructive "DESTRUCTIVE" 100))
(progn
  (format t "=== running #<benchmark DIV2-TEST-1 for 200 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-div2-test1 "DIV2-TEST-1" 200))
(progn
  (format t "=== running #<benchmark DIV2-TEST-2 for 200 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-div2-test2 "DIV2-TEST-2" 200))
(progn
  (format t "=== running #<benchmark FFT for 30 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-fft "FFT" 30))
(progn
  (format t "=== running #<benchmark FRPOLY/FIXNUM for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-frpoly/fixnum "FRPOLY/FIXNUM" 100))
(progn
  (format t "=== running #<benchmark FRPOLY/BIGNUM for 30 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-frpoly/bignum "FRPOLY/BIGNUM" 30))
(progn
  (format t "=== running #<benchmark FRPOLY/FLOAT for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-frpoly/float "FRPOLY/FLOAT" 100))
(progn
  (format t "=== running #<benchmark PUZZLE for 1500 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-puzzle "PUZZLE" 1500))
(progn
  (format t "=== running #<benchmark TAK for 500 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-tak "TAK" 500))
(progn
  (format t "=== running #<benchmark CTAK for 900 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-ctak "CTAK" 900))
(progn
  (format t "=== running #<benchmark TRTAK for 500 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-trtak "TRTAK" 500))
(progn
  (format t "=== running #<benchmark TAKL for 150 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-takl "TAKL" 150))
(progn
  (format t "=== running #<benchmark STAK for 200 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-stak "STAK" 200))
(progn
  (format t "=== running #<benchmark FPRINT/UGLY for 200 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:fprint/ugly "FPRINT/UGLY" 200))
(progn
  (format t "=== running #<benchmark FPRINT/PRETTY for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:fprint/pretty "FPRINT/PRETTY" 100))
(progn
  (format t "=== running #<benchmark TRAVERSE for 15 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-traverse "TRAVERSE" 15))
(progn
  (format t "=== running #<benchmark TRIANGLE for 5 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.gabriel:run-triangle "TRIANGLE" 5))
(progn
  (format t "=== running #<benchmark RICHARDS for 5 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.richards:richards "RICHARDS" 5))
(progn
  (format t "=== running #<benchmark FACTORIAL for 1000 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.math:run-factorial "FACTORIAL" 1000))
(progn
  (format t "=== running #<benchmark FIB for 50 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.math:run-fib "FIB" 50))
(progn
  (format t "=== running #<benchmark FIB-RATIO for 500 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.math:run-fib-ratio "FIB-RATIO" 500))
(progn
  (format t "=== running #<benchmark ACKERMANN for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.math:run-ackermann "ACKERMANN" 1))
(progn
  (format t "=== running #<benchmark MANDELBROT/COMPLEX for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.math:run-mandelbrot/complex "MANDELBROT/COMPLEX" 100))
(progn
  (format t "=== running #<benchmark MANDELBROT/DFLOAT for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.math:run-mandelbrot/dfloat "MANDELBROT/DFLOAT" 100))
(progn
  (format t "=== running #<benchmark MRG32K3A for 20 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.math:run-mrg32k3a "MRG32K3A" 20))
(progn
  (format t "=== running #<benchmark CRC40 for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.crc:run-crc40 "CRC40" 2))
(progn
  (format t "=== running #<benchmark BIGNUM/ELEM-100-1000 for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-elem-100-1000 "BIGNUM/ELEM-100-1000" 1))
(progn
  (format t "=== running #<benchmark BIGNUM/ELEM-1000-100 for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-elem-1000-100 "BIGNUM/ELEM-1000-100" 1))
(progn
  (format t "=== running #<benchmark BIGNUM/ELEM-10000-1 for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-elem-10000-1 "BIGNUM/ELEM-10000-1" 1))
(progn
  (format t "=== running #<benchmark BIGNUM/PARI-100-10 for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-pari-100-10 "BIGNUM/PARI-100-10" 1))
(progn
  (format t "=== running #<benchmark BIGNUM/PARI-200-5 for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-pari-200-5 "BIGNUM/PARI-200-5" 1))
(progn
  (format t "=== running #<benchmark PI-DECIMAL/SMALL for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-pi-decimal/small "PI-DECIMAL/SMALL" 100))
(progn
  (format t "=== running #<benchmark PI-DECIMAL/BIG for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-pi-decimal/big "PI-DECIMAL/BIG" 2))
(progn
  (format t "=== running #<benchmark PI-ATAN for 200 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.bignum:run-pi-atan "PI-ATAN" 200))
(progn
  (format t "=== running #<benchmark PI-RATIOS for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.ratios:run-pi-ratios "PI-RATIOS" 2))
(progn
  (format t "=== running #<benchmark HASH-STRINGS for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.hash:hash-strings "HASH-STRINGS" 2))
(progn
  (format t "=== running #<benchmark HASH-INTEGERS for 10 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.hash:hash-integers "HASH-INTEGERS" 10))
(progn
  (format t "=== running #<benchmark SLURP-LINES for 30 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.hash:run-slurp-lines "SLURP-LINES" 30))

#-(or lispworks-personal-edition)
(progn
  (format t "=== running #<benchmark BOEHM-GC for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.boehm-gc:gc-benchmark "BOEHM-GC" 1))
(progn
  (format t "=== running #<benchmark DEFLATE-FILE for 100 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.deflate:run-deflate-file "DEFLATE-FILE" 100))

#-(or lispworks-personal-edition)
(progn
  (format t "=== running #<benchmark 1D-ARRAYS for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-1d-arrays "1D-ARRAYS" 1))

#-(or lispworks-personal-edition)
(progn
  (format t "=== running #<benchmark 2D-ARRAYS for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-2d-arrays "2D-ARRAYS" 1))

#-(or lispworks-personal-edition)
(progn
  (format t "=== running #<benchmark 3D-ARRAYS for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-3d-arrays "3D-ARRAYS" 1))
(progn
  (format t "=== running #<benchmark BITVECTORS for 3 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-bitvectors "BITVECTORS" 3))

#-(or lispworks-personal-edition)
(progn
  (format t "=== running #<benchmark BENCH-STRINGS for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-strings "BENCH-STRINGS" 1))

#-(or lispworks-personal-edition)
(progn
  (format t "=== running #<benchmark fill-strings/adjustable for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-strings/adjustable "fill-strings/adjustable" 1))

#-(or allegro lispworks-personal-edition poplog)
(progn
  (format t "=== running #<benchmark STRING-CONCAT for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-string-concat "STRING-CONCAT" 1))

#-(or lispworks-personal-edition)
(progn
  (format t "=== running #<benchmark SEARCH-SEQUENCE for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.arrays:bench-search-sequence "SEARCH-SEQUENCE" 1))
(progn
  (format t "=== running #<benchmark CLOS/defclass for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:run-defclass "CLOS/defclass" 1))
(progn
  (format t "=== running #<benchmark CLOS/defmethod for 1 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:run-defmethod "CLOS/defmethod" 1))
(progn
  (format t "=== running #<benchmark CLOS/instantiate for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:make-instances "CLOS/instantiate" 2))
(progn
  (format t "=== running #<benchmark CLOS/simple-instantiate for 200 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:make-instances/simple "CLOS/simple-instantiate" 200))
(progn
  (format t "=== running #<benchmark CLOS/methodcalls for 5 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:methodcalls/simple "CLOS/methodcalls" 5))
(progn
  (format t "=== running #<benchmark CLOS/method+after for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:methodcalls/simple+after "CLOS/method+after" 2))

#-(or clisp poplog)
(progn
  (format t "=== running #<benchmark CLOS/complex-methods for 5 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:methodcalls/complex "CLOS/complex-methods" 5))
(progn
  (format t "=== running #<benchmark EQL-SPECIALIZED-FIB for 2 runs>~%")
  (force-output)
  (bench-gc)
  (bench-report 'cl-bench.clos:run-eql-fib "EQL-SPECIALIZED-FIB" 2))
(bench-report-footer))))
(run-benchmarks)
