;;;-*- Mode:LISP; Package:(WALKER LISP 1000); Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;; 
;;; A simple code walker, based IN PART on: (roll the credits)
;;;   Larry Masinter's Masterscope
;;;   Moon's Common Lisp code walker
;;;   Gary Drescher's code walker
;;;   Larry Masinter's simple code walker
;;;   .
;;;   .
;;;   boy, thats fair (I hope).
;;;
;;; For now at least, this code walker really only does what CLOS needs it to
;;; do.  Maybe it will grow up someday.
;;;

;;;
;;; This code walker used to be completely portable.  Now it is just "Real
;;; easy to port".  This change had to happen because the hack that made it
;;; completely portable kept breaking in different releases of different
;;; Common Lisps, and in addition it never worked entirely anyways.  So,
;;; its now easy to port.  To port this walker, all you have to write is one
;;; simple macro and two simple functions.  These macros and functions are
;;; used by the walker to manipluate the macroexpansion environments of
;;; the Common Lisp it is running in.
;;;
;;; The code which implements the macroexpansion environment manipulation
;;; mechanisms is in the first part of the file, the real walker follows it.
;;; 

(in-package 'walker)

;;;
;;; The user entry points are walk-form and nested-walked-form.  In addition,
;;; it is legal for user code to call the variable information functions:
;;; variable-lexical-p, variable-special-p and variable-class.  Some users
;;; will need to call define-walker-template, they will have to figure that
;;; out for themselves.
;;; 
(export '(define-walker-template
	  walk-form
	  nested-walk-form
	  variable-lexical-p
	  variable-special-p
	  variable-globally-special-p
	  *variable-declarations*
	  variable-declaration
	  ))



;;;
;;; On the following pages are implementations of the implementation specific
;;; environment hacking functions for each of the implementations this walker
;;; has been ported to.  If you add a new one, so this walker can run in a new
;;; implementation of Common Lisp, please send the changes back to us so that
;;; others can also use this walker in that implementation of Common Lisp.
;;;
;;; This code just hacks 'macroexpansion environments'.  That is, it is only
;;; concerned with the function binding of symbols in the environment.  The
;;; walker needs to be able to tell if the symbol names a lexical macro or
;;; function, and it needs to be able to build environments which contain
;;; lexical macro or function bindings.  It must be able, when walking a
;;; macrolet, flet or labels form to construct an environment which reflects
;;; the bindings created by that form.  Note that the environment created
;;; does NOT have to be sufficient to evaluate the body, merely to walk its
;;; body.  This means that definitions do not have to be supplied for lexical
;;; functions, only the fact that that function is bound is important.  For
;;; macros, the macroexpansion function must be supplied.
;;;
;;; This code is organized in a way that lets it work in implementations that
;;; stack cons their environments.  That is reflected in the fact that the
;;; only operation that lets a user build a new environment is a with-body
;;; macro which executes its body with the specified symbol bound to the new
;;; environment.  No code in this walker or in CLOS will hold a pointer to
;;; these environments after the body returns.  Other user code is free to do
;;; so in implementations where it works, but that code is not considered
;;; portable.
;;;
;;; There are 3 environment hacking tools.  One macro which is used for
;;; creating new environments, and two functions which are used to access the
;;; bindings of existing environments.
;;;
;;; WITH-AUGMENTED-ENVIRONMENT
;;;
;;; ENVIRONMENT-FUNCTION
;;;
;;; ENVIRONMENT-MACRO
;;; 

(defun unbound-lexical-function (&rest args)
  (declare (ignore args))
  (error "The evaluator was called to evaluate a form in a macroexpansion~%~
          environment constructed by the CLOS portable code walker.  These~%~
          environments are only useful for macroexpansion, they cannot be~%~
          used for evaluation.~%~
          This error should never occur when using CLOS.~%~
          This most likely source of this error is a program which tries to~%~
          to use the CLOS portable code walker to build its own evaluator."))


;;;
;;; In Coral Common Lisp, the macroexpansion environment is just a list
;;; of environment entries.  The cadr of each element specifies the type
;;; of the element.  The only types that interest us are CCL::MACRO and
;;; FUNCTION.  In these cases the element is interpreted as follows.
;;;
;;;   (<function-name> CCL::MACRO . macroexpansion-function)
;;;   
;;;   (<function-name> FUNCTION . <fn>)
;;;   
;;;   When in the compiler, <fn> is a gensym which will be
;;;   a variable which bound at run-time to the function.
;;;   When in the interpreter, <fn> is the actual function.
;;;   
;;;
#+:Coral
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
  `(let ((,new-env (with-augmented-environment-internal ,old-env
							,functions
							,macros)))
     ,@body))

(defun with-augmented-environment-internal (env functions macros)
  (dolist (f functions)
    (push (list* f 'function (gensym)) env))
  (dolist (m macros)
    (push (list* (car m) 'ccl::macro (cadr m)) env))
  env)

(defun environment-function (env fn)
  (let ((entry (assoc fn env :test #'equal)))
    (and entry
	 (eq (cadr entry) 'function)
	 (cddr entry))))

(defun environment-macro (env macro)
  (let ((entry (assoc macro env :test #'equal)))
    (and entry
	 (eq (cadr entry) 'ccl::macro)
	 (cddr entry))))

);#+:Coral


;;;
;;; Franz Common Lisp is a lot like Coral Lisp.  The macroexpansion
;;; environment is just a list of entries.  The cadr of each element
;;; specifies the type of the element.  The types that interest us
;;; are FUNCTION, EXCL::MACRO, and COMPILER::FUNCTION-VALUE.  These
;;; are interpreted as follows:
;;;
;;;   (<function-name> FUNCTION . <a lexical closure>)
;;;
;;;      This happens in the interpreter with lexically
;;;      bound functions.
;;;
;;;   (<function-name> COMPILER::FUNCTION-VALUE . <gensym>)
;;;
;;;      This happens in the compiler.  The gensym represents
;;;      a variable which will be bound at run time to the
;;;      function object.
;;;
;;;   (<function-name> EXCL::MACRO . <a lambda>)
;;;
;;;      In both interpreter and compiler, this is the
;;;      representation used for macro definitions.
;;;   
;;;
#+:ExCL
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
  `(let ((,new-env (with-augmented-environment-internal ,old-env
							,functions
							,macros)))
     ,@body))

(defun with-augmented-environment-internal (env functions macros)
  (dolist (f functions)
    (push (list* f 'function #'unbound-lexical-function) env))
  (dolist (m macros)
    (push (list* (car m) 'excl::macro (cadr m)) env))
  env)

(defun environment-function (env fn)
  (let ((entry (assoc fn env :test #'equal)))
    (and entry
	 (or (eq (cadr entry) 'function)
	     (eq (cadr entry) 'compiler::function-value))
	 (cddr entry))))

(defun environment-macro (env macro)
  (let ((entry (assoc macro env :test #'equal)))
    (and entry
	 (eq (cadr entry) 'excl::macro)
	 (cddr entry))))

);#+:ExCL


#+Lucid
(progn
  
(proclaim '(inline
	    %alphalex-p
	    add-contour-to-env-shape
	    make-function-variable
	    make-sfc-contour
	    sfc-contour-type
	    sfc-contour-elements
	    add-sfc-contour
	    add-function-contour
	    add-macrolet-contour
	    find-variable-in-contour
	    find-alist-element-in-contour
	    find-macrolet-in-contour))

(defun %alphalex-p (object)
  #-Prime
  (eq (cadddr (cddddr object)) 'lucid::%alphalex)
  #+Prime
  (eq (caddr (cddddr object)) 'lucid::%alphalex))

#+Prime 
(defun lucid::augment-lexenv-fvars-dummy (lexical vars)
  (lucid::augment-lexenv-fvars-aux lexical vars '() '() 'flet '()))

(defconstant function-contour 1)
(defconstant macrolet-contour 5)

(defstruct lucid::contour
  type
  elements)

(defun add-contour-to-env-shape (contour-type elements env-shape)
  (cons (make-contour :type contour-type
		      :elements elements)
	env-shape))

(defstruct (variable (:constructor make-variable (name source-type)))
  name
  (identifier nil)
  source-type)

(defconstant function-sfc-contour 1)
(defconstant macrolet-sfc-contour 8)
(defconstant function-variable-type 1)

(defun make-function-variable (name)
  (make-variable name function-variable-type))

(defun make-sfc-contour (type elements)
  (cons type elements))

(defun sfc-contour-type (sfc-contour)
  (car sfc-contour))

(defun sfc-contour-elements (sfc-contour)
  (cdr sfc-contour))

(defun add-sfc-contour (element-list environment type)
  (cons (make-sfc-contour type element-list) environment))

(defun add-function-contour (variable-list environment)
  (add-sfc-contour variable-list environment function-sfc-contour))

(defun add-macrolet-contour (alist environment)
  (add-sfc-contour alist environment macrolet-sfc-contour))

(defun find-variable-in-contour (name contour)
  (dolist (element (sfc-contour-elements contour) nil)
    (when (eq (variable-name element) name)
      (return element))))

(defun find-alist-element-in-contour (name contour)
  (cdr (assoc name (sfc-contour-elements contour))))

(defun find-macrolet-in-contour (name contour)
  (find-alist-element-in-contour name contour))

(defmacro do-sfc-contours ((contour-var environment &optional result)
			   &body body)
  `(dolist (,contour-var ,environment ,result) ,@body))


(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)     
  `(let* ((,new-env (with-augmented-environment-internal ,old-env
							 ,functions
							 ,macros)))
     ,@body))

;;;
;;; with-augmented-environment-internal is where the real work of augmenting
;;; the environment happens.
;;; 
(defun with-augmented-environment-internal (env functions macros)
  (let ((function-names (mapcar #'first functions))
	(macro-names (mapcar #'first macros))
	(macro-functions (mapcar #'second macros)))
    (cond ((or (null env)
	       (contour-p (first env)))
	   (when function-names
	     (setq env (add-contour-to-env-shape function-contour
						 function-names
						 env)))
	   (when macro-names
	     (setq env (add-contour-to-env-shape macrolet-contour
						 (pairlis macro-names
							  macro-functions)
						 env))))
	  ((%alphalex-p env)
	   (when function-names
	     (setq env (lucid::augment-lexenv-fvars-dummy env function-names)))
	   (when macro-names
	     (setq env (lucid::augment-lexenv-mvars env
						    macro-names
						    macro-functions))))
	  (t
	   (when function-names
	     (setq env (add-function-contour
			 (mapcar #'make-function-variable function-names)
			 env)))
	   (when macro-names
	     (setq env (add-macrolet-contour
			 (pairlis macro-names macro-functions)
			 env)))))
    env))
	 

(defun environment-function (env fn)
  (cond ((null env) nil)
	((contour-p (first env))
	 (if (lucid::find-lexical-function fn env)
	     t
	     nil))
	((%alphalex-p env)
	 (if (lucid::lexenv-fvar fn env)
	     t
	     nil))
	(t (do-sfc-contours (contour env nil)
	     (let ((type (sfc-contour-type contour)))
	       (cond ((eql type function-sfc-contour)
		      (when (find-variable-in-contour fn contour)
			(return t)))
		     ((eql type macrolet-sfc-contour)
		      (when (find-macrolet-in-contour fn contour)
			(return nil)))))))))
		      
(defun environment-macro (env macro)
  (cond ((null env) nil)
	((contour-p (first env))
	 (lucid::find-lexical-macro macro env))
	((%alphalex-p env)
	 (lucid::lexenv-mvar macro env))
	(t (do-sfc-contours (contour env nil)
	     (let ((type (sfc-contour-type contour)))
	       (cond ((eql type function-sfc-contour)
		      (when (find-variable-in-contour macro contour)
			(return nil)))
		     ((eql type macrolet-sfc-contour)
		      (let ((fn (find-macrolet-in-contour macro contour)))
			(when fn
			  (return fn))))))))))
  

);#+Lucid



;;;
;;; On the 3600, the documentation for how the environments are represented
;;; is in sys:sys;eval.lisp.  That total information is not repeated here.
;;; The important points are that:
;;;    si:env-variables returns a list of which each element is:
;;;
;;;		(symbol value)
;;;	     or (symbol . locative)
;;;
;;;	The first form is for lexical variables, the second for
;;;	special and instance variables.  In either case CADR of
;;;	the entry is the value and SETF of CADR is used to change
;;;	the value.  Variables are looked up with ASSQ.
;;;
;;;    si:env-functions returns a list of which each element is:
;;;     
;;;		(symbol definition)
;;;
;;;	where definition is anything that could go in a function cell.
;;;	This is used for both local functions and local macros.
;;;
;;; The 3600 stack conses its environments (at least in the interpreter).
;;; This means that code written using this walker and running on the 3600
;;; must not hold on to the environment after the walk-function returns.
;;; No code in this walker or in CLOS does that.
;;;
#+Genera
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
  (let ((funs (make-symbol "FNS"))
	(macs (make-symbol "MACROS"))
	(new  (make-symbol "NEW")))
    `(let ((,funs ,functions)
	   (,macs ,macros)
	   (,new ()))
       (dolist (f ,funs)
	 (push `(,(car f) ,#'unbound-lexical-function) ,new))
       (dolist (m ,macs)
	 (push `(,(car m) (special ,(cadr m))) ,new))
       (let* ((.old-env. ,old-env)
	      (.old-vars. (pop .old-env.))
	      (.old-funs. (pop .old-env.))
	      (.old-blks. (pop .old-env.))
	      (.old-tags. (pop .old-env.))
	      (.old-dcls. (pop .old-env.)))
	 (si:with-interpreter-environment (,new-env
					   .old-env.
					   .old-vars.
					   (append ,new .old-funs.)
					   .old-blks.
					   .old-tags.
					   .old-dcls.)
	   ,@body)))))
  

(defun environment-function (env fn)
  (if (null env)
      (values nil nil)
      (let ((entry (assoc fn (si:env-functions env) :test #'equal)))
	(if (and entry
		 (or (not (listp (cadr entry)))
		     (not (eq (caadr entry) 'special))))
	    (values (cadr entry) t)
	    (environment-function (si:env-parent env) fn)))))

(defun environment-macro (env macro)
  (if (null env)
      (values nil nil)
      (let ((entry (assoc macro (si:env-functions env) :test #'equal)))
	(if (and entry
		 (listp (cadr entry))
		 (eq (caadr entry) 'special))
	    (values (cadadr entry) t)
	    (environment-macro (si:env-parent env) macro)))))

);#+Genera

#+Cloe-Runtime
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
  `(let ((,new-env (with-augmented-environment-internal ,old-env ,functions ,macros)))
     ,@body))

(defun with-augmented-environment-internal (env functions macros)
  functions
  (dolist (m macros)
    (setf env `(,(first m) (compiler::macro . ,(second m)) ,@env)))
  env)

(defun environment-function (env fn)
  nil)

(defun environment-macro (env macro)
  (let ((entry (getf env macro)))
    (if (and (consp entry)
	     (eq (car entry) 'compiler::macro))
	(values (cdr entry) t)
	(values nil nil))))

);#+Cloe-Runtime


;;;
;;; In Xerox Lisp, the compiler and interpreter use different structures for
;;; the environment.  This doesn't cause a serious problem, the parts of the
;;; environments we are concerned with are fairly similar.
;;; 
#+:Xerox
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)     
  `(let* ((,new-env (with-augmented-environment-internal ,old-env
							 ,functions
							 ,macros)))
     ,@body))

;;;
;;; with-augmented-environment-internal is where the real work of augmenting
;;; the environment happens.  Before it gets there, env had better not be NIL
;;; anymore because we have to know what kind of environment we are supposed
;;; to be building up.  This is probably never a real concern in practice.
;;; It better not be because we don't do anything about it.
;;; 
(defun with-augmented-environment-internal (env functions macros)
  (cond
     ((compiler::env-p env)
	(dolist (f functions)
	   (setq env (compiler::copy-env-with-function
		       env f :function)))
	(dolist (m macros)
	   (setq env (compiler::copy-env-with-function
	 	  env (car m) :macro (cadr m)))))
     (t (setq env (if (il:environment-p env)
		    (il:\\copy-environment env)
		    (il:\\make-environment)))
	;; The functions field of the environment is a plist of function names
	;; and conses like (:function . fn) or (:macro . expansion-fn).
	;; Note that we can't smash existing entries in this plist since these
	;; are likely shared with older environments.
	(dolist (f functions)
	  (setf (il:environment-functions env)
		(list* f (cons :function #'unbound-lexical-function)
		       (il:environment-functions env))))
	(dolist (m macros)
	  (setf (il:environment-functions env)
		(list* (car m) (cons :macro (cadr m))
		       (il:environment-functions env))))))
  env)

(defun environment-function (env fn)
  (cond ((compiler::env-p env) (eq (compiler:env-fboundp env fn) :function))
	((il:environment-p env) (eq (getf (il:environment-functions env) fn)
				    :function))
	(t nil)))

(defun environment-macro (env macro) 
  (cond ((compiler::env-p env)
	 (multiple-value-bind (type def)
	     (compiler:env-fboundp env macro)
	   (when (eq type :macro) def)))
	((il:environment-p env)
	 (xcl:destructuring-bind (type . def)
	     (getf (il:environment-functions env) macro)
	   (when (eq type :macro) def)))
	(t nil)))

);#+:Xerox


;;;
;;; In IBUKI Common Lisp, the macroexpansion environment is a three element
;;; list.  The second element describes lexical functions and macros.  The 
;;; function entries in this list have the form 
;;;     (<name> . (FUNCTION . (<function-value> . nil))
;;; The macro entries have the form 
;;;     (<name> . (MACRO . (<macro-value> . nil)).
;;;
;;;
#+(or KCL IBCL)
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
	  `(let ((,new-env (with-augmented-environment-internal ,old-env
								,functions
								,macros)))
	     ,@body))

(defun with-augmented-environment-internal (env functions macros)
  (let ((first (first env))
	(lexicals (second env))
	(third (third env)))
    (dolist (f functions)
      (push `(,(car f) .  (function  . (,#'unbound-lexical-function . nil)))
	    lexicals))
    (dolist (m macros)
      (push `(,(car m)  .  (macro . ( ,(cadr m) . nil))) 
	    lexicals))
    (list first lexicals third)))

(defun environment-function (env fn)
  (when env
	(let ((entry (assoc fn (second env))))
	  (and entry
	       (eq (cadr entry) 'function)
	       (caddr entry)))))

(defun environment-macro (env macro)
  (when env
	(let ((entry (assoc macro (second env))))
	  (and entry
	       (eq (cadr entry) 'macro)
	       (caddr entry)))))
);#+(or KCL IBCL)


;;;   --- TI Explorer --

;;; An environment is a two element list, whose car we can ignore and
;;; whose cadr is list of the local-definitions-frames. Each
;;; local-definitions-frame holds either macros or functions, but not
;;; both.  Each frame is a plist of <name> <def> <name> <def> ...  where
;;; <name> is a locative to the function cell of the symbol that names
;;; the function or macro, and <def> is the new def or NIL if this is function
;;; redefinition or (cons 'ticl:macro <macro-expansion-function>) if this is a macro
;;; redefinition.
;;;
;;; Here's an example.  For the form:
;;; (defun foo ()
;;;   (macrolet ((bar (a b) (list a b))
;;;	         (bar2 (a b) (list a b)))
;;;     (flet ((some-local-fn (c d) (print (list c d)))
;;;	       (another (c d) (print (list c d))))
;;;       (bar (some-local-fn 1 2) 3))))

;;; the environment arg to macroexpand-1 when called on
;;; (bar (some-local-fn 1 2) 3)
;;;is 
;;;(NIL ((#<DTP-LOCATIVE 4710602> NIL
;;;       #<DTP-LOCATIVE 4710671> NIL)
;;;      (#<DTP-LOCATIVE 7346562>
;;;       (TICL:MACRO TICL:NAMED-LAMBDA (BAR (:DESCRIPTIVE-ARGLIST (A B)))
;;;		   (SYS::*MACROARG* &OPTIONAL SYS::*MACROENVIRONMENT*)
;;;		   (BLOCK BAR ....))
;;;       #<DTP-LOCATIVE 4710664>
;;;       (TICL:MACRO TICL:NAMED-LAMBDA (BAR2 (:DESCRIPTIVE-ARGLIST (A B)))
;;;		   (SYS::*MACROARG* &OPTIONAL SYS::*MACROENVIRONMENT*)
;;;		   (BLOCK BAR2 ....))))
#+TI
(progn 

;;; from sys:site;macros.lisp
(eval-when (compile load eval)
  
(DEFMACRO MACRO-DEF? (thing)
  `(AND (CONSP ,thing) (EQ (CAR ,thing) 'TICL::MACRO)))

;; the following macro generates code to check the 'local' environment
;; for a macro definition for THE SYMBOL <name>. Such a definition would
;; be set up only by a MACROLET. If a macro definition for <name> is
;; found, its expander function is returned.

(DEFMACRO FIND-LOCAL-DEFINITION (name local-function-environment)
  `(IF ,local-function-environment
       (LET ((vcell (ticl::LOCF (SYMBOL-FUNCTION ,name))))
	 (DOLIST (frame  ,local-function-environment)
	   ;; <value> is nil or a locative
	   (LET ((value (sys::GET-LOCATION-OR-NIL (ticl::LOCF frame)
						  vcell))) 
	     (When value (RETURN (CAR value))))))
       nil)))

 
;;;Edited by Reed Hastings         13 Jan 88  16:29
(defun environment-macro (env macro)
  "returns what macro-function would, ie. the expansion function"
  ;;some code picked off macroexpand-1
  (let* ((local-definitions (cadr env))
	 (local-def (find-local-definition macro local-definitions)))
    (if (macro-def? local-def)
	(cdr local-def))))

;;;Edited by Reed Hastings         13 Jan 88  16:29
;;;Edited by Reed Hastings         7 Mar 88  19:07
(defun environment-function (env fn)
  (let* ((local-definitions (cadr env)))
    (dolist (frame local-definitions)
      (let ((val (getf frame
		       (ticl::locf (symbol-function fn))
		       :not-found-marker)))
	(cond ((eq val :not-found-marker))
	      ((functionp val) (return t))
	      ((and (listp val)
		    (eq (car val) 'ticl::macro))
	       (return nil))
	      (t
	       (error "we are confused")))))))
	     

;;;Edited by Reed Hastings         13 Jan 88  16:29
;;;Edited by Reed Hastings         7 Mar 88  19:07
(defun with-augmented-environment-internal (env functions macros)
  (let ((local-definitions (cadr env))
	(new-local-fns-frame
	  (mapcan #'(lambda (fn)
		      (list (ticl:locf (symbol-function (car fn)))
			    #'unbound-lexical-function))
		  functions))
	 (new-local-macros-frame
	   (mapcan #'(lambda (m)
		       (list (ticl:locf (symbol-function (car m))) (cons 'ticl::macro (cadr m))))
		   macros)))
    (when new-local-fns-frame 
      (push new-local-fns-frame local-definitions))
    (when new-local-macros-frame
      (push new-local-macros-frame local-definitions))   
    `(,(car env) ,local-definitions)))


;;;Edited by Reed Hastings         7 Mar 88  19:07
(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
  `(let ((,new-env (with-augmented-environment-internal ,old-env
							,functions
							,macros)))
     ,@body))

);#+TI


#+(and dec vax common)
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
  `(let ((,new-env (with-augmented-environment-internal ,old-env
							,functions
							,macros)))
     ,@body))

(defun with-augmented-environment-internal (env functions macros)
  #'(lambda (op &optional (arg nil arg-p))
      (cond ((eq op :macro-function) 
	     (unless arg-p (error "Invalid environment use."))
	     (lookup-macro-function arg env functions macros))
            (arg-p
	     (error "Invalid environment operation: ~S ~S" op arg))
            (t
	     (lookup-macro-function op env functions macros)))))

(defun lookup-macro-function (name env fns macros)
  (let ((m (assoc name macros)))
    (cond (m                (cadr m))
          ((assoc name fns) :function)
          (env              (funcall env name))
          (t                nil))))

(defun environment-macro (env macro)
  (let ((m (and env (funcall env macro))))
    (and (not (eq m :function)) 
         m)))

;;; Nobody calls environment-function.  What would it return, anyway?
);#+(and dec vax common)


;;;
;;; In Golden Common Lisp, the macroexpansion environment is just a list
;;; of environment entries.  Unless the car of the list is :compiler-menv 
;;; it is an interpreted environment.  The cadr of each element specifies 
;;; the type of the element.  The only types that interest us are GCL:MACRO
;;; and FUNCTION.  In these cases the element is interpreted as follows.
;;;
;;; Compiled:
;;;   (<function-name> <gensym> macroexpansion-function)
;;;   (<function-name> <fn>)
;;;   
;;; Interpreted:
;;;   (<function-name> GCL:MACRO macroexpansion-function)
;;;   (<function-name> <fn>)
;;;   
;;;   When in the compiler, <fn> is a gensym which will be
;;;   a variable which bound at run-time to the function.
;;;   When in the interpreter, <fn> is the actual function.
;;;   
;;;
#+gclisp
(progn

(defmacro with-augmented-environment
	  ((new-env old-env &key functions macros) &body body)
  `(let ((,new-env (with-augmented-environment-internal ,old-env
							,functions
							,macros)))
     ,@body))

(defun with-augmented-environment-internal (env functions macros)
  (let ((new-entries nil))
    (dolist (f functions)
      (push (cons (car f) nil) new-entries))
    (dolist (m macros)
      (push (cons (car m)
		  (if (eq :compiler-menv (car env))
		      (if (eq (caadr m) 'lisp::lambda)
			  `(,(gensym) ,(cadr m))
			`(,(gensym) ,@(cadr m)))
		    `(gclisp:MACRO ,@(cadr m))))
	      new-entries))
    (if (eq :compiler-menv (car env))
	`(:compiler-menv ,@new-entries ,@(cdr env))
      (append new-entries env))))

(defun environment-function (env fn)
  (let ((entry (lisp::lexical-function fn env)))
    (and entry 
	 (eq entry 'lisp::lexical-function)
	 fn)))

(defun environment-macro (env macro)
  (let ((entry (assoc macro (if (eq :compiler-menv (first env))
				 (rest env)
			       env))))
    (and entry
	 (consp entry)
	 (symbolp (car entry))			;name
	 (symbolp (cadr entry))			;gcl:macro or gensym
	 (nthcdr 2 entry))))

);#+gclisp



(defmacro with-new-definition-in-environment
	  ((new-env old-env macrolet/flet/labels-form) &body body)
  (let ((functions (make-symbol "Functions"))
	(macros (make-symbol "Macros")))
    `(let ((,functions ())
	   (,macros ()))
       (ecase (car ,macrolet/flet/labels-form)
	 ((flet labels)
	  (dolist (fn (cadr ,macrolet/flet/labels-form))
	    (push fn ,functions)))
	 ((macrolet)
	  (dolist (mac (cadr ,macrolet/flet/labels-form))
	    (push (list (car mac)
			(convert-macro-to-lambda (cadr mac)
						 (cddr mac)
						 (string (car mac))))
		  ,macros))))
       (with-augmented-environment
	      (,new-env ,old-env :functions ,functions :macros ,macros)
	 ,@body))))

#-Genera
(defun convert-macro-to-lambda (llist body &optional (name "Dummy Macro"))
  (let ((gensym (make-symbol name)))
    (eval `(defmacro ,gensym ,llist ,@body))
    (macro-function gensym)))

#+Genera
(defun convert-macro-to-lambda (llist body &optional (name "Dummy Macro"))
  (si:defmacro-1
    'sys:named-lambda 'sys:special (make-symbol name) llist body))





;;;
;;; Now comes the real walker.
;;;
;;; As the walker walks over the code, it communicates information to itself
;;; about the walk.  This information includes the walk function, variable
;;; bindings, declarations in effect etc.  This information is inherently
;;; lexical, so the walker passes it around in the actual environment the
;;; walker passes to macroexpansion functions.  This is what makes the
;;; nested-walk-form facility work properly.
;;;
(defmacro walker-environment-bind ((var env &rest key-args)
				      &body body)
  `(with-augmented-environment
     (,var ,env :macros (walker-environment-bind-1 ,env ,.key-args))
     .,body))

(defvar *key-to-walker-environment* (gensym))

(defun env-lock (env)
  (environment-macro env *key-to-walker-environment*))

(defun walker-environment-bind-1 (env &key (walk-function nil wfnp)
					   (walk-form nil wfop)
					   (declarations nil decp)
					   (lexical-variables nil lexp))
  (let ((lock (environment-macro env *key-to-walker-environment*)))
    (list
      (list *key-to-walker-environment*
	    (list (if wfnp walk-function     (car lock))
		  (if wfop walk-form         (cadr lock))
		  (if decp declarations      (caddr lock))
		  (if lexp lexical-variables (cadddr lock)))))))
		  
(defun env-walk-function (env)
  (car (env-lock env)))

(defun env-walk-form (env)
  (cadr (env-lock env)))

(defun env-declarations (env)
  (caddr (env-lock env)))

(defun env-lexical-variables (env)
  (cadddr (env-lock env)))


(defun note-declaration (declaration env)
  (let ((lock (env-lock env)))
    (setf (caddr lock)
	  (cons declaration (caddr lock)))))

(defun note-lexical-binding (thing env)
  (let ((lock (env-lock env)))
    (setf (cadddr lock)
	  (cons thing (cadddr lock)))))


(defun VARIABLE-LEXICAL-P (var env)
  (member var (env-lexical-variables env)))

(defvar *VARIABLE-DECLARATIONS* '(special))

(defun VARIABLE-DECLARATION (declaration var env)
  (if (not (member declaration *variable-declarations*))
      (error "~S is not a reckognized variable declaration." declaration)
      (let ((id (or (member var (env-lexical-variables env)) var)))
	(dolist (decl (env-declarations env))
	  (when (and (eq (car decl) declaration)
		     (eq (cadr decl) id))
	    (return decl))))))

(defun VARIABLE-SPECIAL-P (var env)
  (or (not (null (variable-declaration 'special var env)))
      (variable-globally-special-p var)))

;;;
;;; VARIABLE-GLOBALLY-SPECIAL-P is used to ask if a variable has been
;;; declared globally special.  Any particular CommonLisp implementation
;;; should customize this function accordingly and send their customization
;;; back.
;;;
;;; The default version of variable-globally-special-p is probably pretty
;;; slow, so it uses *globally-special-variables* as a cache to remember
;;; variables that it has already figured out are globally special.
;;;
;;; This would need to be reworked if an unspecial declaration got added to
;;; Common Lisp.
;;;
;;; Common Lisp nit:
;;;   variable-globally-special-p should be defined in Common Lisp.
;;;
#-(or Genera Cloe-Runtime Lucid Xerox Excl KCL IBCL (and dec vax common) :CMU HP-HPLabs
      GCLisp TI pyramid)
(defvar *globally-special-variables* ())

(defun variable-globally-special-p (symbol)
  #+Genera                      (si:special-variable-p symbol)
  #+Cloe-Runtime		(compiler::specialp symbol)
  #+Lucid                       (lucid::proclaimed-special-p symbol)
  #+TI                          (get symbol 'special)
  #+Xerox                       (il:variable-globally-special-p symbol)
  #+(and dec vax common)        (get symbol 'system::globally-special)
  #+(or KCL IBCL)               (si:specialp symbol)
  #+excl                        (get symbol 'excl::.globally-special.)
  #+:CMU			(or (get symbol 'lisp::globally-special)
				    (get symbol
					 'clc::globally-special-in-compiler))
  #+HP-HPLabs                   (member (get symbol 'impl:vartype)
					'(impl:fluid impl:global)
					:test #'eq)
  #+:GCLISP                     (gclisp::special-p symbol)
  #+pyramid			(or (get symbol 'lisp::globally-special)
				    (get symbol
					 'clc::globally-special-in-compiler))
  #+:CORAL                      (ccl::proclaimed-special-p symbol)
  #-(or Genera Cloe-Runtime Lucid Xerox Excl KCL IBCL (and dec vax common) :CMU HP-HPLabs
	GCLisp TI pyramid :CORAL)
  (or (not (null (member symbol *globally-special-variables* :test #'eq)))
      (when (eval `(flet ((ref () ,symbol))
		     (let ((,symbol '#,(list nil)))
		       (and (boundp ',symbol) (eq ,symbol (ref))))))
	(push symbol *globally-special-variables*)
	t)))


  ;;   
;;;;;; Handling of special forms (the infamous 24).
  ;;
;;;
;;; and I quote...
;;; 
;;;     The set of special forms is purposely kept very small because
;;;     any program analyzing program (read code walker) must have
;;;     special knowledge about every type of special form. Such a
;;;     program needs no special knowledge about macros...
;;;
;;; So all we have to do here is a define a way to store and retrieve
;;; templates which describe how to walk the 24 special forms and we are all
;;; set...
;;;
;;; Well, its a nice concept, and I have to admit to being naive enough that
;;; I believed it for a while, but not everyone takes having only 24 special
;;; forms as seriously as might be nice.  There are (at least) 3 ways to
;;; lose:
;;
;;;   1 - Implementation x implements a Common Lisp special form as a macro
;;;       which expands into a special form which:
;;;         - Is a common lisp special form (not likely)
;;;         - Is not a common lisp special form (on the 3600 IF --> COND).
;;;
;;;     * We can safe ourselves from this case (second subcase really) by
;;;       checking to see if there is a template defined for something
;;;       before we check to see if we we can macroexpand it.
;;;
;;;   2 - Implementation x implements a Common Lisp macro as a special form.
;;;
;;;     * This is a screw, but not so bad, we save ourselves from it by
;;;       defining extra templates for the macros which are *likely* to
;;;       be implemented as special forms.  (DO, DO* ...)
;;;
;;;   3 - Implementation x has a special form which is not on the list of
;;;       Common Lisp special forms.
;;;
;;;     * This is a bad sort of a screw and happens more than I would like
;;;       to think, especially in the implementations which provide more
;;;       than just Common Lisp (3600, Xerox etc.).
;;;       The fix is not terribly staisfactory, but will have to do for
;;;       now.  There is a hook in get walker-template which can get a
;;;       template from the implementation's own walker.  That template
;;;       has to be converted, and so it may be that the right way to do
;;;       this would actually be for that implementation to provide an
;;;       interface to its walker which looks like the interface to this
;;;       walker.
;;;

(eval-when (compile load eval)

(defmacro get-walker-template-internal (x) ;Has to be inside eval-when because
  `(get ,x 'walker-template))		   ;Golden Common Lisp doesn't hack
					   ;compile time definition of macros
					   ;right for setf.

(defmacro define-walker-template
	  (name &optional (template '(nil repeat (eval))))
  `(eval-when (load eval)
     (setf (get-walker-template-internal ',name) ',template)))
)

(defun get-walker-template (x)
  (cond ((symbolp x)
	 (or (get-walker-template-internal x)
	     (get-implementation-dependent-walker-template x)))
	((and (listp x) (eq (car x) 'lambda))
	 '(lambda repeat (eval)))
	(t
	 (error "Can't get template for ~S" x))))

(defun get-implementation-dependent-walker-template (x)
  (declare (ignore x))
  ())


  ;;   
;;;;;; The actual templates
  ;;   

(define-walker-template BLOCK                (NIL NIL REPEAT (EVAL)))
(define-walker-template CATCH                (NIL EVAL REPEAT (EVAL)))
(define-walker-template COMPILER-LET         walk-compiler-let)
(define-walker-template DECLARE              walk-unexpected-declare)
(define-walker-template EVAL-WHEN            (NIL QUOTE REPEAT (EVAL)))
(define-walker-template FLET                 walk-flet)
(define-walker-template FUNCTION             (NIL CALL))
(define-walker-template GO                   (NIL QUOTE))
(define-walker-template IF                   walk-if)
(define-walker-template LABELS               walk-labels)
(define-walker-template LAMBDA               walk-lambda)
(define-walker-template LET                  walk-let)
(define-walker-template LET*                 walk-let*)
(define-walker-template MACROLET             walk-macrolet)
(define-walker-template MULTIPLE-VALUE-CALL  (NIL EVAL REPEAT (EVAL)))
(define-walker-template MULTIPLE-VALUE-PROG1 (NIL RETURN REPEAT (EVAL)))
(define-walker-template MULTIPLE-VALUE-SETQ  (NIL (REPEAT (SET)) EVAL))
(define-walker-template MULTIPLE-VALUE-BIND  walk-multiple-value-bind)
(define-walker-template PROGN                (NIL REPEAT (EVAL)))
(define-walker-template PROGV                (NIL EVAL EVAL REPEAT (EVAL)))
(define-walker-template QUOTE                (NIL QUOTE))
(define-walker-template RETURN-FROM          (NIL QUOTE REPEAT (RETURN)))
(define-walker-template SETQ                 (NIL REPEAT (SET EVAL)))
(define-walker-template TAGBODY              walk-tagbody)
(define-walker-template THE                  (NIL QUOTE EVAL))
(define-walker-template THROW                (NIL EVAL EVAL))
(define-walker-template UNWIND-PROTECT       (NIL RETURN REPEAT (EVAL)))

;;; The new special form.
;(define-walker-template clos::LOAD-TIME-EVAL       (NIL EVAL))

;;;
;;; And the extra templates...
;;;
(define-walker-template DO      walk-do)
(define-walker-template DO*     walk-do*)
(define-walker-template PROG    walk-prog)
(define-walker-template PROG*   walk-prog*)
(define-walker-template COND    (NIL REPEAT ((TEST REPEAT (EVAL)))))

#+Genera
(progn
  (define-walker-template zl::named-lambda walk-named-lambda)
  (define-walker-template SCL:LETF walk-let)
  (define-walker-template SCL:LETF* walk-let*)
  )

#+Lucid
(progn
  (define-walker-template #+LCL3.0 lucid-common-lisp:named-lambda
			  #-LCL3.0 sys:named-lambda walk-named-lambda)
  )

#+(or KCL IBCL)
(progn
  (define-walker-template lambda-block walk-named-lambda);Not really right,
							 ;we don't hack block
						         ;names anyways.
  )

#+TI
(progn
  (define-walker-template TICL::LET-IF walk-let-if)
  )

#+:Coral
(progn
  (define-walker-template ccl:%stack-block walk-let)
  )



(defun WALK-FORM (form
		  &optional environment
			    (walk-function
			      #'(lambda (subform context env)
				  (declare (ignore context env))
				  subform)))
  (walker-environment-bind (new-env environment :walk-function walk-function)
    (walk-form-internal form :eval new-env)))

;;;
;;; nested-walk-form provides an interface that allows nested macros, each
;;; of which must walk their body to just do one walk of the body of the
;;; inner macro.  That inner walk is done with a walk function which is the
;;; composition of the two walk functions.
;;;
;;; This facility works by having the walker annotate the environment that
;;; it passes to macroexpand-1 to know which form is being macroexpanded.
;;; If then the &whole argument to the macroexpansion function is eq to
;;; the env-walk-form of the environment, nested-walk-form can be certain
;;; that there are no intervening layers and that a nested walk is alright.
;;;
;;; There are some semantic problems with this facility.  In particular, if
;;; the outer walk function returns T as its walk-no-more-p value, this will
;;; prevent the inner walk function from getting a chance to walk the subforms
;;; of the form.  This is almost never what you want, since it destroys the
;;; equivalence between this nested-walk-form function and two seperate
;;; walk-forms.
;;;
(defun NESTED-WALK-FORM (whole
			 form
			 &optional environment
				   (walk-function
				     #'(lambda (subform context env)
					 (declare (ignore context env))
					 subform)))
  (if (eq whole (env-walk-form environment))
      (let ((outer-walk-function (env-walk-function environment)))
	(throw whole
	  (walk-form
	    form
	    environment
	    #'(lambda (f c e)
		;; First loop to make sure the inner walk function
		;; has done all it wants to do with this form.
		;; Basically, what we are doing here is providing
		;; the same contract walk-form-internal normally
		;; provides to the inner walk function.
		(let ((inner-result nil)
		      (inner-no-more-p nil)
		      (outer-result nil)
		      (outer-no-more-p nil))
		  (loop
		    (multiple-value-setq (inner-result inner-no-more-p)
					 (funcall walk-function f c e))
		    (cond (inner-no-more-p (return))
			  ((not (eq inner-result f)))
			  ((not (consp inner-result)) (return))
			  ((get-walker-template (car inner-result)) (return))
			  (t
			   (multiple-value-bind (expansion macrop)
			       (walker-environment-bind
				     (new-env e :walk-form inner-result)
				 (macroexpand-1 inner-result new-env))
			     (if macrop
				 (setq inner-result expansion)
				 (return)))))
		    (setq f inner-result))
		  (multiple-value-setq (outer-result outer-no-more-p)
				       (funcall outer-walk-function
						inner-result
						c
						e))
		  (values outer-result
			  (and inner-no-more-p outer-no-more-p)))))))
      (walk-form form environment walk-function)))

;;;
;;; WALK-FORM-INTERNAL is the main driving function for the code walker. It
;;; takes a form and the current context and walks the form calling itself or
;;; the appropriate template recursively.
;;;
;;;   "It is recommended that a program-analyzing-program process a form
;;;    that is a list whose car is a symbol as follows:
;;;
;;;     1. If the program has particular knowledge about the symbol,
;;;        process the form using special-purpose code.  All of the
;;;        standard special forms should fall into this category.
;;;     2. Otherwise, if macro-function is true of the symbol apply
;;;        either macroexpand or macroexpand-1 and start over.
;;;     3. Otherwise, assume it is a function call. "
;;;     

(defun walk-form-internal (form context env
			   &aux newform newnewform
				walk-no-more-p macrop
				fn template)
  ;; First apply the walk-function to perform whatever translation
  ;; the user wants to this form.  If the second value returned
  ;; by walk-function is T then we don't recurse...
  (catch form
    (multiple-value-setq (newform walk-no-more-p)
      (funcall (env-walk-function env) form context env))
    (catch newform
      (cond (walk-no-more-p newform)
	    ((not (eq form newform))
	     (walk-form-internal newform context env))
	    ((not (consp newform)) newform)
	    ((setq template (get-walker-template (setq fn (car newform))))
	     (if (symbolp template)
		 (funcall template newform context env)
		 (walk-template newform template context env)))
	    (t
	     (multiple-value-setq (newnewform macrop)
	       (walker-environment-bind (new-env env :walk-form newform)
		 (macroexpand-1 newform new-env)))
	     (cond (macrop (walk-form-internal newnewform context env))
		   ((and (symbolp fn)
			 (not (fboundp fn))
			 (special-form-p fn))
		    (error
		      "~S is a special form, not defined in the CommonLisp.~%~
                       manual This code walker doesn't know how to walk it.~%~
                       Define a template for this special form and try again."
		      fn))
		   (t
		    ;; Otherwise, walk the form as if its just a standard 
		    ;; functioncall using a template for standard function
		    ;; call.
		    (walk-template
		      newnewform '(call repeat (eval)) context env))))))))

(defun walk-template (form template context env)
  (if (atom template)
      (ecase template
        ((EVAL FUNCTION TEST EFFECT RETURN)
         (walk-form-internal form :EVAL env))
        ((QUOTE NIL) form)
        (SET
          (walk-form-internal form :SET env))
        ((LAMBDA CALL)
	 (cond ((symbolp form) form)
	       #+Lispm
	       ((sys:validate-function-spec form) form)
	       (t (walk-form-internal form context env)))))
      (case (car template)
        (REPEAT
          (walk-template-handle-repeat form
                                       (cdr template)
				       ;; For the case where nothing happens
				       ;; after the repeat optimize out the
				       ;; call to length.
				       (if (null (cddr template))
					   ()
					   (nthcdr (- (length form)
						      (length
							(cddr template)))
						   form))
                                       context
				       env))
        (IF
	  (walk-template form
			 (if (if (listp (cadr template))
				 (eval (cadr template))
				 (funcall (cadr template) form))
			     (caddr template)
			     (cadddr template))
			 context
			 env))
        (REMOTE
          (walk-template form (cadr template) context env))
        (otherwise
          (cond ((atom form) form)
                (t (recons form
                           (walk-template
			     (car form) (car template) context env)
                           (walk-template
			     (cdr form) (cdr template) context env))))))))

(defun walk-template-handle-repeat (form template stop-form context env)
  (if (eq form stop-form)
      (walk-template form (cdr template) context env)
      (walk-template-handle-repeat-1 form
				     template
				     (car template)
				     stop-form
				     context
				     env)))

(defun walk-template-handle-repeat-1 (form template repeat-template
					   stop-form context env)
  (cond ((null form) ())
        ((eq form stop-form)
         (if (null repeat-template)
             (walk-template stop-form (cdr template) context env)       
             (error "While handling repeat:
                     ~%~Ran into stop while still in repeat template.")))
        ((null repeat-template)
         (walk-template-handle-repeat-1
	   form template (car template) stop-form context env))
        (t
         (recons form
                 (walk-template (car form) (car repeat-template) context env)
                 (walk-template-handle-repeat-1 (cdr form)
						template
						(cdr repeat-template)
						stop-form
						context
						env)))))

(defun walk-repeat-eval (form env)
  (and form
       (recons form
	       (walk-form-internal (car form) :eval env)
	       (walk-repeat-eval (cdr form) env))))

(defun recons (x car cdr)
  (if (or (not (eq (car x) car))
          (not (eq (cdr x) cdr)))
      (cons car cdr)
      x))

(defun relist (x &rest args)
  (relist-internal x args nil))

(defun relist* (x &rest args)
  (relist-internal x args 't))

(defun relist-internal (x args *p)
  (if (null (cdr args))
      (if *p (car args) (list (car args)))
      (recons x
	      (car args)
	      (relist-internal (cdr x) (cdr args) *p))))


  ;;   
;;;;;; Special walkers
  ;;

(defun walk-declarations (body fn env
			       &optional doc-string-p declarations old-body
			       &aux (form (car body)) macrop new-form)
  (cond ((and (stringp form)			;might be a doc string
              (cdr body)			;isn't the returned value
              (null doc-string-p)		;no doc string yet
              (null declarations))		;no declarations yet
         (recons body
                 form
                 (walk-declarations (cdr body) fn env t)))
        ((and (listp form) (eq (car form) 'declare))
         ;; Got ourselves a real live declaration.  Record it, look for more.
         (dolist (declaration (cdr form))
	   (let ((type (car declaration))
		 (name (cadr declaration))
		 (args (cddr declaration)))
	     (if (member type *variable-declarations*)
		 (note-declaration `(,type
				     ,(or (variable-lexical-p name env) name)
				     ,.args)
				   env)
		 (note-declaration declaration env))
	     (push declaration declarations)))
         (recons body
                 form
                 (walk-declarations
		   (cdr body) fn env doc-string-p declarations)))
        ((and form
	      (listp form)
	      (null (get-walker-template (car form)))
	      (progn
		(multiple-value-setq (new-form macrop)
				     (macroexpand-1 form env))
		macrop))
	 ;; This form was a call to a macro.  Maybe it expanded
	 ;; into a declare?  Recurse to find out.
	 (walk-declarations (recons body new-form (cdr body))
			    fn env doc-string-p declarations
			    (or old-body body)))
	(t
	 ;; Now that we have walked and recorded the declarations,
	 ;; call the function our caller provided to expand the body.
	 ;; We call that function rather than passing the real-body
	 ;; back, because we are RECONSING up the new body.
	 (funcall fn (or old-body body) env))))


(defun walk-unexpected-declare (form context env)
  (declare (ignore context env))
  (warn "Encountered declare ~S in a place where a declare was not expected."
	form)
  form)

(defun walk-arglist (arglist context env &optional (destructuringp nil)
					 &aux arg)
  (cond ((null arglist) ())
        ((symbolp (setq arg (car arglist)))
         (or (member arg lambda-list-keywords)
             (note-lexical-binding arg env))
         (recons arglist
                 arg
                 (walk-arglist (cdr arglist)
                               context
			       env
                               (and destructuringp
				    (not (member arg
						 lambda-list-keywords))))))
        ((consp arg)
         (prog1 (if destructuringp
                    (walk-arglist arg context env destructuringp)
                    (recons arglist
                            (relist* arg
                                     (car arg)
                                     (walk-form-internal (cadr arg) :eval env)
                                     (cddr arg))
                            (walk-arglist (cdr arglist) context env nil)))
                (if (symbolp (car arg))
                    (note-lexical-binding (car arg) env)
                    (note-lexical-binding (cadar arg) env))
                (or (null (cddr arg))
                    (not (symbolp (caddr arg)))
                    (note-lexical-binding (caddr arg) env))))
          (t
	   (error "Can't understand something in the arglist ~S" arglist))))

(defun walk-let (form context env)
  (walk-let/let* form context env nil))

(defun walk-let* (form context env)
  (walk-let/let* form context env t))

(defun walk-prog (form context env)
  (walk-prog/prog* form context env nil))

(defun walk-prog* (form context env)
  (walk-prog/prog* form context env t))

(defun walk-do (form context env)
  (walk-do/do* form context env nil))

(defun walk-do* (form context env)
  (walk-do/do* form context env t))

(defun walk-let/let* (form context old-env sequentialp)
  (walker-environment-bind (new-env old-env)
    (let* ((let/let* (car form))
	   (bindings (cadr form))
	   (body (cddr form))
	   (walked-bindings 
	     (walk-bindings-1 bindings
			      old-env
			      new-env
			      context
			      sequentialp))
	   (walked-body
	     (walk-declarations body #'walk-repeat-eval new-env)))
      (relist*
	form let/let* walked-bindings walked-body))))

(defun walk-prog/prog* (form context old-env sequentialp)
  (walker-environment-bind (new-env old-env)
    (let* ((possible-block-name (second form))
	   (blocked-prog (and (symbolp possible-block-name)
			      (not (eq possible-block-name 'nil)))))
      (multiple-value-bind (let/let* block-name bindings body)
	  (if blocked-prog
	      (values (car form) (cadr form) (caddr form) (cdddr form))
	      (values (car form) nil	     (cadr  form) (cddr  form)))
	(let* ((walked-bindings 
		 (walk-bindings-1 bindings
				  old-env
				  new-env
				  context
				  sequentialp))
	       (walked-body
		 (walk-declarations 
		   body
		   #'(lambda (real-body real-env)
		       (walk-tagbody-1 real-body context real-env))
		   new-env)))
	  (if block-name
	      (relist*
		form let/let* block-name walked-bindings walked-body)
	      (relist*
		form let/let* walked-bindings walked-body)))))))

(defun walk-do/do* (form context old-env sequentialp)
  (walker-environment-bind (new-env old-env)
    (let* ((do/do* (car form))
	   (bindings (cadr form))
	   (end-test (caddr form))
	   (body (cdddr form))
	   (walked-bindings (walk-bindings-1 bindings
					     old-env
					     new-env
					     context
					     sequentialp))
	   (walked-body
	     (walk-declarations body #'walk-repeat-eval new-env)))
      (relist* form
	       do/do*
	       (walk-bindings-2 bindings walked-bindings context new-env)
	       (walk-template end-test '(test repeat (eval)) context new-env)
	       walked-body))))

(defun walk-let-if (form context env)
  (let ((test (cadr form))
	(bindings (caddr form))
	(body (cdddr form)))
    (walk-form-internal
      `(let ()
	 (declare (special ,@(mapcar #'(lambda (x) (if (listp x) (car x) x))
				     bindings)))
	 (flet ((.let-if-dummy. () ,@body))
	   (if ,test
	       (let ,bindings (.let-if-dummy.))
	       (.let-if-dummy.))))
      context
      env)))

(defun walk-multiple-value-bind (form context old-env)
  (walker-environment-bind (new-env old-env)
    (let* ((mvb (car form))
	   (bindings (cadr form))
	   (mv-form (walk-template (caddr form) 'eval context old-env))
	   (body (cdddr form))
	   walked-bindings
	   (walked-body
	     (walk-declarations 
	       body
	       #'(lambda (real-body real-env)
		   (setq walked-bindings
			 (walk-bindings-1 bindings
					  old-env
					  new-env
					  context
					  nil))
		   (walk-repeat-eval real-body real-env))
	       new-env)))
      (relist* form mvb walked-bindings mv-form walked-body))))

(defun walk-bindings-1 (bindings old-env new-env context sequentialp)
  (and bindings
       (let ((binding (car bindings)))
         (recons bindings
                 (if (symbolp binding)
                     (prog1 binding
                            (note-lexical-binding binding new-env))
                     (prog1 (relist* binding
				     (car binding)
				     (walk-form-internal (cadr binding)
							 context
							 (if sequentialp
							     new-env
							     old-env))
				     (cddr binding))	;save cddr for DO/DO*
						        ;it is the next value
						        ;form. Don't walk it
						        ;now though.
                            (note-lexical-binding (car binding) new-env)))
                 (walk-bindings-1 (cdr bindings)
				  old-env
				  new-env
				  context
				  sequentialp)))))

(defun walk-bindings-2 (bindings walked-bindings context env)
  (and bindings
       (let ((binding (car bindings))
             (walked-binding (car walked-bindings)))
         (recons bindings
		 (if (symbolp binding)
		     binding
		     (relist* binding
			      (car walked-binding)
			      (cadr walked-binding)
			      (walk-template (cddr binding)
					     '(eval)
					     context
					     env)))		 
                 (walk-bindings-2 (cdr bindings)
				  (cdr walked-bindings)
				  context
				  env)))))

(defun walk-lambda (form context old-env)
  (walker-environment-bind (new-env old-env)
    (let* ((arglist (cadr form))
           (body (cddr form))
           (walked-arglist (walk-arglist arglist context new-env))
           (walked-body
             (walk-declarations body #'walk-repeat-eval new-env)))
      (relist* form
               (car form)
	       walked-arglist
               walked-body))))

(defun walk-named-lambda (form context old-env)
  (walker-environment-bind (new-env old-env)
    (let* ((name (cadr form))
	   (arglist (caddr form))
           (body (cdddr form))
           (walked-arglist (walk-arglist arglist context new-env))
           (walked-body
             (walk-declarations body #'walk-repeat-eval new-env)))
      (relist* form
               (car form)
	       name
	       walked-arglist
               walked-body))))  

(defun walk-tagbody (form context env)
  (recons form (car form) (walk-tagbody-1 (cdr form) context env)))

(defun walk-tagbody-1 (form context env)
  (and form
       (recons form
               (walk-form-internal (car form)
				   (if (symbolp (car form)) 'quote context)
				   env)
               (walk-tagbody-1 (cdr form) context env))))

(defun walk-compiler-let (form context old-env)
  (declare (ignore context))
  (let ((vars ())
	(vals ()))
    (dolist (binding (cadr form))
      (cond ((symbolp binding) (push binding vars) (push nil vals))
	    (t
	     (push (car binding) vars)
	     (push (eval (cadr binding)) vals))))
    (relist* form
	     (car form)
	     (cadr form)
	     (progv vars vals (walk-repeat-eval (cddr form) old-env)))))

(defun walk-macrolet (form context old-env)
  (walker-environment-bind (macro-env
			    nil
			    :walk-function (env-walk-function old-env))
    (labels ((walk-definitions (definitions)
	       (and definitions
		    (let ((definition (car definitions)))
		      (recons definitions
                              (relist* definition
                                       (car definition)
                                       (walk-arglist (cadr definition)
						     context
						     macro-env
						     t)
                                       (walk-declarations (cddr definition)
							  #'walk-repeat-eval
							  macro-env))
			      (walk-definitions (cdr definitions)))))))
      (with-new-definition-in-environment (new-env old-env form)
	(relist* form
		 (car form)
		 (walk-definitions (cadr form))
		 (walk-declarations (cddr form)
				    #'walk-repeat-eval
				    new-env))))))

(defun walk-flet (form context old-env)
  (labels ((walk-definitions (definitions)
	     (if (null definitions)
		 ()
		 (recons definitions
			 (walk-lambda (car definitions) context old-env)
			 (walk-definitions (cdr definitions))))))
    (recons form
	    (car form)
	    (recons (cdr form)
		    (walk-definitions (cadr form))
		    (with-new-definition-in-environment (new-env old-env form)
		      (walk-declarations (cddr form)
					 #'walk-repeat-eval
					 new-env))))))

(defun walk-labels (form context old-env)
  (with-new-definition-in-environment (new-env old-env form)
    (labels ((walk-definitions (definitions)
	       (if (null definitions)
		   ()
		   (recons definitions
			   (walk-lambda (car definitions) context new-env)
			   (walk-definitions (cdr definitions))))))
      (recons form
	      (car form)
	      (recons (cdr form)
		      (walk-definitions (cadr form))
		      (walk-declarations (cddr form)
					 #'walk-repeat-eval
					 new-env))))))

(defun walk-if (form context env)
  (let ((predicate (cadr form))
	(arm1 (caddr form))
	(arm2 
	  (if (cddddr form)
	      (progn
		(warn "In the form:~%~S~%~
                       IF only accepts three arguments, you are using ~D.~%~
                       It is true that some Common Lisps support this, but ~
                       it is not~%~
                       truly legal Common Lisp.  For now, this code ~
                       walker is interpreting ~%~
                       the extra arguments as extra else clauses. ~
                       Even if this is what~%~
                       you intended, you should fix your source code."
		      form
		      (length (cdr form)))
		(cons 'progn (cdddr form)))
	      (cadddr form))))
    (relist form
	    'if
	    (walk-form-internal predicate context env)
	    (walk-form-internal arm1 context env)
	    (walk-form-internal arm2 context env))))


;;;
;;; Tests tests tests
;;;

#|
;;; 
;;; Here are some examples of the kinds of things you should be able to do
;;; with your implementation of the macroexpansion environment hacking
;;; mechanism.
;;; 
;;; with-lexical-macros is kind of like macrolet, but it only takes names
;;; of the macros and actual macroexpansion functions to use to macroexpand
;;; them.  The win about that is that for macros which want to wrap several
;;; macrolets around their body, they can do this but have the macroexpansion
;;; functions be compiled.  See the WITH-RPUSH example.
;;;
;;; If the implementation had a special way of communicating the augmented
;;; environment back to the evaluator that would be totally great.  It would
;;; mean that we could just augment the environment then pass control back
;;; to the implementations own compiler or interpreter.  We wouldn't have
;;; to call the actual walker.  That would make this much faster.  Since the
;;; principal client of this is defmethod it would make compiling defmethods
;;; faster and that would certainly be a win.
;;;
(defmacro with-lexical-macros (macros &body body &environment old-env)
  (with-augmented-environment (new-env old-env :macros macros)
    (walk-form (cons 'progn body) :environment new-env)))

(defun expand-rpush (form env)
  `(push ,(caddr form) ,(cadr form)))

(defmacro with-rpush (&body body)
  `(with-lexical-macros ,(list (list 'rpush #'expand-rpush)) ,@body))


;;;
;;; Unfortunately, I don't have an automatic tester for the walker.  
;;; Instead there is this set of test cases with a description of
;;; how each one should go.
;;; 
(defmacro take-it-out-for-a-test-walk (form)
  `(take-it-out-for-a-test-walk-1 ',form))

(defun take-it-out-for-a-test-walk-1 (form)
  (terpri)
  (terpri)
  (let ((copy-of-form (copy-tree form))
	(result (walk-form form nil
		  #'(lambda (x y env)
		      (format t "~&Form: ~S ~3T Context: ~A" x y)
		      (when (symbolp x)
			(let ((lexical (variable-lexical-p x env))
			      (special (variable-special-p x env)))
			  (when lexical
			    (format t ";~3T")
			    (format t "lexically bound"))
			  (when special
			    (format t ";~3T")
			    (format t "declared special"))
			  (when (boundp x)
			    (format t ";~3T")
			    (format t "bound: ~S " (eval x)))))
		      x))))
    (cond ((not (equal result copy-of-form))
	   (format t "~%Warning: Result not EQUAL to copy of start."))
	  ((not (eq result form))
	   (format t "~%Warning: Result not EQ to copy of start.")))
    (pprint result)
    result))

(defmacro foo (&rest ignore) ''global-foo)

(defmacro bar (&rest ignore) ''global-bar)

(take-it-out-for-a-test-walk (list arg1 arg2 arg3))
(take-it-out-for-a-test-walk (list (cons 1 2) (list 3 4 5)))

(take-it-out-for-a-test-walk (progn (foo) (bar 1)))

(take-it-out-for-a-test-walk (block block-name a b c))
(take-it-out-for-a-test-walk (block block-name (list a) b c))

(take-it-out-for-a-test-walk (catch catch-tag (list a) b c))
;;;
;;; This is a fairly simple macrolet case.  While walking the body of the
;;; macro, x should be lexically bound. In the body of the macrolet form
;;; itself, x should not be bound.
;;; 
(take-it-out-for-a-test-walk
  (macrolet ((foo (x) (list x) ''inner))
    x
    (foo 1)))

;;;
;;; A slightly more complex macrolet case.  In the body of the macro x
;;; should not be lexically bound.  In the body of the macrolet form itself
;;; x should be bound.  Note that THIS CASE WILL CAUSE AN ERROR when it
;;; tries to macroexpand the call to foo.
;;; 
(take-it-out-for-a-test-walk
     (let ((x 1))
       (macrolet ((foo () (list x) ''inner))
	 x
	 (foo))))

;;;
;;; A truly hairy use of compiler-let and macrolet.  In the body of the
;;; macro x should not be lexically bound.  In the body of the macrolet
;;; itself x should not be lexically bound.  But the macro should expand
;;; into 1.
;;; 
(take-it-out-for-a-test-walk
  (compiler-let ((x 1))
    (let ((x 2))
      (macrolet ((foo () x))
	x
	(foo)))))


(take-it-out-for-a-test-walk
  (flet ((foo (x) (list x y))
	 (bar (x) (list x y)))
    (foo 1)))

(take-it-out-for-a-test-walk
  (let ((y 2))
    (flet ((foo (x) (list x y))
	   (bar (x) (list x y)))
      (foo 1))))

(take-it-out-for-a-test-walk
  (labels ((foo (x) (bar x))
	   (bar (x) (foo x)))
    (foo 1)))

(take-it-out-for-a-test-walk
  (flet ((foo (x) (foo x)))
    (foo 1)))

(take-it-out-for-a-test-walk
  (flet ((foo (x) (foo x)))
    (flet ((bar (x) (foo x)))
      (bar 1))))

(take-it-out-for-a-test-walk (compiler-let ((a 1) (b 2)) (foo a) b))
(take-it-out-for-a-test-walk (prog () (declare (special a b))))
(take-it-out-for-a-test-walk (let (a b c)
                               (declare (special a b))
                               (foo a) b c))
(take-it-out-for-a-test-walk (let (a b c)
                               (declare (special a) (special b))
                               (foo a) b c))
(take-it-out-for-a-test-walk (let (a b c)
                               (declare (special a))
                               (declare (special b))
                               (foo a) b c))
(take-it-out-for-a-test-walk (let (a b c)
                               (declare (special a))
                               (declare (special b))
                               (let ((a 1))
                                 (foo a) b c)))
(take-it-out-for-a-test-walk (eval-when ()
                               a
                               (foo a)))
(take-it-out-for-a-test-walk (eval-when (eval when load)
                               a
                               (foo a)))

(take-it-out-for-a-test-walk (multiple-value-bind (a b) (foo a b) (list a b)))
(take-it-out-for-a-test-walk (multiple-value-bind (a b)
				 (foo a b)
			       (declare (special a))
			       (list a b)))
(take-it-out-for-a-test-walk (progn (function foo)))
(take-it-out-for-a-test-walk (progn a b (go a)))
(take-it-out-for-a-test-walk (if a b c))
(take-it-out-for-a-test-walk (if a b))
(take-it-out-for-a-test-walk ((lambda (a b) (list a b)) 1 2))
(take-it-out-for-a-test-walk ((lambda (a b) (declare (special a)) (list a b))
			      1 2))
(take-it-out-for-a-test-walk (let ((a a) (b a) (c b)) (list a b c)))
(take-it-out-for-a-test-walk (let* ((a a) (b a) (c b)) (list a b c)))
(take-it-out-for-a-test-walk (let ((a a) (b a) (c b))
                               (declare (special a b))
                               (list a b c)))
(take-it-out-for-a-test-walk (let* ((a a) (b a) (c b))
                               (declare (special a b))
                               (list a b c)))
(take-it-out-for-a-test-walk (let ((a 1) (b 2))
                               (foo bar)
                               (declare (special a))
                               (foo a b)))
(take-it-out-for-a-test-walk (multiple-value-call #'foo a b c))
(take-it-out-for-a-test-walk (multiple-value-prog1 a b c))
(take-it-out-for-a-test-walk (progn a b c))
(take-it-out-for-a-test-walk (progv vars vals a b c))
(take-it-out-for-a-test-walk (quote a))
(take-it-out-for-a-test-walk (return-from block-name a b c))
(take-it-out-for-a-test-walk (setq a 1))
(take-it-out-for-a-test-walk (setq a (foo 1) b (bar 2) c 3))
(take-it-out-for-a-test-walk (tagbody a b c (go a)))
(take-it-out-for-a-test-walk (the foo (foo-form a b c)))
(take-it-out-for-a-test-walk (throw tag-form a))
(take-it-out-for-a-test-walk (unwind-protect (foo a b) d e f))

(defmacro flet-1 (a b) ''outer)
(defmacro labels-1 (a b) ''outer)

(take-it-out-for-a-test-walk
  (flet ((flet-1 (a b) () (flet-1 a b) (list a b)))
    (flet-1 1 2)
    (foo 1 2)))
(take-it-out-for-a-test-walk
  (labels ((label-1 (a b) () (label-1 a b)(list a b)))
    (label-1 1 2)
    (foo 1 2)))
(take-it-out-for-a-test-walk (macrolet ((macrolet-1 (a b) (list a b)))
                               (macrolet-1 a b)
                               (foo 1 2)))

(take-it-out-for-a-test-walk (macrolet ((foo (a) `(inner-foo-expanded ,a)))
                               (foo 1)))

(take-it-out-for-a-test-walk (progn (bar 1)
                                    (macrolet ((bar (a)
						 `(inner-bar-expanded ,a)))
                                      (bar 2))))

(take-it-out-for-a-test-walk (progn (bar 1)
                                    (macrolet ((bar (s)
						 (bar s)
						 `(inner-bar-expanded ,s)))
                                      (bar 2))))

(take-it-out-for-a-test-walk (cond (a b)
                                   ((foo bar) a (foo a))))


(let ((the-lexical-variables ()))
  (walk-form '(let ((a 1) (b 2))
		#'(lambda (x) (list a b x y)))
	     ()
	     #'(lambda (form context env)
		 (when (and (symbolp form)
			    (variable-lexical-p form env))
		   (push form the-lexical-variables))
		 form))
  (or (and (= (length the-lexical-variables) 3)
	   (member 'a the-lexical-variables)
	   (member 'b the-lexical-variables)
	   (member 'x the-lexical-variables))
      (error "Walker didn't do lexical variables of a closure properly.")))
    
|#

()
