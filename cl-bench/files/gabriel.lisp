;;; gabriel.lisp -- the Gabriel benchmarks, in Common Lisp
;;
;;
;; This file contains the common lisp version of the lisp performance
;; benchmarks from Stanford.  These were translated and tested using
;; Symbolics Common Lisp on a Symbolics 3600.  The benchmarks in this
;; file have not been "tuned" to any particular implementation.
;;
;; The benchmarks have been substantially cleaned up and made truly
;; Common Lisp at CMU by Rob Maclachlan and Skef Wholey.  Timing
;; functions for each benchmark have been added.  Declarations have
;; been added by David B. McDonald.  Declarations should only affect
;; performance on general purpose hardware.  Also, this reduces or
;; eliminates the error checking and may allow the system to be
;; corrupted if incorrect programs are run.
;;
;;
;; Modifications by Eric Marsden:
;;
;; - removed CMUCL-specific (proclaim start-block) stuff
;;
;; - removed some declarations that I considered abusive, such as
;;   (declare fixnum) for iteration variables in DO and DOLIST forms
;;
;; - fix bug in the Boyer benchmark as per Heny Baker's paper "The
;;   Boyer Benchmark Meets Linear Logic"
;;
;; - some renamings to be closer to standard CL style (eg global
;;   variable names with asterisk). Only partially done...



(in-package :cl-bench.gabriel)

;;; BOYER -- Logic programming benchmark, originally written by Bob Boyer.
;;; Fairly CONS intensive.

(defvar unify-subst)
(defvar temp-temp)

(defun add-lemma (term)
  (cond ((and (not (atom term))
	      (eq (car term)
		  (quote equal))
	      (not (atom (cadr term))))
	 (setf (get (car (cadr term)) (quote lemmas))
	       (cons term (get (car (cadr term)) (quote lemmas)))))
	(t (error "ADD-LEMMA did not like term:  ~a" term))))

(defun add-lemma-lst (lst)
  (cond ((null lst)
	 t)
	(t (add-lemma (car lst))
	   (add-lemma-lst (cdr lst)))))

(defun apply-subst (alist term)
  (cond ((atom term)
	 (cond ((setq temp-temp (assoc term alist :test #'eq))
		(cdr temp-temp))
	       (t term)))
	(t (cons (car term)
		 (apply-subst-lst alist (cdr term))))))

(defun apply-subst-lst (alist lst)
  (cond ((null lst)
	 nil)
	(t (cons (apply-subst alist (car lst))
		 (apply-subst-lst alist (cdr lst))))))

(defun falsep (x lst)
  (or (equal x (quote (f)))
      (member x lst :test #'eq)))


(defun one-way-unify (term1 term2)
  (progn (setq unify-subst nil)
	 (one-way-unify1 term1 term2)))

;; this function is buggy -- see "The Boyer Benchmark Meets Linear
;; Logic" by Henry Baker. Corrected version below.

;; (defun one-way-unify1 (term1 term2)
;;   (cond ((atom term2)
;; 	 (cond ((setq temp-temp (assoc term2 unify-subst :test #'eq))
;; 		(equal term1 (cdr temp-temp)))
;; 	       (t (setq unify-subst (cons (cons term2 term1)
;; 					  unify-subst))
;; 		  t)))
;; 	((atom term1)
;; 	 nil)
;; 	((eq (car term1)
;; 	     (car term2))
;; 	 (one-way-unify1-lst (cdr term1)
;; 			     (cdr term2)))
;; 	(t nil)))

(defun one-way-unify1 (term1 term2)                                          ; With bug fixed.
  (cond ((atom term2)
         (cond ((setq temp-temp (assoc term2 unify-subst :test #'eq))
                (equal term1 (cdr temp-temp)))
               ;; this clause added
               ((numberp term2) (equal term1 term2))
               (t (setq unify-subst (cons (cons term2 term1) unify-subst)) t)))
        ((atom term1) nil)
        ((eq (car term1) (car term2)) (one-way-unify1-lst (cdr term1) (cdr term2)))
        (t nil)))

(defun one-way-unify1-lst (lst1 lst2)
  (cond ((null lst1)
	 t)
	((one-way-unify1 (car lst1)
			 (car lst2))
	 (one-way-unify1-lst (cdr lst1)
			     (cdr lst2)))
	(t nil)))

(defun rewrite (term)
  (cond ((atom term)
	 term)
	(t (rewrite-with-lemmas (cons (car term)
				      (rewrite-args (cdr term)))
				(get (car term)
				     (quote lemmas))))))

(defun rewrite-args (lst)
  (cond ((null lst)
	 nil)
	(t (cons (rewrite (car lst))
		 (rewrite-args (cdr lst))))))

(defun rewrite-with-lemmas (term lst)
  (cond ((null lst)
	 term)
	((one-way-unify term (cadr (car lst)))
	 (rewrite (apply-subst unify-subst (caddr (car lst)))))
	(t (rewrite-with-lemmas term (cdr lst)))))

(defun setup-boyer ()
  (add-lemma-lst
    (quote ((equal (compile form)
		   (reverse (codegen (optimize form)
				     (nil))))
	    (equal (eqp x y)
		   (equal (fix x)
			  (fix y)))
	    (equal (greaterp x y)
		   (lessp y x))
	    (equal (lesseqp x y)
		   (not (lessp y x)))
	    (equal (greatereqp x y)
		   (not (lessp x y)))
	    (equal (boolean x)
		   (or (equal x (t))
		       (equal x (f))))
	    (equal (iff x y)
		   (and (implies x y)
			(implies y x)))
	    (equal (even1 x)
		   (if (zerop x)
		       (t)
		       (odd (1- x))))
	    (equal (countps- l pred)
		   (countps-loop l pred (zero)))
	    (equal (fact- i)
		   (fact-loop i 1))
	    (equal (reverse- x)
		   (reverse-loop x (nil)))
	    (equal (divides x y)
		   (zerop (remainder y x)))
	    (equal (assume-true var alist)
		   (cons (cons var (t))
			 alist))
	    (equal (assume-false var alist)
		   (cons (cons var (f))
			 alist))
	    (equal (tautology-checker x)
		   (tautologyp (normalize x)
			       (nil)))
	    (equal (falsify x)
		   (falsify1 (normalize x)
			     (nil)))
	    (equal (prime x)
		   (and (not (zerop x))
			(not (equal x (add1 (zero))))
			(prime1 x (1- x))))
	    (equal (and p q)
		   (if p (if q (t)
			     (f))
		       (f)))
	    (equal (or p q)
		   (if p (t)
		       (if q (t)
			   (f))
		       (f)))
	    (equal (not p)
		   (if p (f)
		       (t)))
	    (equal (implies p q)
		   (if p (if q (t)
			     (f))
		       (t)))
	    (equal (fix x)
		   (if (numberp x)
		       x
		       (zero)))
	    (equal (if (if a b c)
		       d e)
		   (if a (if b d e)
		       (if c d e)))
	    (equal (zerop x)
		   (or (equal x (zero))
		       (not (numberp x))))
	    (equal (plus (plus x y)
			 z)
		   (plus x (plus y z)))
	    (equal (equal (plus a b)
			  (zero))
		   (and (zerop a)
			(zerop b)))
	    (equal (difference x x)
		   (zero))
	    (equal (equal (plus a b)
			  (plus a c))
		   (equal (fix b)
			  (fix c)))
	    (equal (equal (zero)
			  (difference x y))
		   (not (lessp y x)))
	    (equal (equal x (difference x y))
		   (and (numberp x)
			(or (equal x (zero))
			    (zerop y))))
	    (equal (meaning (plus-tree (append x y))
			    a)
		   (plus (meaning (plus-tree x)
				  a)
			 (meaning (plus-tree y)
				  a)))
	    (equal (meaning (plus-tree (plus-fringe x))
			    a)
		   (fix (meaning x a)))
	    (equal (append (append x y)
			   z)
		   (append x (append y z)))
	    (equal (reverse (append a b))
		   (append (reverse b)
			   (reverse a)))
	    (equal (times x (plus y z))
		   (plus (times x y)
			 (times x z)))
	    (equal (times (times x y)
			  z)
		   (times x (times y z)))
	    (equal (equal (times x y)
			  (zero))
		   (or (zerop x)
		       (zerop y)))
	    (equal (exec (append x y)
			 pds envrn)
		   (exec y (exec x pds envrn)
			 envrn))
	    (equal (mc-flatten x y)
		   (append (flatten x)
			   y))
	    (equal (member x (append a b))
		   (or (member x a)
		       (member x b)))
	    (equal (member x (reverse y))
		   (member x y))
	    (equal (length (reverse x))
		   (length x))
	    (equal (member a (intersect b c))
		   (and (member a b)
			(member a c)))
	    (equal (nth (zero)
			i)
		   (zero))
	    (equal (exp i (plus j k))
		   (times (exp i j)
			  (exp i k)))
	    (equal (exp i (times j k))
		   (exp (exp i j)
			k))
	    (equal (reverse-loop x y)
		   (append (reverse x)
			   y))
	    (equal (reverse-loop x (nil))
		   (reverse x))
	    (equal (count-list z (sort-lp x y))
		   (plus (count-list z x)
			 (count-list z y)))
	    (equal (equal (append a b)
			  (append a c))
		   (equal b c))
	    (equal (plus (remainder x y)
			 (times y (quotient x y)))
		   (fix x))
	    (equal (power-eval (big-plus1 l i base)
			       base)
		   (plus (power-eval l base)
			 i))
	    (equal (power-eval (big-plus x y i base)
			       base)
		   (plus i (plus (power-eval x base)
				 (power-eval y base))))
	    (equal (remainder y 1)
		   (zero))
	    (equal (lessp (remainder x y)
			  y)
		   (not (zerop y)))
	    (equal (remainder x x)
		   (zero))
	    (equal (lessp (quotient i j)
			  i)
		   (and (not (zerop i))
			(or (zerop j)
			    (not (equal j 1)))))
	    (equal (lessp (remainder x y)
			  x)
		   (and (not (zerop y))
			(not (zerop x))
			(not (lessp x y))))
	    (equal (power-eval (power-rep i base)
			       base)
		   (fix i))
	    (equal (power-eval (big-plus (power-rep i base)
					 (power-rep j base)
					 (zero)
					 base)
			       base)
		   (plus i j))
	    (equal (gcd x y)
		   (gcd y x))
	    (equal (nth (append a b)
			i)
		   (append (nth a i)
			   (nth b (difference i (length a)))))
	    (equal (difference (plus x y)
			       x)
		   (fix y))
	    (equal (difference (plus y x)
			       x)
		   (fix y))
	    (equal (difference (plus x y)
			       (plus x z))
		   (difference y z))
	    (equal (times x (difference c w))
		   (difference (times c x)
			       (times w x)))
	    (equal (remainder (times x z)
			      z)
		   (zero))
	    (equal (difference (plus b (plus a c))
			       a)
		   (plus b c))
	    (equal (difference (add1 (plus y z))
			       z)
		   (add1 y))
	    (equal (lessp (plus x y)
			  (plus x z))
		   (lessp y z))
	    (equal (lessp (times x z)
			  (times y z))
		   (and (not (zerop z))
			(lessp x y)))
	    (equal (lessp y (plus x y))
		   (not (zerop x)))
	    (equal (gcd (times x z)
			(times y z))
		   (times z (gcd x y)))
	    (equal (value (normalize x)
			  a)
		   (value x a))
	    (equal (equal (flatten x)
			  (cons y (nil)))
		   (and (nlistp x)
			(equal x y)))
	    (equal (listp (gopher x))
		   (listp x))
	    (equal (samefringe x y)
		   (equal (flatten x)
			  (flatten y)))
	    (equal (equal (greatest-factor x y)
			  (zero))
		   (and (or (zerop y)
			    (equal y 1))
			(equal x (zero))))
	    (equal (equal (greatest-factor x y)
			  1)
		   (equal x 1))
	    (equal (numberp (greatest-factor x y))
		   (not (and (or (zerop y)
				 (equal y 1))
			     (not (numberp x)))))
	    (equal (times-list (append x y))
		   (times (times-list x)
			  (times-list y)))
	    (equal (prime-list (append x y))
		   (and (prime-list x)
			(prime-list y)))
	    (equal (equal z (times w z))
		   (and (numberp z)
			(or (equal z (zero))
			    (equal w 1))))
	    (equal (greatereqpr x y)
		   (not (lessp x y)))
	    (equal (equal x (times x y))
		   (or (equal x (zero))
		       (and (numberp x)
			    (equal y 1))))
	    (equal (remainder (times y x)
			      y)
		   (zero))
	    (equal (equal (times a b)
			  1)
		   (and (not (equal a (zero)))
			(not (equal b (zero)))
			(numberp a)
			(numberp b)
			(equal (1- a)
			       (zero))
			(equal (1- b)
			       (zero))))
	    (equal (lessp (length (delete x l))
			  (length l))
		   (member x l))
	    (equal (sort2 (delete x l))
		   (delete x (sort2 l)))
	    (equal (dsort x)
		   (sort2 x))
	    (equal (length (cons x1
				 (cons x2
				       (cons x3 (cons x4
						      (cons x5
							    (cons x6 x7)))))))
		   (plus 6 (length x7)))
	    (equal (difference (add1 (add1 x))
			       2)
		   (fix x))
	    (equal (quotient (plus x (plus x y))
			     2)
		   (plus x (quotient y 2)))
	    (equal (sigma (zero)
			  i)
		   (quotient (times i (add1 i))
			     2))
	    (equal (plus x (add1 y))
		   (if (numberp y)
		       (add1 (plus x y))
		       (add1 x)))
	    (equal (equal (difference x y)
			  (difference z y))
		   (if (lessp x y)
		       (not (lessp y z))
		       (if (lessp z y)
			   (not (lessp y x))
			   (equal (fix x)
				  (fix z)))))
	    (equal (meaning (plus-tree (delete x y))
			    a)
		   (if (member x y)
		       (difference (meaning (plus-tree y)
					    a)
				   (meaning x a))
		       (meaning (plus-tree y)
				a)))
	    (equal (times x (add1 y))
		   (if (numberp y)
		       (plus x (times x y))
		       (fix x)))
	    (equal (nth (nil)
			i)
		   (if (zerop i)
		       (nil)
		       (zero)))
	    (equal (last (append a b))
		   (if (listp b)
		       (last b)
		       (if (listp a)
			   (cons (car (last a))
				 b)
			   b)))
	    (equal (equal (lessp x y)
			  z)
		   (if (lessp x y)
		       (equal t z)
		       (equal f z)))
	    (equal (assignment x (append a b))
		   (if (assignedp x a)
		       (assignment x a)
		       (assignment x b)))
	    (equal (car (gopher x))
		   (if (listp x)
		       (car (flatten x))
		       (zero)))
	    (equal (flatten (cdr (gopher x)))
		   (if (listp x)
		       (cdr (flatten x))
		       (cons (zero)
			     (nil))))
	    (equal (quotient (times y x)
			     y)
		   (if (zerop y)
		       (zero)
		       (fix x)))
	    (equal (get j (set i val mem))
		   (if (eqp j i)
		       val
		       (get j mem)))))))

(defun tautologyp (x true-lst false-lst)
  (cond ((truep x true-lst)
	 t)
	((falsep x false-lst)
	 nil)
	((atom x)
	 nil)
	((eq (car x)
	     (quote if))
	 (cond ((truep (cadr x)
		       true-lst)
		(tautologyp (caddr x)
			    true-lst false-lst))
	       ((falsep (cadr x)
			false-lst)
		(tautologyp (cadddr x)
			    true-lst false-lst))
	       (t (and (tautologyp (caddr x)
				   (cons (cadr x)
					 true-lst)
				   false-lst)
		       (tautologyp (cadddr x)
				   true-lst
				   (cons (cadr x)
					 false-lst))))))
	(t nil)))

(defun tautp (x)
  (tautologyp (rewrite x)
	      nil nil))

(defun boyer ()
  (let (term)
     (setq term
           (apply-subst
            (quote ((x f (plus (plus a b)
                               (plus c (zero))))
                    (y f (times (times a b)
                                (plus c d)))
                    (z f (reverse (append (append a b)
                                          (nil))))
                    (u equal (plus a b)
                       (difference x y))
                    (w lessp (remainder a b)
                       (member a (length b)))))
            (quote (implies (and (implies x y)
                                 (and (implies y z)
                                      (and (implies z u)
                                           (implies u w))))
                            (implies x w)))))
     (tautp term)))

(defun trans-of-implies (n)
  (list (quote implies)
	(trans-of-implies1 n)
	(list (quote implies)
	      0 n)))

(defun trans-of-implies1 (n)
  (declare (fixnum n))
  (cond ((eql n 1)
	 (list (quote implies)
	       0 1))
	(t (list (quote and)
		 (list (quote implies)
		       (1- n)
		       n)
		 (trans-of-implies1 (1- n))))))

(defun truep (x lst)
  (or (equal x (quote (t)))
      (member x lst :test #'eq)))

(eval-when (:load-toplevel :execute)
  (setup-boyer))


;;; BROWSE -- Benchmark to create and browse through an AI-like data base of units.

;;; n is # of symbols
;;; m is maximum amount of stuff on the plist
;;; npats is the number of basic patterns on the unit
;;; ipats is the instantiated copies of the patterns

(defvar browse-rand 21.)

(defmacro char1 (x) `(aref (string ,x) 0))

(defun init-browse (n m npats ipats)
  (declare (fixnum n m npats))
  (let ((ipats (copy-tree ipats)))
    (do ((p ipats (cdr p)))
	((null (cdr p)) (rplacd p ipats)))
    (do ((n n (1- n))
	 (i m (cond ((= (the fixnum i) 0) m)
		    (t (1- i))))
	 (name (gentemp) (gentemp))
	 (a ()))
	((= (the fixnum n) 0) a)
      (push name a)
      (do ((i i (1- i)))
	  ((= (the fixnum i) 0))
	(setf (get name (gensym)) nil))
      (setf (get name 'pattern)
	    (do ((i npats (1- i))
		 (ipats ipats (cdr ipats))
		 (a ()))
		((= (the fixnum i) 0) a)
	      (push (car ipats) a)))
      (do ((j (- m i) (1- j)))
	  ((= (the fixnum j) 0))
	(setf (get name (gensym)) nil)))))

(defun browse-random ()
  (setq browse-rand (mod (the fixnum (* (the fixnum browse-rand) 17.)) 251.)))

(defun randomize (l)
  (do ((a ()))
      ((null l) a)
    (let ((n (mod (browse-random) (length l))))
      (cond ((= n 0)
	     (push (car l) a)
	     (setq l (cdr l)))
	    (t
	     (do ((n n (1- n))
		  (x l (cdr x)))
		 ((= n 1)
		  (push (cadr x) a)
		  (rplacd x (cddr x)))))))))

(defun match (pat dat alist)
  (cond ((null pat)
	 (null dat))
	((null dat) ())
	((or (eq (car pat) '?)
	     (eq (car pat)
		 (car dat)))
	 (match (cdr pat) (cdr dat) alist))
	((eq (car pat) '*)
	 (or (match (cdr pat) dat alist)
	     (match (cdr pat) (cdr dat) alist)
	     (match pat (cdr dat) alist)))
	(t (cond ((atom (car pat))
		  (cond ((eq (char1 (car pat)) #\?)
			 (let ((val (assoc (car pat) alist)))
			   (cond (val (match (cons (cdr val)
						   (cdr pat))
					     dat alist))
				 (t (match (cdr pat)
					   (cdr dat)
					   (cons (cons (car pat)
						       (car dat))
						 alist))))))
			((eq (char1 (car pat)) #\*)
			 (let ((val (assoc (car pat) alist)))
			   (cond (val (match (append (cdr val)
						     (cdr pat))
					     dat alist))
				 (t
				  (do ((l () (nconc l (cons (car d) nil)))
				       (e (cons () dat) (cdr e))
				       (d dat (cdr d)))
				      ((null e) ())
				    (cond ((match (cdr pat) d
						  (cons (cons (car pat) l)
							alist))
					   (return t))))))))))
		 (t (and
		      (not (atom (car dat)))
		      (match (car pat)
			     (car dat) alist)
		      (match (cdr pat)
			     (cdr dat) alist)))))))

(defun browse ()
  (investigate (randomize
		 (init-browse 100. 10. 4. '((a a a b b b b a a a a a b b a a a)
					    (a a b b b b a a
					       (a a)(b b))
					    (a a a b (b a) b a b a))))
	       '((*a ?b *b ?b a *a a *b *a)
		 (*a *b *b *a (*a) (*b))
		 (? ? * (b a) * ? ?))))

(defun investigate (units pats)
  (do ((units units (cdr units)))
      ((null units))
    (do ((pats pats (cdr pats)))
	((null pats))
      (do ((p (get (car units) 'pattern)
	      (cdr p)))
	  ((null p))
	(match (car pats) (car p) ())))))


;;; CTAK -- A version of the TAKeuchi function that uses the CATCH/THROW facility.

(defun ctak-aux (x y z)
  (declare (fixnum x y z))
  (cond ((not (< y x))
	 (throw 'ctak z))
	(t (ctak-aux
	     (catch 'ctak
	       (ctak-aux (the fixnum (1- x))
			 y
			 z))
	     (catch 'ctak
	       (ctak-aux (the fixnum (1- y))
			 z
			 x))
	     (catch 'ctak
	       (ctak-aux (the fixnum (1- z))
			 x
			 y))))))

(defun ctak (x y z)
  (declare (fixnum x y z))
  (catch 'ctak (ctak-aux x y z)))

(defun run-ctak ()
  (ctak 22 12 8))


;;; DDERIV -- The Common Lisp version of a symbolic derivative benchmark, written
;;; by Vaughn Pratt.

;;; This benchmark is a variant of the simple symbolic derivative program
;;; (DERIV). The main change is that it is `table-driven.'  Instead of using a
;;; large COND that branches on the CAR of the expression, this program finds
;;; the code that will take the derivative on the property list of the atom in
;;; the CAR position. So, when the expression is (+ . <rest>), the code
;;; stored under the atom '+ with indicator DERIV will take <rest> and
;;; return the derivative for '+. The way that MacLisp does this is with the
;;; special form: (DEFUN (FOO BAR) ...). This is exactly like DEFUN with an
;;; atomic name in that it expects an argument list and the compiler compiles
;;; code, but the name of the function with that code is stored on the
;;; property list of FOO under the indicator BAR, in this case.

(defun dderiv-aux (a)
  (list '/ (dderiv a) a))

(defun +-dderiv (a)
  (cons '+ (mapcar #'dderiv a)))
(setf (get '+ 'dderiv)  #'+-dderiv)

(defun --dderiv (a)
  (cons '- (mapcar #'dderiv a)))
(setf (get '- 'dderiv) #'--dderiv)

(defun *-dderiv (a)
  (list '* (cons '* a)
	(cons '+ (mapcar #'dderiv-aux a))))
(setf (get '* 'dderiv) #'*-dderiv)

(defun /-dderiv (a)
  (list '-
	(list '/
	      (dderiv (car a))
	      (cadr a))
	(list '/
	      (car a)
	      (list '*
		    (cadr a)
		    (cadr a)
		    (dderiv (cadr a))))))
(setf (get '/ 'dderiv) #'/-dderiv)

(defun dderiv (a)
  (cond
    ((atom a)
     (cond ((eq a 'x) 1) (t 0)))
    (t (let ((dderiv (get (car a) 'dderiv)))
	 (cond (dderiv (funcall (the function dderiv) (cdr a)))
	       (t 'error))))))

(defun dderiv-run ()
  (do ((i 0 (1+ i)))
      ((= i 1000.))
    (dderiv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (dderiv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (dderiv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (dderiv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (dderiv '(+ (* 3 x x) (* a x x) (* b x) 5))))


;;; DERIV -- This is the Common Lisp version of a symbolic derivative benchmark
;;; written by Vaughn Pratt.  It uses a simple subset of Lisp and does a lot of
;;; CONSing.

(defun deriv-aux (a) (list '/ (deriv a) a))

(defun deriv (a)
  (cond
    ((atom a)
     (cond ((eq a 'x) 1) (t 0)))
    ((eq (car a) '+)
     (cons '+ (mapcar #'deriv (cdr a))))
    ((eq (car a) '-)
     (cons '- (mapcar #'deriv
		      (cdr a))))
    ((eq (car a) '*)
     (list '*
	   a
	   (cons '+ (mapcar #'deriv-aux (cdr a)))))
    ((eq (car a) '/)
     (list '-
	   (list '/
		 (deriv (cadr a))
		 (caddr a))
	   (list '/
		 (cadr a)
		 (list '*
		       (caddr a)
		       (caddr a)
		       (deriv (caddr a))))))
    (t 'error)))

(defun deriv-run ()
  (do ((i 0 (1+ i)))
      ((= i 1000.))	;runs it 5000 times
    (deriv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (deriv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (deriv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (deriv '(+ (* 3 x x) (* a x x) (* b x) 5))
    (deriv '(+ (* 3 x x) (* a x x) (* b x) 5))))


;;; DESTRU -- Destructive operation benchmark

(defun destructive (n m)
  (declare (fixnum n m))
  (let ((l (do ((i 10. (1- i))
		(a () (push () a)))
	       ((= i 0) a))))
    (do ((i n (1- i)))
	((= i 0))
      (cond ((null (car l))
	     (do ((l l (cdr l)))
		 ((null l))
	       (or (car l)
		   (rplaca l (cons () ())))
	       (nconc (car l)
		      (do ((j m (1- j))
			   (a () (push () a)))
			  ((= j 0) a)))))
	    (t
	     (do ((l1 l (cdr l1))
		  (l2 (cdr l) (cdr l2)))
		 ((null l2))
	       (rplacd (do ((j (floor (length (car l2)) 2)
			       (1- j))
			    (a (car l2) (cdr a)))
			   ((zerop j) a)
                         (rplaca a i))
		       (let ((n (floor (length (car l1)) 2)))
			 (cond ((= n 0) (rplaca l1 ())
				(car l1))
			       (t
				(do ((j n (1- j))
				     (a (car l1) (cdr a)))
				    ((= j 1)
				     (prog1 (cdr a)
					    (rplacd a ())))
				  (rplaca a i))))))))))))

;; entry point for destructive test
(defun run-destructive ()
  (destructive 600 50))


;;; DIV2 -- Benchmark which divides by 2 using lists of n ()'s.
;;; This file contains a recursive as well as an iterative test.

(defun create-n (n)
  (declare (fixnum n))
  (do ((n n (1- n))
       (a () (push () a)))
      ((zerop n) a)))

(defvar div2-l (create-n 200.))

(defun iterative-div2 (l)
  (do ((l l (cddr l))
       (a () (push (car l) a)))
      ((null l) a)))

(defun recursive-div2 (l)
  (cond ((null l) ())
	(t (cons (car l) (recursive-div2 (cddr l))))))

(defun div2-test-1 (l)
  (do ((i 300 (1- i)))
      ((zerop i))
    (iterative-div2 l)
    (iterative-div2 l)
    (iterative-div2 l)
    (iterative-div2 l)))

(defun div2-test-2 (l)
  (do ((i 300 (1- i)))
      ((zerop i))
    (recursive-div2 l)
    (recursive-div2 l)
    (recursive-div2 l)
    (recursive-div2 l)))

(defun run-div2-test1 ()
  (div2-test-1 div2-l))

(defun run-div2-test2 ()
  (div2-test-2 div2-l))



;;; FFT -- This is an FFT benchmark written by Harry Barrow.  It tests a
;;; variety of floating point operations, including array references.

(defvar re (make-array 1025 :element-type 'single-float :initial-element 0.0))
(defvar im (make-array 1025 :element-type 'single-float :initial-element 0.0))


;areal = real part
;aimag = imaginary part
(defun fft (areal aimag)
  (declare (type (simple-array single-float (1025)) areal aimag))
  (prog ((ar areal)
	 (ai aimag)
	 (i 0)
	 (j 0)
	 (k 0)
	 (m 0)
	 (n 0)
	 (le 0)
	 (le1 0)
	 (ip 0)
	 (nv2 0)
	 (ur 0.0)
	 (ui 0.0)
	 (wr 0.0)
	 (wi 0.0)
	 (tr 0.0)
	 (ti 0.0))
    (declare (fixnum i j k m n le le1 ip nv2)
	     (single-float ur ui wr wi tr ti))
    (setq n (array-dimension ar 0)
	  n (1- n)
	  nv2 (floor n 2)
	  m 0					;compute m = log(n)
	  i 1)
 l1 (cond ((< i n)
	   (setq m (1+ m)
		 i (+ i i))
	   (go l1)))
    (cond ((not (equal n (expt 2 m)))
	   (princ "error ... array size not a power of two.")
	   (read)
	   (return (terpri))))
    (setq j 1					;interchange elements
	  i 1)					;in bit-reversed order
 l3 (cond ((< i j)
	   (setq tr (aref ar j)
		 ti (aref ai j))
	   (setf (aref ar j) (aref ar i))
	   (setf (aref ai j) (aref ai i))
	   (setf (aref ar i) tr)
	   (setf (aref ai i) ti)))
    (setq k nv2)
 l6 (cond ((< k j)
	   (setq j (- j k)
		 k (/ k 2))
	   (go l6)))
    (setq j (+ j k)
	  i (1+ i))
    (cond ((< i n)
	   (go l3)))
    (do ((l 1 (1+ l)))
	((> l m))			;loop thru stages
      (setq le (expt 2 l)
	    le1 (floor le 2)
	    ur 1.0
	    ui 0.0
	    wr (cos (/ 3.14159265 le1))
	    wi (sin (/ 3.14159265 le1)))
      (do ((j 1 (1+ j)))
	  ((> j le1))		;loop thru butterflies
	(do ((i j (+ i le)))
	    ((> i n))		;do a butterfly
	  (setq ip (+ i le1)
		tr (- (* (aref ar ip) ur)
		      (* (aref ai ip) ui))
		ti (+ (* (aref ar ip) ui)
		      (* (aref ai ip) ur)))
	  (setf (aref ar ip) (- (aref ar i) tr))
	  (setf (aref ai ip) (- (aref ai i) ti))
	  (setf (aref ar i) (+ (aref ar i) tr))
	  (setf (aref ai i) (+ (aref ai i) ti))))
	(setq tr (- (* ur wr) (* ui wi))
	      ti (+ (* ur wi) (* ui wr))
	      ur tr
	      ui ti))
    (return t)))

(defun run-fft ()
  (dotimes (i 10)
    (fft re im)))



;;; FPRINT -- Benchmark to print to a file.

(defparameter +fread-temporary-pathname+ "/tmp/fprint.tst")

(defvar *fprint-test-atoms*
  '(abcdef12 cdefgh23 efghij34 ghijkl45 ijklmn56 klmnop67
    mnopqr78 opqrst89 qrstuv90 stuvwx01 uvwxyz12
    wxyzab23 xyzabc34 123456ab 234567bc 345678cd
    456789de 567890ef 678901fg 789012gh 890123hi))

(defun fprint-init-aux (m n atoms)
  (declare (fixnum m n))
  (cond ((zerop m) (pop atoms))
	(t (do ((i n (- i 2))
		(a ()))
	       ((< i 1) a)
	     (push (pop atoms) a)
	     (push (fprint-init-aux (1- m) n atoms) a)))))

(defun fprint-init (m n atoms)
  (let ((atoms (subst () () atoms)))
    (do ((a atoms (cdr a)))
	((null (cdr a)) (rplacd a atoms)))
    (fprint-init-aux m n atoms)))

(defvar *fprint-test-pattern* (fprint-init 6. 6. *fprint-test-atoms*))

(defun fprint/ugly ()
  (with-open-file (sink +fread-temporary-pathname+
                        :direction :output
                        :if-exists :supersede)
    (let ((*print-pretty* nil)
          (*print-circle* nil)
          (*print-escape* nil)
          (*print-level* nil)
          (*print-readably* nil)
          (*print-base* 10))
      (print *fprint-test-pattern* sink))))

(defun fprint/pretty ()
  (with-open-file (sink +fread-temporary-pathname+
                        :direction :output
                        :if-exists :supersede)
    (let ((*print-pretty* t)
          (*print-circle* t)
          (*print-escape* t)
          (*print-level* 100)
          (*print-readably* t)
          (*print-base* 10))
      (pprint *fprint-test-pattern* sink))))



;;; FREAD -- Benchmark to read from a file.
;;; Pronounced "FRED".  Requires the existance of FPRINT.TST which is created
;;; by FPRINT.

(defun fread ()
  (with-open-file (source +fread-temporary-pathname+ :direction :input)
    (read source)))

;;; TPRINT -- Benchmark to print and read to the terminal.

(defvar *tprint-test-atoms*
  '(abc1 cde2 efg3 ghi4 ijk5 klm6 mno7 opq8 qrs9
    stu0 uvw1 wxy2 xyz3 123a 234b 345c 456d
    567d 678e 789f 890g))

(defun tprint-init (m n atoms)
  (let ((atoms (subst () () atoms)))
    (do ((a atoms (cdr a)))
	((null (cdr a)) (rplacd a atoms)))
    (tprint-init-aux m n atoms)))

(defun tprint-init-aux (m n atoms)
  (declare (fixnum m n))
  (cond ((zerop m) (pop atoms))
	(t (do ((i n (- i 2))
		(a ()))
	       ((< i 1) a)
	     (push (pop atoms) a)
	     (push (tprint-init-aux (1- m) n atoms) a)))))

(defvar *tprint-test-pattern* (tprint-init 6. 6. *tprint-test-atoms*))



;; FRPOLY -- Benchmark from Berkeley based on polynomial arithmetic.
;; Originally writen in Franz Lisp by Richard Fateman.

(defvar *frpoly-v*)
(defvar *x*)
(defvar *alpha*)
(defvar *a*)
(defvar *b*)
(defvar *chk)
(defvar *l)
(defvar *p)
(defvar q*)
(defvar u*)
(defvar *var)
(defvar *y*)
(defparameter *frpoly-r* nil)
(defparameter *frpoly-r2* nil)
(defparameter *frpoly-r3* nil)

;; dummy definition -- doesn't get called at runtime
(defmacro pdiffer1 (a b) `(cons ,a ,b))

(defmacro pointergp (x y) `(> (get ,x 'order)(get ,y 'order)))
(defmacro pcoefp (e) `(atom ,e))

(defmacro pzerop (x)
  `(if (numberp ,x) 					; no signp in CL
       (zerop ,x)))
(defmacro pzero () 0)
(defmacro cplus (x y) `(+ ,x ,y))
(defmacro ctimes (x y) `(* ,x ,y))

(defun pcoefadd (e c x)
  (if (pzerop c)
      x
      (cons e (cons c x))))

(defun pcplus (c p)
  (if (pcoefp p)
      (cplus p c)
      (psimp (car p) (pcplus1 c (cdr p)))))

(defun pcplus1 (c x)
  (cond ((null x)
	 (if (pzerop c)
	     nil
	     (cons 0 (cons c nil))))
	((pzerop (car x))
	 (pcoefadd 0 (pplus c (cadr x)) nil))
	(t
	 (cons (car x) (cons (cadr x) (pcplus1 c (cddr x)))))))

(defun pctimes (c p)
  (if (pcoefp p)
      (ctimes c p)
      (psimp (car p) (pctimes1 c (cdr p)))))

(defun pctimes1 (c x)
  (if (null x)
      nil
      (pcoefadd (car x)
		(ptimes c (cadr x))
		(pctimes1 c (cddr x)))))

(defun pplus (x y)
  (cond ((pcoefp x)
	 (pcplus x y))
	((pcoefp y)
	 (pcplus y x))
	((eq (car x) (car y))
	 (psimp (car x) (pplus1 (cdr y) (cdr x))))
	((pointergp (car x) (car y))
	 (psimp (car x) (pcplus1 y (cdr x))))
	(t
	 (psimp (car y) (pcplus1 x (cdr y))))))

(defun pplus1 (x y)
  (cond ((null x) y)
	((null y) x)
	((= (car x) (car y))
	 (pcoefadd (car x)
		   (pplus (cadr x) (cadr y))
		   (pplus1 (cddr x) (cddr y))))
	((> (car x) (car y))
	 (cons (car x) (cons (cadr x) (pplus1 (cddr x) y))))
	(t (cons (car y) (cons (cadr y) (pplus1 x (cddr y)))))))

(defun psimp (var x)
  (cond ((null x) 0)
	((atom x) x)
	((zerop (car x))
	 (cadr x))
	(t
	 (cons var x))))

(defun ptimes (x y)
  (cond ((or (pzerop x) (pzerop y))
	 (pzero))
	((pcoefp x)
	 (pctimes x y))
	((pcoefp y)
	 (pctimes y x))
	((eq (car x) (car y))
	 (psimp (car x) (ptimes1 (cdr x) (cdr y))))
	((pointergp (car x) (car y))
	 (psimp (car x) (pctimes1 y (cdr x))))
	(t
	 (psimp (car y) (pctimes1 x (cdr y))))))

(defun ptimes1 (*x* y)
  (prog (u* *frpoly-v*)
	(setq *frpoly-v* (setq u* (ptimes2 y)))
     a
	(setq *x* (cddr *x*))
	(if (null *x*)
	    (return u*))
	(ptimes3 y)
	(go a)))

(defun ptimes2 (y)
  (if (null y)
      nil
      (pcoefadd (+ (car *x*) (car y))
		(ptimes (cadr *x*) (cadr y))
		(ptimes2 (cddr y)))))

(defun ptimes3 (y)
  (prog (e u c)
     a1	(if (null y)
	    (return nil))
	(setq e (+ (car *x*) (car y))
	      c (ptimes (cadr y) (cadr *x*) ))
	(cond ((pzerop c)
	       (setq y (cddr y))
	       (go a1))
	      ((or (null *frpoly-v*) (> e (car *frpoly-v*)))
	       (setq u* (setq *frpoly-v* (pplus1 u* (list e c))))
	       (setq y (cddr y))
	       (go a1))
	      ((= e (car *frpoly-v*))
	       (setq c (pplus c (cadr *frpoly-v*)))
	       (if (pzerop c) 			; never true, evidently
		   (setq u* (setq *frpoly-v* (pdiffer1 u* (list (car *frpoly-v*) (cadr *frpoly-v*)))))
		   (rplaca (cdr *frpoly-v*) c))
	       (setq y (cddr y))
	       (go a1)))
     a  (cond ((and (cddr *frpoly-v*) (> (caddr *frpoly-v*) e))
	       (setq *frpoly-v* (cddr *frpoly-v*))
	       (go a)))
	(setq u (cdr *frpoly-v*))
     b  (if (or (null (cdr u)) (< (cadr u) e))
	    (rplacd u (cons e (cons c (cdr u)))) (go e))
	(cond ((pzerop (setq c (pplus (caddr u) c)))
	       (rplacd u (cdddr u))
	       (go d))
	      (t
	       (rplaca (cddr u) c)))
     e  (setq u (cddr u))
     d  (setq y (cddr y))
	(if (null y)
	    (return nil))
	(setq e (+ (car *x*) (car y))
	      c (ptimes (cadr y) (cadr *x*)))
     c  (cond ((and (cdr u) (> (cadr u) e))
	       (setq u (cddr u))
	       (go c)))
	(go b)))

(defun pexptsq (p n)
  (do ((n (floor n 2) (floor n 2))
       (s (if (oddp n) p 1)))
      ((zerop n) s)
    (setq p (ptimes p p))
    (and (oddp n) (setq s (ptimes s p)))))

(eval-when (:load-toplevel :execute)
  (setf (get 'x 'order) 1)
  (setf (get 'y 'order) 2)
  (setf (get 'z 'order) 3))


;; r = x+y+z+1
;; r2 = 100000 * r
;; r3 = r with floating point coefficients
(defparameter *frpoly-r* (pplus '(x 1 1 0 1) (pplus '(y 1 1) '(z 1 1))))
(defparameter *frpoly-r2* (ptimes *frpoly-r* 100000))
(defparameter *frpoly-r3* (ptimes *frpoly-r* 1.0))


(defun run-frpoly/fixnum ()
  (dolist (exp '(2 5 10 15))
    (pexptsq *frpoly-r* exp)))

(defun run-frpoly/bignum ()
  (dolist (exp '(2 5 10 15))
    (pexptsq *frpoly-r2* exp)))

(defun run-frpoly/float ()
  (dolist (exp '(2 5 10 15))
    (pexptsq *frpoly-r3* exp)))


;;; PUZZLE -- Forest Baskett's Puzzle benchmark, originally written in
;; Pascal. Solves a combinatorial puzzle by exploring the search
;; space, using arrays to represent state.
;;
;; Comments from Henry Baker: Puzzle solves a 3-dimensional packing
;; problem by attempting to pack pieces of 4 different types into a
;; 5x5x5 cube. The class of such packing problems is closely related
;; to the "bin-packing" and "knapsack" problems of complexity theory,
;; which are known to be NP-complete.
;;
;; The standard Gabriel code for Puzzle solves the problem by
;; "pre-rotating" all of the different puzzle pieces, so that these
;; rotations do not have to be performed during the actual
;; combinatorial search. Thus, each piece "class" has a number of
;; different piece "types" which result from different rotations of
;; the pieces. For example, the 4x2x1 piece has 6 distinct rotations,
;; while the 2x2x2 piece has only 1. The 5x5x5 puzzle cube itself is
;; represented as a section of an 8x8x8 cube of Boolean values, while
;; the various piece types (rotations) are represented as a vector of
;; Boolean values which is in correspondence with the representation
;; of the puzzle itself. By embedding a 5x5x5 cube within an 8x8x8
;; cube, a "border" is created which makes sure that the pieces stay
;; within the 5x5x5 boundaries.
;;
;; After initialization, the standard Puzzle code linearly searches
;; the puzzle representation for the smallest-numbered empty location.
;; It then tries all of the remaining pieces to see if they can be fit
;; into the puzzle in such a way that this empty location will be
;; filled. If a piece can be fitted, then the code performs a
;; depth-first search for the next empty location and the next piece
;; to be fitted. In many instances, the code will find that it has
;; pieces which cannot be fitted, and initiates a backtrack to remove
;; previously fitted pieces.
;; 
;; The standard code investigates 2,005 placements of the 18 pieces.
;; The speed of the standard code is highly dependent upon the
;; ordering of the pieces, which affects the ordering of the search; a
;; different ordering investigated 10 times as many placements, for
;; example. Interestingly enough, of the 2,005 partially-completed
;; puzzles investigated, 1,565 of them are distinct, meaning that
;; there is little hope of speedup from the "memoization" techniques
;; which have been found effective for other puzzles and games
;; [Bird80] [Baker92]. (The standard implementation of Puzzle
;; investigates surprisingly few configurations, making the ordering
;; of the puzzle pieces appear to have been tampered with to produce
;; shorter searches. See [Beeler84] for deeper analysis of the puzzle
;; itself.)
;; 
;; The standard Gabriel code for Puzzle does not have any errors, but
;; it does show evidence of a hasty conversion from a non-Lisp
;; language. It cannot decide, for example, whether to consistently
;; use 0-origin or 1-origin indexing. The standard code prefers to use
;; the more complex do instead of the simpler dotimes, and does not
;; utilize macros like incf and decf. None of these stylistic issues
;; should affect performance, however.
;; 
;; The one obvious stylistic change which could significantly improve
;; performance occurs at the end of the place routine where the puzzle
;; is searched for the smallest-numbered empty location. The Common
;; Lisp position "sequence" function could be used for this purpose,
;; and it could conceivably improve performance due to its presumably
;; high level of optimization.
;;
;; <URL:http://home.pipeline.com/~hbaker1/PuzzleB.html>

(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant +puzzle-size+ 511)
  (defconstant +puzzle-classmax+ 3)
  (defconstant +puzzle-dee+ 8)
  (defconstant +puzzle-typemax+ 12))

(defvar *iii* 0)
(defvar *kount* 0)

(declaim (type fixnum +puzzle-size+ +puzzle-classmax+ +puzzle-typemax+
               *iii* *kount* +puzzle-dee+))

(eval-when (:compile-toplevel :load-toplevel :execute)
  (deftype class-vector () `(simple-vector ,(1+ +puzzle-classmax+)))
  (deftype type-vector () `(simple-vector ,(1+ +puzzle-typemax+)))
  (deftype size-vector () `(simple-vector ,(1+ +puzzle-size+)))
  (deftype p-array () `(simple-array t (,(1+ +puzzle-typemax+) ,(1+ +puzzle-size+)))))

(defvar *piece-count* (make-array (1+ +puzzle-classmax+) :initial-element 0))
(defvar *class* (make-array (1+ +puzzle-typemax+) :initial-element 0))
(defvar *piecemax* (make-array (1+ +puzzle-typemax+) :initial-element 0))
(defvar *puzzle* (make-array (1+ +puzzle-size+)))
(defvar *puzzle-p* (make-array (list (1+ +puzzle-typemax+) (1+ +puzzle-size+))))

(declaim (type type-vector *class* *piecemax*))
(declaim (type class-vector *piece-count*))
(declaim (type size-vector *puzzle*))
(declaim (type p-array *puzzle-p*))

(defun fit (i j)
  (declare (fixnum i j))
  (dotimes (k (svref *piecemax* i))
    (and (aref *puzzle-p* i k)
         (svref *puzzle* (+ j k))
         (return nil)))
  t)

(defun place (i j)
  (declare (fixnum i j))
  (let ((end (svref *piecemax* i)))
    (declare (fixnum end))
    (dotimes (k end)
      (when (aref *puzzle-p* i k)
        (setf (svref *puzzle* (+ j k)) t)))
    (setf (svref *piece-count* (svref *class* i))
	  (the fixnum (- (the fixnum (svref *piece-count* (svref *class* i))) 1)))
    (do ((k j (1+ k)))
	((> k +puzzle-size+)
;	 (terpri)
;	 (princ "Puzzle filled")
	 0)
      (unless (svref *puzzle* k)
        (return k)))))

(defun puzzle-remove (i j)
  (declare (fixnum i j))
  (let ((end (svref *piecemax* i)))
    (declare (fixnum end))
    (do ((k 0 (1+ k)))
	((> k end))
      (when (aref *puzzle-p* i k)
        (setf (svref *puzzle* (+ j k))  nil))
      (setf (svref *piece-count* (svref *class* i))
	    (the fixnum (+ (the fixnum (svref *piece-count* (svref *class* i)))
			   1))))))

(defun trial (j)
  (declare (fixnum j))
  (let ((k 0))
    (declare (fixnum k))
    (do ((i 0 (1+ i)))
	((> i +puzzle-typemax+)
         (incf *kount*)
	 nil)
      (unless (eql (svref *piece-count* (svref *class* i)) 0)
        (when (fit i j)
          (setq k (place i j))
          (cond ((or (trial k)
                     (= k 0))
                 ;; (format t "~%Piece ~4D at ~4D." (+ i 1) (+ k 1))
                 (incf *kount*)
                 (return t))
                (t (puzzle-remove i j))))))))

(defun definepiece (iclass ii jj kk)
  (declare (fixnum ii jj kk))
  (let ((index 0))
    (declare (fixnum index))
    (do ((i 0 (1+ i)))
	((> i ii))
      (do ((j 0 (1+ j)))
	  ((> j jj))
	(do ((k 0 (1+ k)))
	    ((> k kk))
	  (setq index  (+ i (the fixnum
                              (* +puzzle-dee+ (the fixnum
                                                (+ j (the fixnum (* +puzzle-dee+ k))))))))
	  (setf (aref *puzzle-p* *iii* index)  t))))
    (setf (svref *class* *iii*) iclass)
    (setf (svref *piecemax* *iii*) index)
    (unless (= *iii* +puzzle-typemax+)
      (incf *iii*))))

(defun run-puzzle ()
  (do ((m 0 (1+ m)))
      ((> m +puzzle-size+))
    (setf (svref *puzzle* m) t))
  (do ((i 1 (1+ i)))
      ((> i 5))
    (do ((j 1 (1+ j)))
	((> j 5))
      (do ((k 1 (1+ k)))
	  ((> k 5))
	(setf (svref *puzzle*
		     (+ i
			(the fixnum
			     (* +puzzle-dee+ (the fixnum
					 (+ j (the fixnum (* +puzzle-dee+ k))))))))
	      nil))))
  (do ((i 0 (1+ i)))
      ((> i +puzzle-typemax+))
    (do ((m 0 (1+ m)))
	((> m +puzzle-size+))
      (setf (aref *puzzle-p* i m)  nil)))
  (setq *iii* 0)
  (definePiece 0 3 1 0)
  (definePiece 0 1 0 3)
  (definePiece 0 0 3 1)
  (definePiece 0 1 3 0)
  (definePiece 0 3 0 1)
  (definePiece 0 0 1 3)

  (definePiece 1 2 0 0)
  (definePiece 1 0 2 0)
  (definePiece 1 0 0 2)

  (definePiece 2 1 1 0)
  (definePiece 2 1 0 1)
  (definePiece 2 0 1 1)

  (definePiece 3 1 1 1)

  (setf (svref *piece-count* 0) 13.)
  (setf (svref *piece-count* 1) 3)
  (setf (svref *piece-count* 2) 1)
  (setf (svref *piece-count* 3) 1)
  (let ((m (1+ (* +puzzle-dee+ (1+ +puzzle-dee+))))
	(n 0)
	(*kount* 0))
    (declare (fixnum m n))
    (cond ((fit 0 m) (setq n (place 0 m)))
	  (t (format t "~%Error.")))
    (cond ((trial n)
	   ;; (format t "~%Success in ~4D trials." kount)
           )
	  (t (format t "~%Failure.")))))



;;; TAK -- A vanilla version of the TAKeuchi function and one with tail recursion
;;; removed.

(defun tak (x y z)
  (declare (fixnum x y z))
  (if (not (< y x))
      z
      (tak (tak (the fixnum (1- x)) y z)
	   (tak (the fixnum (1- y)) z x)
	   (tak (the fixnum (1- z)) x y))))

(defun run-tak ()
  (tak 18 12 6))


(defun trtak (x y z)
  (declare (fixnum x y z))
  (prog ()
    tak
    (if (not (< y x))
	(return z)
	(let ((a (tak (1- x) y z))
	      (b (tak (1- y) z x)))
	  (setq z (tak (1- z) x y)
		x a
		y b)
	  (go tak)))))

(defun run-trtak ()
   (trtak 18 12 6))



;;; TAKL -- The TAKeuchi function using lists as counters.

(defun listn (n)
  (if (not (= 0 (the fixnum n)))
      (cons n (listn (1- n)))))

(defun shorterp (x y)
  (declare (list x y))
  (and y (or (null x)
	     (shorterp (cdr x)
		       (cdr y)))))

(defun mas (x y z)
  (declare (list x y z))
  (if (not (shorterp y x))
      z
      (mas (mas (cdr x)
		 y z)
	    (mas (cdr y)
		 z x)
	    (mas (cdr z)
		 x y))))

(defun run-takl ()
  (let ((l18 (listn 18.))
        (l12 (listn 12.))
        (l6 (listn 6.)))
    (mas l18 l12 l6)))


;;; STAK -- The TAKeuchi function with special variables instead of parameter
;;; passing.

(defvar *stak-x*)
(defvar *stak-y*)
(defvar *stak-z*)

(defun stak-aux ()
  (if (not (< (the fixnum *stak-y*) (the fixnum *stak-x*)))
      *stak-z*
      (let ((*stak-x* (let ((*stak-x* (the fixnum (1- (the fixnum *stak-x*))))
                            (*stak-y* *stak-y*)
                            (*stak-z* *stak-z*))
                        (stak-aux)))
	    (*stak-y* (let ((*stak-x* (the fixnum (1- (the fixnum *stak-y*))))
                            (*stak-y* *stak-z*)
                            (*stak-z* *stak-x*))
                        (stak-aux)))
	    (*stak-z* (let ((*stak-x* (the fixnum (1- (the fixnum *stak-z*))))
                            (*stak-y* *stak-x*)
                            (*stak-z* *stak-y*))
                        (stak-aux))))
	(stak-aux))))

(defun stak (*stak-x* *stak-y* *stak-z*)
  (stak-aux))

(defun run-stak ()
  (stak 18 12 6))


;;; TRAVERSE --  Benchmark which creates and traverses a tree structure.

(defstruct node
  (parents ())
  (sons ())
  (sn (snb))
  (entry1 ())
  (entry2 ())
  (entry3 ())
  (entry4 ())
  (entry5 ())
  (entry6 ())
  (mark ()))

(defvar *sn* 0)
(defvar *rand* 21.)
(defvar *count* 0)
(defvar *marker* nil)
(defvar *root* )


(declaim (fixnum *sn* *rand*count))

(defun snb ()
  (setq *sn* (the fixnum (1+ (the fixnum *sn*)))))

(defun seed ()
  (setq *rand* 21.))

(defun traverse-random ()
  (setq *rand* (rem (the fixnum (* (the fixnum *rand*) 17.)) 251.)))

(defun traverse-remove (n q)
  (cond ((eq (cdr (car q)) (car q))
	 (prog2 () (caar q) (rplaca q ())))
	((= (the fixnum n) 0)
	 (prog2 () (caar q)
		(do ((p (car q) (cdr p)))
		    ((eq (cdr p) (car q))
		     (rplaca q
			     (rplacd p (cdr (car q))))))))
	(t (do ((n n (the fixnum (1- n)))
		(q (car q) (cdr q))
		(p (cdr (car q)) (cdr p)))
	       ((= (the fixnum n) 0) (prog2 () (car q) (rplacd q p)))))))

(defun traverse-select (n q)
  (do ((n n (the fixnum (1- n)))
       (q (car q) (cdr q)))
      ((= (the fixnum n) 0) (car q))))

(defun add (a q)
  (cond ((null q)
	 `(,(let ((x `(,a)))
	      (rplacd x x) x)))
	((null (car q))
	 (let ((x `(,a)))
	   (rplacd x x)
	   (rplaca q x)))
	(t (rplaca q
		   (rplacd (car q) `(,a .,(cdr (car q))))))))

(defun create-structure (n)
  (declare (fixnum n))
  (let ((a `(,(make-node))))
    (do ((m (the fixnum (1- n)) (the fixnum (1- m)))
	 (p a))
	((= (the fixnum m) 0) (setq a `(,(rplacd p a)))
	 (do ((unused a)
	      (used (add (traverse-remove 0 a) ()))
	      (x) (y))
	     ((null (car unused))
	      (find-root (traverse-select 0 used) n))
	   (setq x (traverse-remove (rem (traverse-random) n) unused))
	   (setq y (traverse-select (rem (traverse-random) n) used))
	   (add x used)
	   (setf (node-sons y) `(,x .,(node-sons y)))
	   (setf (node-parents x) `(,y .,(node-parents x))) ))
      (declare (fixnum m))
      (push (make-node) a))))

(defun find-root (node n)
  (declare (fixnum n))
  (do ((n n (the fixnum (1- n))))
      ((= (the fixnum n) 0) node)
    (cond ((null (node-parents node))
	   (return node))
	  (t (setq node (car (node-parents node)))))))

(defun travers (node mark)
  (cond ((eq (node-mark node) mark) ())
	(t (setf (node-mark node) mark)
	   (setq *count* (the fixnum (1+ *count*)))
	   (setf (node-entry1 node) (not (node-entry1 node)))
	   (setf (node-entry2 node) (not (node-entry2 node)))
	   (setf (node-entry3 node) (not (node-entry3 node)))
	   (setf (node-entry4 node) (not (node-entry4 node)))
	   (setf (node-entry5 node) (not (node-entry5 node)))
	   (setf (node-entry6 node) (not (node-entry6 node)))
	   (do ((sons (node-sons node) (cdr sons)))
	       ((null sons) ())
	     (travers (car sons) mark)))))

(defun traverse (root)
  (let ((*count* 0))
    (travers root (setq *marker* (not *marker*)))
    *count*))

(defun run-traverse ()
  (setq *root* (create-structure 100.))
  (do ((i 50. (the fixnum (1- i))))
      ((= (the fixnum i) 0))
    (traverse *root*)
    (traverse *root*)
    (traverse *root*)
    (traverse *root*)
    (traverse *root*)))



;;; TRIANG -- Board game benchmark.

(defvar board (make-array 16. :initial-element 1))
(setf (aref board 5) 0)

(defvar triang-sequence (make-array 14. :initial-element 0))
(defvar triang-a (make-array 37. :initial-contents '(1 2 4 3 5 6 1 3 6 2 5 4 11. 12. 13. 7 8. 4 4 7 11 8 12
						13. 6 10. 15. 9. 14. 13. 13. 14. 15. 9. 10. 6 6)))
(defvar triang-b (make-array 37. :initial-contents  '(2 4 7 5 8. 9. 3 6 10. 5 9. 8. 12. 13. 14. 8. 9. 5
						 2 4 7 5 8. 9. 3 6 10. 5 9. 8. 12. 13. 14. 8. 9. 5 5)))
(defvar triang-c (make-array 37. :initial-contents  '(4 7 11. 8. 12. 13. 6 10. 15. 9. 14. 13. 13. 14. 15. 9. 10. 6
						 1 2 4 3 5 6 1 3 6 2 5 4 11. 12. 13. 7 8. 4 4)))
(defvar answer)
(defvar final)

(declaim (type simple-vector board triang-sequence triang-a triang-b triang-c))

(defun last-position ()
  (do ((i 1 (1+ i)))
      ((= i 16.) 0)
    (if (= 1 (the fixnum (aref board i)))
	(return i))))

(defun try (i depth)
  (declare (fixnum i depth))
  (cond ((= depth 14)
	 (let ((lp (last-position)))
	   (unless (member lp final)
	     (push lp final)))
	 (push (cdr (coerce (the simple-vector triang-sequence) 'list))
	       answer) t)	; this is a hack to replace LISTARRAY
	((and (= 1 (the fixnum (aref board (aref triang-a i))))
	      (= 1 (the fixnum (aref board (aref triang-b i))))
	      (= 0 (the fixnum (aref board (aref triang-c i)))))
	 (setf (aref board (aref triang-a i)) 0)
	 (setf (aref board (aref triang-b i)) 0)
	 (setf (aref board (aref triang-c i)) 1)
	 (setf (aref triang-sequence depth) i)
	 (do ((j 0 (1+ j))
	      (depth (1+ depth)))
	     ((or (= j 36.)
		  (try j depth)) ()))
         (setf (aref board (aref triang-a i)) 1)
	 (setf (aref board (aref triang-b i)) 1)
	 (setf (aref board (aref triang-c i)) 0) ())))

(defun triangle (i)
  (let ((answer ())
	(final ()))
    (try i 1)))

;; entry point 
(defun run-triangle ()
  (triangle 22))

;; EOF
