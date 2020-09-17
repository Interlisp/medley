;;; ratios.lisp -- calculate digits of pi using ratios
;;
;; Time-stamp: <2003-12-29 emarsden>
;;
;;
;; This code was posted to comp.lang.lisp on 2001-12-28 by Vladimir
;; Nesterovsky <vnestr@netvision.net.il>, in message
;; <tcio2ucso5eace5dc7cnbevpc2nqukgofh@4ax.com>. 
;;
;; "I played with some code to calculate more then 16 digits of the 
;; number pi. The simplest series for pi/4 is 1 - 1/3 + 1/5 - 1/7 ... 
;; with Euler transformation applied on its partial sums series 
;; several times (as per SICP).
;; 
;; Of course denominators will grow very fast if we'd just
;; perform calculations in a straightforward manner which would
;; make them very slow, so I tried to "adjust" the ratio to having 
;; no more precision than I need (say 1000 digits), which greatly
;; improved the speed and made it possible to calculate much more
;; digits of pi in the same amount of time."
;;
;;
;; sample calls (timings on PIII/550/Win98):
;;   make 20 euler transforms, pre-generate 41 terms 
;;   (2n+1 by default because each transform shortens the list by two)
;; 	(find-pi 20)     ; 0.3 sec CLISP // 5 sec ACL 
;;   make 20 euler transforms, pre-generate 100 terms
;; 	(find-pi 20 100) ; 0.3 sec CLISP // 6 sec ACL
;;   make 20 euler transforms, pre-generate 200 terms
;; 	(find-pi 20 200) ; 0.3 sec // 7 sec
;;   50 transforms, 101 pre-generated terms
;; 	(find-pi 50)     ; 2 sec // 37 sec (35 compiled) 
;;   1000 pre-generated (working only on 101 last) terms for 120 digits
;; 	(find-pi 50 1000 120)     ; 2 sec // 84 sec (80 compiled)
;;   10,000 pre-generated terms for better precision for 150 digits
;; 	(find-pi 50 10000 150)    ; 4.5 sec // ??
;;   find 1040 digits of the number pi
;; 	(find-pi 120 150000 1039) ; 6.5 min, CLISP // ?? ACL


(in-package :cl-bench.ratios)

(defvar *report-digits* 55)        ; digits to report
(defvar *interim-precision* 95)    ; decimal places of interim precision
(defvar *supress-interim-printout* t)
(defvar *supress-interim-dot-printout* t)

(defun adjust-ratio (r n)
  "adjust ratio's precision to n decimal places"
  (let ((base (expt 10 n)))
    (multiple-value-bind (quot rem)
        (round r)
      (declare (ignore quot))
      (if (< (denominator rem) base)
          r
          (/ (round (* r base)) base)))))

;; a series for pi/4 = 
;;   = 1 - 1/3 + 1/5 - 1/7 + 1/9 - 1/11 + ....
(defun s-pi/4 ( m &optional (len-from-end m))
  "generate up to m partial sums for pi series"
  (do* ((i0 (- m len-from-end))
        (i  0   (+ i 1))
        (s  0   (adjust-ratio (+ s xi) *interim-precision*))
        (j  1   (- j))
        (n  1   (+ n 2))
        (xi 1   (adjust-ratio (/ j n) *interim-precision*))
        (sums ()  (if (> i i0) (cons s sums))))
       ((>= i m)  (reverse sums))
    (unless *supress-interim-dot-printout*
      (if (and (zerop (rem i 1000)) (> i 0))
          (format t ".")))))

;; the Euler transformation of a partial sums series of alternating series
;; A[n] = S[n+1] - (S[n+1]-S[n])^2/(S[n-1]-2S[n]+S[n+1])
;;   returns (cons 'div-zero seq) on 0/0 (to stop further transformations)
(defun euler-trans (seq) 
  "perform a euler transformation on a sequence"
  (let ((a1 (car seq))
        (a2 (cadr seq)))
    (mapcar
      #'(lambda(a3)
         (let ((den (+ a1 (* -2 a2) a3))) 
           (if (zerop den) ; sould I use throw/catch here?
             (return-from euler-trans (cons 'div-zero seq)))
           (let ((r (- a3 (/ (sqr (- a3 a2)) den))))
             (psetq a1 a2
                    a2 a3)
             (adjust-ratio r *interim-precision*))))
      (cddr seq))))

;; main function to call
(defun find-pi (n &optional
                (m (+ (* 2 n) 1))
                (dig *report-digits*)
                (prec (+ dig 40))
                (sup *supress-interim-printout*))
  "(find-pi n [m d p]) to find d digits of the pi value by performing n euler
   transformations on m terms of pi series with p digits of interim precision."
  (let ((*report-digits* dig)
        (*interim-precision* prec)
        (*supress-interim-printout* sup))
    (when (< m (+ (* 2 n) 1))
      (setq m (+ (* 2 n) 1)))
    ;; (format t "~&Generating ~A terms of pi/4 series " m)
    (do ((s   (s-pi/4 m (+ (* 2 n) 1))
                  (euler-trans s))
         (i   1   (+ i 1)))
        ((or (> i n) (eq 'div-zero (car s)))
         ;; (format t "~& After ~A Euler transforms:~%" (- i 1))
         (n-digits (* 4 (car (last s)))
                   *report-digits*))
      (unless *supress-interim-printout*
        (format t "~&~A"
                (last-n-digits
                 (n-digits (* 4 (car (last s)))
                           *report-digits*) 
                 79))))))

(defun n-digits (v n)
  "return v with n digits after decimal point as integer"
  (multiple-value-bind (a b)
      (round (* v (expt 10 n)))
    (declare (ignore b))
    a))

(defun last-n-digits (v n)
  "return last n digits of long integer as integer"
  (multiple-value-bind (a b)
      (floor v (expt 10 n))
    (declare (ignore a))
    b))

(defun sqr(x)
  "find the square of number"
  (* x x))


;; entry point
(defun run-pi-ratios ()
  (assert (eql (find-pi 20 1000 78)
               (find-pi 90 0 78 81))))


#|
(find-pi 20 100) ; 55 digits
31415926535897932384626433832795028841971693993751058210
(find-pi 20 1000 78) ; 78 digits, 1000 terms
3141592653589793238462643383279502884197169399375105820974944592307816406286209
(find-pi 90 0 78 81) ; 181 terms --
       ; like SICP's "tableau" of streams --
       ; all in all slower because it produces bigger interim lists to be able
       ; to run much more transforms (although it exits in the middle on 0/0).
3141592653589793238462643383279502884197169399375105820974944592307816406286209
|#

;; EOF
