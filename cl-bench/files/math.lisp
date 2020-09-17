;;; math.lisp -- various numerical operations
;;
;; Time-stamp: <2004-01-05 emarsden>
;;
;; some basic mathematical benchmarks


(in-package :cl-bench.math)


(defun factorial (n)
  (declare (type integer n))
  (if (zerop n) 1
      (* n (factorial (1- n)))))

(defun run-factorial ()
  (declare (inline factorial))
  (factorial 500))

(defun fib (n)
  (declare (type integer n))
  (if (< n 2) 1 (+ (fib (- n 1)) (fib (- n 2)))))

(defun run-fib ()
  (declare (inline fib))
  (fib 25))

(defun fib-ratio (n)
  (declare (type integer n))
  (labels ((fr (n)
             (if (= n 1) 1
                 (1+ (/ (fr (- n 1)))))))
    (numerator (fr n))))

(defun run-fib-ratio ()
  (declare (inline fib-ratio))
   (fib-ratio 150))


;; The Ackermann function is the simplest example of a well-defined total
;; function which is computable but not primitive recursive, providing a
;; counterexample to the belief in the early 1900s that every computable
;; function was also primitive recursive (Dtzel 1991). It grows faster
;; than an exponential function, or even a multiple exponential function. 
(defun ackermann (m n)
  (declare (type integer m n))
  (cond
    ((zerop m) (1+ n))
    ((zerop n) (ackermann (1- m) 1))
    (t (ackermann (1- m) (ackermann m (1- n))))))

(defun run-ackermann ()
   (ackermann 3 11))


;; calculate the "level" of a point in the Mandebrot Set, which is the
;; number of iterations taken to escape to "infinity" (points that
;; don't escape are included in the Mandelbrot Set). This version is
;; intended to test performance when programming in naïve math-style. 
(defun mset-level/complex (c)
  (declare (type complex c))
  (loop :for z = #c(0 0) :then (+ (* z z) c)
        :for iter :from 1 :to 300
        :until (> (abs z) 4.0)
        :finally (return iter)))

;; this version is intended to test lower-level performance-oriented
;; coding of the same function; hence the extra declarations and the
;; decoding of the operations on complex numbers.
(defun mset-level/dfloat (c1 c2)
  (declare (type double-float c1 c2))
  (let ((z1 0.0d0)
        (z2 0.0d0)
        (aux 0.0d0))
    (declare (double-float z1 z2 aux))
    (do ((iter 0 (1+ iter)))
        ((or (> (abs (+ (* z1 z1) (* z2 z2))) 4.0)
             (> iter 300))
         iter)
      (setq aux z1
            z1 (+ (* z1 z1) (- (* z2 z2)) c1)
            z2 (+ (* 2.0d0 z2 aux) c2)))))

(defun run-mandelbrot/complex ()
  (let ((n 100)
        (sum 0))
    (dotimes (i n)
      (incf sum (mset-level/complex (complex 0.0001d0 (/ i n 0.25d0)))))))

(defun run-mandelbrot/dfloat ()
  (let ((n 100)
        (sum 0))
    (dotimes (i n)
      (incf sum (mset-level/dfloat 0.0001d0 (/ i n 0.25d0))))))



;; Common Lisp implementation of the multiple recursive random number
;; generator (MRG) of l'Ecuyer. Written by Raymond Toy. 

(eval-when (:compile-toplevel :load-toplevel)
  (defconstant +m1+   4294967087d0)
  (defconstant +m2+   4294944443d0)
  (defconstant +a12+     1403580d0)
  (defconstant +a13n+     810728d0)
  (defconstant +a21+      527612d0)
  (defconstant +a23n+    1370589d0)
  (defconstant +norm+ (/ (1+ +m1+))))

(declaim (inline mrg32k3a-comp-1 mrg32k3a-comp-2))

(defun mrg32k3a-comp-1 (state)
  (declare (type (simple-array double-float (6)) state)
	   (optimize (speed 3) (safety 0)))
  (let ((s10 (aref state 0))
	(s11 (aref state 1)))
    (declare (type (double-float 0d0 4294967086d0) s10 s11))
    (let* ((p1 (- (* s11 +a12+) (* s10 +a13n+)))
	   (k (ftruncate (/ p1 +m1+)))
	   (p1b (- p1 (* k +m1+)))
	   (p1c (if (< p1b 0)
		    (+ p1b +m1+)
		    p1b)))
      (shiftf (aref state 0)
	      (aref state 1)
	      (aref state 2)
	      p1c)
      p1c)))

(defun mrg32k3a-comp-2 (state)
  (declare (type (simple-array double-float (6)) state)
	   (optimize (speed 3) (safety 0)))
  (let ((s20 (aref state 3))
	(s22 (aref state 5)))
    (declare (type (double-float 0d0 4294944442d0) s20 s22))
    (let* ((p2 (- (* s22 +a21+) (* s20 +a23n+)))
	   (k (ftruncate (/ p2 +m2+)))
	   (p2b (- p2 (* k +m2+)))
	   (p2c (if (< p2b 0)
		    (+ p2b +m2+)
		    p2b)))
      (shiftf (aref state 3)
	      (aref state 4)
	      (aref state 5)
	      p2c)
      p2c)))

(declaim (inline mrg32k3a))

(defun mrg32k3a (state)
  (declare (type (simple-array double-float (6)) state)
	   (optimize (speed 3) (safety 0)))
  (let ((p1 (mrg32k3a-comp-1 state))
	(p2 (mrg32k3a-comp-2 state)))
    (if (<= p1 p2)
	(* (+ (- p1 p2) +m1+) +norm+)
	(* (- p1 p2) +norm+))))

(defun gen-mrg32 (n state)
  (declare (fixnum n)
           (optimize (speed 3) (safety 0)))
  (let ((y 0d0))
    (dotimes (k n)
      (declare (fixnum k))
      (setf y (mrg32k3a state)))
    (* 3 y)))

(defun gen-ran (n)
  (declare (fixnum n)
           (optimize (speed 3) (safety 0)))
  (let ((y 0d0))
    (dotimes (k n)
      (declare (fixnum k))
      (setf y (random 1d0)))
    (* 3 y)))

(defun run-mrg32k3a ()
  (declare (inline gen-ran))
  (gen-ran 1000000))

;; EOF
