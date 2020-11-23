;;;-*-Mode:LISP; Package: CLOS; Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;;

(in-package 'clos)

(defun make-effective-method-function (generic-function form)
  (flet ((name-function (fn) (set-function-name fn 'a-combined-method) fn))
    (if (and (listp form)
	     (eq (car form) 'call-method)
	     (method-p (cadr form))
	     (every #'method-p (caddr form)))
	;;
	;; The effective method is just a call to call-method.  This opens up
	;; the possibility of just using the method function of the method as
	;; as the effective method function.
	;;
	;; But we have to be careful.  If that method function will ask for
	;; the next methods we have to provide them.  We do not look to see
	;; if there are next methods, we look at whether the method function
	;; asks about them.  If it does, we must tell it whether there are
	;; or aren't to prevent the leaky next methods bug.
	;; 
	(let* ((method-function (method-function (cadr form)))
	       (arg-info (gf-arg-info generic-function))
	       (metatypes (arg-info-metatypes arg-info))
	       (applyp (arg-info-applyp arg-info)))
	  (if (not (method-function-needs-next-methods-p method-function))
	      method-function
	      (let ((next-method-functions (mapcar #'method-function (caddr form))))
		(name-function
		  (get-function `(lambda ,(make-dfun-lambda-list metatypes applyp)
				   (let ((*next-methods* .next-method-functions.))
				     ,(make-dfun-call metatypes applyp '.method-function.)))
		    #'default-test-converter	;This could be optimized by making
						;the interface from here to the
						;walker more clear so that the
						;form wouldn't get walked at all.
		    #'(lambda (form)
			(if (memq form '(.next-method-functions. .method-function.))
			    (values form (list form))
			    form))
		    #'(lambda (form)
			(cond ((eq form '.next-method-functions.)
			       (list next-method-functions))
			      ((eq form '.method-function.)
			       (list method-function)))))))))
	;;
	;; We have some sort of `real' effective method.  Go off and get a
	;; compiled function for it.  Most of the real hair here is done by
	;; the GET-FUNCTION mechanism.
	;; 
	(name-function (make-effective-method-function-internal generic-function form)))))

(defvar *global-effective-method-gensyms* ())
(defvar *rebound-effective-method-gensyms*)

(defun get-effective-method-gensym ()
  (or (pop *rebound-effective-method-gensyms*)
      (let ((new (make-symbol "EFFECTIVE-METHOD-GENSYM-")))
	(push new *global-effective-method-gensyms*)
	new)))

(eval-when (load)
  (let ((*rebound-effective-method-gensyms* ()))
    (dotimes (i 10) (get-effective-method-gensym))))

(defun make-effective-method-function-internal (generic-function effective-method)
  (let* ((*rebound-effective-method-gensyms* *global-effective-method-gensyms*)
	 (arg-info (gf-arg-info generic-function))
	 (metatypes (arg-info-metatypes arg-info))
	 (applyp (arg-info-applyp arg-info)))
    (labels ((test-converter (form)
	       (if (and (consp form) (eq (car form) 'call-method))
		   '.call-method.
		   (default-test-converter form)))
	     (code-converter (form)
	       (if (and (consp form) (eq (car form) 'call-method))
		   ;;
		   ;; We have a `call' to CALL-METHOD.  There may or may not be next methods
		   ;; and the two cases are a little different.  It controls how many gensyms
		   ;; we will generate.
		   ;;
		   (let ((gensyms
			   (if (cddr form)
			       (list (get-effective-method-gensym)
				     (get-effective-method-gensym))
			       (list (get-effective-method-gensym)
				     ()))))
		     (values `(let ((*next-methods* ,(cadr gensyms)))
				,(make-dfun-call metatypes applyp (car gensyms)))
			     gensyms))
		   (default-code-converter form)))
	     (constant-converter (form)
	       (if (and (consp form) (eq (car form) 'call-method))
		   (if (cddr form)
		       (list (check-for-make-method (cadr form))
			     (mapcar #'check-for-make-method (caddr form)))
		       (list (check-for-make-method (cadr form))
			     ()))
		   (default-constant-converter form)))
	     (check-for-make-method (effective-method)
	       (cond ((method-p effective-method)
		      (method-function effective-method))
		     ((and (listp effective-method)
			   (eq (car effective-method) 'make-method))
		      (make-effective-method-function generic-function
						      (make-progn (cadr effective-method))))
		     (t
		      (error "Effective-method form is malformed.")))))
      (get-function `(lambda ,(make-dfun-lambda-list metatypes applyp) ,effective-method)
		  #'test-converter
		  #'code-converter
		  #'constant-converter))))



(defvar *invalid-method-error*
	#'(lambda (&rest args)
	    (declare (ignore args))
	    (error
	      "INVALID-METHOD-ERROR was called outside the dynamic scope~%~
               of a method combination function (inside the body of~%~
               DEFINE-METHOD-COMBINATION or a method on the generic~%~
               function COMPUTE-EFFECTIVE-METHOD).")))

(defvar *method-combination-error*
	#'(lambda (&rest args)
	    (declare (ignore args))
	    (error
	      "METHOD-COMBINATION-ERROR was called outside the dynamic scope~%~
               of a method combination function (inside the body of~%~
               DEFINE-METHOD-COMBINATION or a method on the generic~%~
               function COMPUTE-EFFECTIVE-METHOD).")))

;(defmethod compute-effective-method :around        ;issue with magic
;	   ((generic-function generic-function)     ;generic functions
;	    (method-combination method-combination)
;	    applicable-methods)
;  (declare (ignore applicable-methods))
;  (flet ((real-invalid-method-error (method format-string &rest args)
;	   (declare (ignore method))
;	   (apply #'error format-string args))
;	 (real-method-combination-error (format-string &rest args)
;	   (apply #'error format-string args)))
;    (let ((*invalid-method-error* #'real-invalid-method-error)
;	  (*method-combination-error* #'real-method-combination-error))
;      (call-next-method))))

(defun invalid-method-error (&rest args)
  (declare (arglist method format-string &rest format-arguments))
  (apply *invalid-method-error* args))

(defun method-combination-error (&rest args)
  (declare (arglist format-string &rest format-arguments))
  (apply *method-combination-error* args))



;;;
;;; The STANDARD method combination type.  This is coded by hand (rather than
;;; with define-method-combination) for bootstrapping and efficiency reasons.
;;; Note that the definition of the find-method-combination-method appears in
;;; the file defcombin.lisp, this is because EQL methods can't appear in the
;;; bootstrap.
;;;
;;; The defclass for the METHOD-COMBINATION and STANDARD-METHOD-COMBINATION
;;; classes has to appear here for this reason.  This code must conform to
;;; the code in the file defcombin, look there for more details.
;;;

(defclass method-combination () ())

(define-gf-predicate method-combination-p method-combination)

(defclass standard-method-combination
	  (definition-source-mixin method-combination)
     ((type          :reader method-combination-type
	             :initarg :type)
      (documentation :reader method-combination-documentation
		     :initarg :documentation)
      (options       :reader method-combination-options
	             :initarg :options)))

(defmethod print-object ((mc method-combination) stream)
  (printing-random-thing (mc stream)
    (format stream
	    "Method-Combination ~S ~S"
	    (method-combination-type mc)
	    (method-combination-options mc))))

(eval-when (load eval)
  (setq *standard-method-combination*
	(make-instance 'standard-method-combination
		       :type 'standard
		       :documentation "The standard method combination."
		       :options ())))

;This definition appears in defcombin.lisp.
;
;(defmethod find-method-combination ((generic-function generic-function)
;				     (type (eql 'standard))
;				     options)
;  (when options
;    (method-combination-error
;      "The method combination type STANDARD accepts no options."))
;  *standard-method-combination*)

(defun make-call-methods (methods)
  (mapcar #'(lambda (method) `(call-method ,method ())) methods))

(defmethod compute-effective-method ((generic-function generic-function)
				     (combin standard-method-combination)
				     applicable-methods)
  (let ((before ())
	(primary ())
	(after ())
	(around ()))
    (dolist (m applicable-methods)
      (let ((qualifiers (method-qualifiers m)))
	(cond ((member ':before qualifiers)  (push m before))
	      ((member ':after  qualifiers)  (push m after))
	      ((member ':around  qualifiers) (push m around))
	      (t
	       (push m primary)))))
    (setq before  (reverse before)
	  after   (reverse after)
	  primary (reverse primary)
	  around  (reverse around))
    (cond ((null primary)
	   `(error "No primary method for the generic function ~S." ',generic-function))
	  ((and (null before) (null after) (null around))
	   ;;
	   ;; By returning a single call-method `form' here we enable an important
	   ;; implementation-specific optimization.
	   ;; 
	   `(call-method ,(first primary) ,(rest primary)))
	  (t
	   (let ((main-effective-method
		   (if (or before after (rest primary))
		       `(multiple-value-prog1
			  (progn ,@(make-call-methods before)
				 (call-method ,(first primary) ,(rest primary)))
			  ,@(make-call-methods (reverse after)))
		       `(call-method ,(first primary) ()))))
	     (if around
		 `(call-method ,(first around)
			       (,@(rest around) (make-method ,main-effective-method)))
		 main-effective-method))))))

