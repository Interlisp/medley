;;; playing with the CPU Performance Counters on CMUCL for Solaris
;;;
;;; Time-stamp: <2004-01-05 emarsden>
;;
;;
;; This will run the performance benchmarks with instrumentation from
;; the CPC library (see <http://www.chez.com/emarsden/downloads/ for
;; cpc.lisp, an FFI interface to Solaris libcpc). It will produce a
;; report in /tmp/cmucl-cpc.txt regarding various microarchitectural
;; measurements: average CPI for each test, proportion of icache
;; misses, number of cycles stalled due to icache misses or due to a
;; load-use dependency.
;;
;; This runs the each test a number of times, one for each observation
;; made, so it takes longer to run than a normal cl-bench run. Each
;; test is executed for a maximum of 3 seconds, using a SIGALRM-driven
;; interrupt. Some of the tests, in particular the CLOS tests, will
;; not work in this case, because their premature abortion means that
;; the following tests don't have all necessary classes defined. I
;; normally interrupt the tests manually at the SEARCH-SEQUENCE test.


#-sparc-v9
(error "Performance counters are only present on an UltraSPARC")

(unless
    (ignore-errors (require :cpc))
  (error "Can't load CPC subsystem"))

(setq ext:*gc-verbose* nil)

(push :performance-counters *features*)


(load "defpackage")
(compile-file "sysdep/setup-cmucl" :load t)
(load "do-compilation-script")
(load "do-execute-script")

;; EOF
