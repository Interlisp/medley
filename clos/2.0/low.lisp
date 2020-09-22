
;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;; File converted on 26-Mar-91 10:29:45 from source low
;;;. Original source {dsk}<usr>local>users>welch>lisp>clos>rev4>il-format>low.;4 created 27-Feb-91 17:16:47

;;;. Copyright (c) 1991 by Venue



(in-package "CLOS")

;;; Shadow, Export, Require, Use-package, and Import forms should follow here



;;;
;;;*************************************************************************
;;;Copyright (c) 1991 Venue
;;; This file contains portable versions of low-level functions and macros which are ripe for
;;; implementation specific customization.  None of the code in this file *has* to be customized for
;;; a particular Common Lisp implementation. Moreover, in some implementations it may not make any
;;; sense to customize some of this code. ks. 


(defmacro %svref (vector index)
       `(locally (declare (optimize (speed 3)
                                 (safety 0))
                        (inline svref))
               (svref (the simple-vector ,vector)
                      (the fixnum ,index))))

(defsetf %svref (vector index)
       (new-value)
       `(locally (declare (optimize (speed 3)
                                 (safety 0))
                        (inline svref))
               (setf (svref (the simple-vector ,vector)
                            (the fixnum ,index))
                     ,new-value)))


;;; without-interrupts OK, Common Lisp doesn't have this and for good reason.  But For all of the
;;; Common Lisp's that CLOS runs on today, there is a meaningful way to implement this.  WHAT I MEAN
;;; IS: I want the body to be evaluated in such a way that no other code that is running CLOS can be
;;; run during that evaluation.  I agree that the body won't take *long* to evaluate.  That is to
;;; say that I will only use without interrupts around relatively small computations. INTERRUPTS-ON
;;; should turn interrupts back on if they were on. INTERRUPTS-OFF should turn interrupts back off.
;;; These are only valid inside the body of WITHOUT-INTERRUPTS. OK? 



;;; AKW: IT'S CALLED, BUT NEVER REALLY USED, SO I'VE REPLACED IT WITH THE PROGN. IF WE REALLY NEED
;;; IT, CAN BE TRIVIALLY DONE WITH IL:MONITORS


(defmacro without-interrupts (&body body)
       `(progn ,.body))


;;; Very Low-Level representation of instances with meta-class standard-class. 


(defmacro std-instance-wrapper (x)
       `(%std-instance-wrapper ,x))

(defmacro std-instance-slots (x)
       `(%std-instance-slots ,x))

(defun print-std-instance (instance stream depth)
                                                             ; A temporary definition used
       (declare (ignore depth))
                                                             ; for debugging the bootstrap
       (printing-random-thing (instance stream)
                                                             ; code of CLOS (See high.lisp).
              (format stream "#<std-instance>")))

(defmacro %allocate-instance--class (no-of-slots)
       `(let ((instance (%%allocate-instance--class)))
             (%allocate-instance--class-1 ,no-of-slots instance)
             instance))

(defmacro %allocate-instance--class-1 (no-of-slots instance)
       (once-only (instance)
              `(progn (setf (std-instance-slots ,instance)
                            (%allocate-static-slot-storage--class ,no-of-slots)))))


;;; This is the value that we stick into a slot to tell us that it is unbound. It may seem gross,
;;; but for performance reasons, we make this an interned symbol.  That means that the fast check to
;;; see if a slot is unbound is to say (EQ <val> '..SLOT-UNBOUND..).  That is considerably faster
;;; than looking at the value of a special variable.  Be careful, there are places in the code which
;;; actually use ..slot-unbound.. rather than this variable.  So much for modularity 


(defvar *slot-unbound* '..slot-unbound..)

(defmacro %allocate-static-slot-storage--class (no-of-slots)
       `(make-array ,no-of-slots :initial-element *slot-unbound*))

(defmacro std-instance-class (instance)
       `(wrapper-class (std-instance-wrapper ,instance)))


;; 



;;; FUNCTION-ARGLIST



;; 



;;; [COMMENTED OUT AKW. NEVER CALLED] Given something which is functionp, function-arglist should
;;; return the argument list for it.  CLOS does not count on having this available, but
;;; MAKE-SPECIALIZABLE works much better if it is available.  Versions of function-arglist for each
;;; specific port of clos should be put in the appropriate xxx-low file. This is what it should look
;;; like: 


                                                             ; (defun function-arglist (function)
                                                             ; (<system-dependent-arglist-function>
                                                             ; function)) 



;; (FUNCTIONS CLOS::FUNCTION-PRETTY-ARGLIST) (SETFS CLOS::FUNCTION-PRETTY-ARGLIST) (FUNCTIONS
;; CLOS::SET-FUNCTION-PRETTY-ARGLIST)



;;; set-function-name When given a function should give this function the name <new-name>. Note that
;;; <new-name> is sometimes a list.  Some lisps get the upset in the tummy when they start thinking
;;; about functions which have lists as names.  To deal with that there is set-function-name-intern
;;; which takes a list spec for a function name and turns it into a symbol if need be. When given a
;;; funcallable instance, set-function-name MUST side-effect that FIN to give it the name.  When
;;; given any other kind of function set-function-name is allowed to return new function which is
;;; the 'same' except that it has the name. In all cases, set-function-name must return the new (or
;;; same) function. 


(defun set-function-name #'new-name (declare (notinline set-function-name-1 intern-function-name))
       (set-function-name-1 function (intern-function-name new-name)
              new-name))

(defun set-function-name-1 (fn new-name uninterned-name)
       (cond ((typep fn 'il:compiled-closure)
              (il:\\rplptr (compiled-closure-fnheader fn)
                     4 new-name)
              (when (and (consp uninterned-name)
                         (eq (car uninterned-name)
                             'method))
                  (let ((debug (si::compiled-function-debugging-info fn)))
                       (when debug
                           (setf (cdr debug)
                                 uninterned-name)))))
             (t nil))
       fn)

(defun intern-function-name (name)
       (cond ((symbolp name)
              name)
             ((listp name)
              (intern (let ((*package* *the-clos-package*)
                            (*print-case* :upcase)
                            (*print-gensym* 't))
                           (format nil "~S" name))
                     *the-clos-package*))))


;;; COMPILE-LAMBDA This is like the Common Lisp function COMPILE.  In fact, that is what it ends up
;;; calling.   


(defun compile-lambda (lambda &rest desirability)
       (declare (ignore desirability))
       (compile nil lambda))

(defmacro precompile-random-code-segments (&optional system)
  `(progn
     (precompile-function-generators ,system)
     (precompile-dfun-constructors ,system)))



(defun record-definition (type spec &rest args)
  (declare (ignore type spec args))
  ())

(defun doctor-dfun-for-the-debugger (gf dfun) (declare (ignore gf)) dfun)