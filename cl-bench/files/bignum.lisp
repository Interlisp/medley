;;; bignum.lisp -- bignum operations from Bruno Haible
;;
;; Time-stamp: <2004-01-09 emarsden>
;;

;; code from Bruno Haible <haible@ilog.fr>
;;
;; A. Elementary integer computations:
;;    The tests are run with N = 100, 1000, 10000, 100000 decimal digits.
;;    Precompute *x1* = floor((sqrt(5)+1)/2 * 10^(2N))
;;               *x2* = floor(sqrt(3) * 10^N)
;;               *x3* = 10^N+1
;;    Then time the following operations:
;;    1. Multiplication *x1* * *x2*,
;;    2. Division (with remainder) *x1* / *x2*,
;;    3. integer_sqrt (*x3*),
;;    4. gcd (*x1*, *x2*),
;;
;; B. (from Pari)
;;       u=1;v=1;p=1;q=1;for(k=1..1000){w=u+v;u=v;v=w;p=p*w;q=lcm(q,w);}


(in-package :cl-bench.bignum)

(defvar *x1*)
(defvar *x2*)
(defvar *x3*)
(defvar *y*)
(defvar *z*)


;; this can be 1e-6 on most compilers, but for COMPUTE-PI-DECIMAL on
;; OpenMCL we lose lotsa precision
(defun fuzzy-eql (a b)
  (< (abs (/ (- a b) b)) 1e-4))


(defun elementary-benchmark (N repeat)
  (setq *x1* (floor (+ (isqrt (* 5 (expt 10 (* 4 N)))) (expt 10 (* 2 N))) 2))
  (setq *x2* (isqrt (* 3 (expt 10 (* 2 N)))))
  (setq *x3* (+ (expt 10 N) 1))
  ;; (format t "~&~%N = ~D, Multiplication *x1* * *x2*, divide times by ~D~%" N repeat)
  (dotimes (count 3)
    (dotimes (_ repeat)
      (setq *y* (* *x1* *x2*))))
  ;; (format t "~&~%N = ~D, Division (with remainder) *x1* / *x2*, divide times by ~D~%" N repeat)
  (dotimes (count 3)
    (dotimes (_ repeat)
      (multiple-value-setq (*y* *z*) (floor *x1* *x2*))))
  ;; (format t "~&~%N = ~D, integer_sqrt(*x3*), divide times by ~D~%" N repeat)
  (dotimes (count 3)
    (dotimes (_ repeat)
      (setq *y* (isqrt *x3*))))
  ;; (format t "~&~%N = ~D, gcd(*x1*,*x2*), divide times by ~D~%" N repeat)
  (dotimes (count 3)
    (dotimes (_ repeat)
      (setq *y* (gcd *x1* *x2*)))))

(defun run-elem-100-1000 ()
  (elementary-benchmark 100 1000))

(defun run-elem-1000-100 ()
  (elementary-benchmark 1000 100))

(defun run-elem-10000-1 ()
  (elementary-benchmark 10000 1))


(defun pari-benchmark (N repeat)
  (dotimes (count 3)
    (dotimes (_ repeat)
      (let ((u 1) (v 1) (p 1) (q 1))
        (do ((k 1 (1+ k)))
            ((> k N) (setq *y* p *z* q))
          (let ((w (+ u v)))
            (shiftf u v w)
            (setq p (* p w))
            (setq q (lcm q w))))))))

(defun run-pari-100-10 ()
  (pari-benchmark 100 10))

(defun run-pari-200-5 ()
  (pari-benchmark 200 5))

(defun run-pari-1000-1 ()
  (pari-benchmark 1000 1))




;; calculating pi using ratios
(defun compute-pi-decimal (n)
  (let ((p 0)
        (r nil)
        (dpi 0))
    (dotimes (i n)
      (incf p (/ (- (/ 4 (+ 1 (* 8 i)))
                    (/ 2 (+ 4 (* 8 i)))
                    (/ 1 (+ 5 (* 8 i)))
                    (/ 1 (+ 6 (* 8 i))))
                 (expt 16 i))))
    (dotimes (i n)
      (multiple-value-setq (r p) (truncate p 10))
      (setf dpi (+ (* 10 dpi) r))
      (setf p (* p 10)))
    dpi))

(defun run-pi-decimal/small ()
  (assert (fuzzy-eql pi (/ (compute-pi-decimal 200) (expt 10 198)))))

(defun run-pi-decimal/big ()
  (assert (fuzzy-eql pi (/ (compute-pi-decimal 1000) (expt 10 998)))))


(defun pi-atan (k n)
  (do* ((a 0) (w (* n k)) (k2 (* k k)) (i -1))
       ((= w 0) a)
    (setq w (truncate w k2))
    (incf i 2)
    (incf a (truncate w i))
    (setq w (truncate w k2))
    (incf i 2)
    (decf a (truncate w i))))

(defun calc-pi-atan (digits)
  (let* ((n digits)
         (m (+ n 3))
         (tenpower (expt 10 m)))
    (values (truncate (- (+ (pi-atan 18 (* tenpower 48))
                            (pi-atan 57 (* tenpower 32)))
                         (pi-atan 239 (* tenpower 20)))
                      1000))))

(defun run-pi-atan ()
  (let ((api (calc-pi-atan 1000)))
    (assert (fuzzy-eql pi (/ api (expt 10 1000))))))


;; EOF
