;;;-*-Mode:LISP; Package:(CLOS (LISP WALKER)); Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;;
;;; Medley-Lisp specific environment hacking for CLOS

(in-package "CLOS")

;; 
;; Protect the Corporation
;; 
(eval-when (eval load)
  (format *terminal-io*
    "~&;CLOS-ENV Copyright (c) 1991 by ~
        Venue Corporation.  All rights reserved.~%"))


;;; Make funcallable instances (FINs) print by calling print-object.

(eval-when (eval load)
  (il:defprint 'il:compiled-closure 'il:print-closure))

(defun il:print-closure (x &optional stream depth)
  ;; See the IRM, section 25.3.3.  Unfortunatly, that documentation is
  ;; not correct.  In particular, it makes no mention of the third argument.
  (cond ((not (funcallable-instance-p x))
	 ;; IL:\CCLOSURE.DEFPRINT is the orginal system function for
	 ;; printing closures
	 (il:\\cclosure.defprint x stream))
	((streamp stream)
	 ;; Use the standard CLOS printing method, then return T to tell
	 ;; the printer that we have done the printing ourselves.
	 (print-object x stream)
	 t)
	(t 
	 ;; Internal printing (again, see the IRM section 25.3.3). 
	 ;; Return a list containing the string of characters that
	 ;; would be printed, if the object were being printed for
	 ;; real.
	 (with-output-to-string (stream)
	   (list (print-object x stream))))))


;;; Naming methods

(defun gf-named (gf-name)
  (let ((spec (cond ((symbolp gf-name) gf-name)
		    ((and (consp gf-name)
			  (eq (first gf-name) 'setf)
			  (symbolp (second gf-name))
			  (null (cddr gf-name)))
		     (get-setf-function-name (second gf-name)))
		    (t nil))))
    (if (and (fboundp spec)
	     (generic-function-p (symbol-function spec)))
	(symbol-function spec)
	nil)))

(defun generic-function-method-names (gf-name hasdefp)
  (if hasdefp
      (let ((names nil))
        (maphash #'(lambda (key value)
                     (declare (ignore value))
                     (when (and (consp key) (eql (car key) gf-name))
                       (pushnew key names)))
                 (gethash 'methods xcl:*definition-hash-table*))
        names)
      (let ((gf (gf-named gf-name)))
        (when gf
          (mapcar #'full-method-name (generic-function-methods gf))))))

(defun full-method-name (method)
  "Return the full name of the method"
  (let ((specializers (mapcar #'(lambda (x)
		                  (cond ((eq x 't) t)
		                        ((and (consp x) (eq (car x) 'eql)) x)
		                        (t (class-name x))))
		       (method-specializers method))))
    ;; Now go through some hair to make sure that specializer is
    ;; really right.  Once CLOS returns the right value for
    ;; specializers this can be taken out.
    (let* ((arglist (method-lambda-list method))
	   (number-required (or (position-if
				  #'(lambda (x) (member x lambda-list-keywords))
				  arglist)
				(length arglist)))
	   (diff (- number-required (length specializers))))
      (when (> diff 0)
	(setq specializers (nconc (copy-list specializers)
				  (make-list diff :initial-element 't)))))
    (make-full-method-name (generic-function-name
			       (method-generic-function method))
			   (method-qualifiers method)
			   specializers)))

(defun make-full-method-name (generic-function-name qualifiers arg-types)
  "Return the full name of a method, given the generic-function name, the method
qualifiers, and the arg-types"
  ;; The name of the method is:
  ;;      (<generic-function-name> <qualifier-1> .. 
  ;;         (<arg-specializer-1>..))
  (labels ((remove-trailing-ts (l)
	     (if (null l)
		 nil
		 (let ((tail (remove-trailing-ts (cdr l))))
		   (if (null tail)
		       (if (eq (car l) 't)
			   nil
			   (list (car l)))
		       (if (eq l tail)
			   l
			   (cons (car l) tail)))))))
    `(,generic-function-name ,@qualifiers
      ,(remove-trailing-ts arg-types))))

(defun parse-full-method-name (method-name)
  "Parse the method name, returning the gf-name, the qualifiers, and the
arg-types."
  (values (first method-name)
	  (butlast (rest method-name))
	  (car (last method-name))))

(defun prompt-for-full-method-name (gf-name &optional has-def-p)
  "Prompt the user for the full name of a method on the given generic function name"
  (let ((method-names (generic-function-method-names gf-name has-def-p)))
    (cond ((null method-names)
	   nil)
	  ((null (cdr method-names))
	   (car method-names))
	  (t (il:menu
	      (il:create
	       il:menu il:items il:_	;If HAS-DEF-P, include only
					; those methods that have a
					; symbolic def'n that we can
					; find
	       (remove-if #'null
			  (mapcar #'(lambda (m)
				      (if (or (not has-def-p)
					      (il:hasdef m 'methods))
					  `(,(with-output-to-string (s)
					       (dolist (x m)
						 (format s "~A " x))
					       s)
					    ',m)
					  nil))
				  method-names))
	       il:title il:_ "Which method?"))))))


;;; Converting generic defining macros into DEFDEFINER macros

(defmacro make-defdefiner (definer-name definer-type type-description &body 
					definer-options)
  "Make the DEFINER-NAME use DEFDEFINER, defining items of type DEFINER-TYPE"
  (let ((old-definer-macro-name (intern (string-append definer-name
						       " old definition")
					(symbol-package definer-name)))
	(old-definer-macro-expander (intern (string-append definer-name 
							   " old expander")
					    (symbol-package definer-name))))
    `(progn 
      ;; First, move the current defining function off to some safe
      ;; place
      (unmake-defdefiner ',definer-name)
      (cond ((not (fboundp ',definer-name))
	     (error "~A has no definition!" ',definer-name))
	    ((fboundp ',old-definer-macro-name))
	    ((macro-function ',definer-name)
					; We have to move the macro
					; expansion function as well,
					; so it won't get clobbered
					; when the original macro is
					; redefined.  See AR 7410.
	     (let* ((expansion-function (macro-function ',definer-name)))
	       (setf (symbol-function ',old-definer-macro-expander)
		     (loop (if (symbolp expansion-function)
			       (setq expansion-function
				     (symbol-function expansion-function))
			       (return expansion-function))))
	       (setf (macro-function ',old-definer-macro-name)
		     ',old-definer-macro-expander)
	       (setf (get ',definer-name 'make-defdefiner) expansion-function)))
	    (t (error "~A does not name a macro." ',definer-name)))
      ;; Make sure the type is defined
      (xcl:def-define-type ,definer-type ,type-description)
      ;; Now redefine the definer, using DEFEDFINER and the original def'n
      (xcl:defdefiner ,(if definer-options
			   (cons definer-name definer-options)
			   definer-name)
	  ,definer-type	(&body b) `(,',old-definer-macro-name ,@,'b)))))

(defun unmake-defdefiner (definer-name)
  (let ((old-expander (get definer-name 'make-defdefiner)))
    (when old-expander
      (setf (macro-function definer-name old-expander))
      (remprop definer-name 'make-defdefiner))))


;;; For tricking ED into being able to use just the generic-function-name
;;; instead of the full method name

(defun source-manager-method-edit-fn (name type source editcoms options)
  "Edit a method of the given name"
  (let ((full-name (if (gf-named name)
					;If given the name of a
					; generic-function, try to get
					; the full method name
		       (prompt-for-full-method-name name t)
					; Otherwise it should name the
					; method
		       name)))
    (when (not (null full-name))
      (il:default.editdef full-name type source editcoms options))
    (or full-name name)))		;Return the name

(defun source-manager-method-hasdef-fn (name type &optional source)
  "Is there a method defined with the given name?"
  (cond ((not (eq type 'methods)) nil)
	((or (symbolp name)
	     (and (consp name)
		  (eq (first name) 'setf)
		  (symbolp (second name))
		  (null (cddr name))))
	 ;; If passed in the name of a generic-function, pretend that
	 ;; there is a method by that name if there is a generic function
	 ;; by that name, and there is a method whose source we can find.
	 (if (and (not (null (gf-named name)))
		  (find-if #'(lambda (m)
			       (il:hasdef m type source))
			   (generic-function-method-names name t)))
	     name
	     nil))
	((and (consp name) (>= (length name) 2))
	 ;; Standard methods are named (gf-name {qualifiers}* ({specializers}*))
	 (when (il:getdef name type source '(il:nocopy il:noerror))
	   name))
	(t
	 ;; Nothing else can name a method
	 nil)))

;;; Initialize the CLOS env

(defun initialize-clos-env nil
  "Initialize the Medley CLOS environment" 
  ;; Set up SourceManager DEFDEFINERS for classes and methods.
  ;;
  ;; Make sure to define methods before classes, so that (IL:FILES?) will build
  ;; filecoms that have classes before methods. 
  (unless (il:hasdef 'methods 'il:filepkgtype)
    (make-defdefiner defmethod methods "methods"
		     (:name (lambda (form)
			      (multiple-value-bind (name qualifiers arglist)
				  (parse-defmethod (cdr form))
				(make-full-method-name name qualifiers
				    (specialized-lambda-list-specializers
					arglist)))))
		     (:undefiner
		      (lambda (method-name)
			(multiple-value-bind
			      (name qualifiers arg-types)
			    (parse-full-method-name method-name)
			  (let* ((gf (gf-named name))
				 (method (when gf
					   (get-method gf qualifiers
						       (mapcar #'find-class 
							       arg-types)))))
			    (when method (remove-method gf method))))))))
  ;; Include support for DEFGENERIC, if that is defined
  (unless (or (not (fboundp 'defgeneric))
	      (il:hasdef 'generic-functions 'il:filepkgtype))
    (make-defdefiner defgeneric generic-functions "generic-function definitions"))
  ;; DEFCLASS FileManager stuff
  (unless (il:hasdef 'classes 'il:filepkgtype)
    (make-defdefiner defclass classes "class definitions"
		     (:undefiner (lambda (name)
				   (when (find-class name t)
				     (setf (find-class name) nil)))))
    ;; CLASSES "include" TYPES.
    (il:filepkgcom 'classes 'il:contents
		   #'(lambda (com name type &optional reason)
		       (declare (ignore name reason))
		       (if (member type '(il:types classes) :test #'eq)
			   (cdr com)
			   nil))))
  ;; Set up the hooks so that ED can be handed the name of a generic function,
  ;; and end up editing a method instead
  (il:filepkgtype 'methods 'il:editdef 'source-manager-method-edit-fn
		  'il:hasdef 'source-manager-method-hasdef-fn)
  ;; Set up the inspect macro.  The right way to do this is to
  ;; (ENSURE-GENERIC-FUNCTION 'IL:INSPECT...), but for now...
  (push '((il:function clos-object-p) . \\internal-inspect-object)
	il:inspectmacros)
  ;; Unmark any SourceManager changes caused by this loadup
  (dolist (com (il:filepkgchanges))
    (dolist (name (cdr com))
      (when (and (symbolp name)
		 (eq (symbol-package name) (find-package "CLOS")))
	(il:unmarkaschanged name (car com))))))

(eval-when (eval load)
  (initialize-clos-env))


;;; Inspecting CLOS objects

(defun clos-object-p (x)
  "Is the datum a CLOS object?"
  (or (std-instance-p x)
      (fsc-instance-p x)))

(defun \\internal-inspect-object (x type where)
  (inspect-object x type where))

(defun \\internal-inspect-slot-names (x)
  (inspect-slot-names x))

(defun \\internal-inspect-slot-value (x slot-name)
  (inspect-slot-value x slot-name))

(defun \\internal-inspect-setf-slot-value (x slot-name value)
  (inspect-setf-slot-value x slot-name value))

(defun \\internal-inspect-slot-name-command (slot-name x window)
  (inspect-slot-name-command slot-name x window))

(defun \\internal-inspect-title (x y)
  (inspect-title x y))

(defmethod inspect-object (x type where)
  "Open an insect window on the object x"
  (il:inspectw.create x '\\internal-inspect-slot-names
              '\\internal-inspect-slot-value
              '\\internal-inspect-setf-slot-value
              '\\internal-inspect-slot-name-command nil nil 
              '\\internal-inspect-title nil where
              #'(lambda (n v)		;Same effect as NIL, but avoids bug in
		  (declare (ignore v))	; INSPECTW.CREATE
		  n)))

(defmethod inspect-slot-names (x)
  "Return a list of names of slots of the object that should be shown in the
inspector"
  (mapcar #'(lambda (slotd) (slot-value slotd 'name))
	  (slots-to-inspect (class-of x) x)))

(defmethod inspect-slot-value (x slot-name)
  (cond ((not (slot-exists-p x slot-name)) "** no such slot **")
	((not (slot-boundp x slot-name)) "** slot not bound **")
	(t (slot-value x slot-name))))

(defmethod inspect-setf-slot-value (x slot-name value)
  "Used by the inspector to set the value fo a slot"
  ;; Make this UNDO-able
  (il:undosave `(inspect-setf-slot-value ,x ,slot-name
		 ,(slot-value x slot-name)))
  ;; Then change the value
  (setf (slot-value x slot-name) value))

(defmethod inspect-slot-name-command (slot-name x window)
  "Allows the user to select a menu item to change a slot value in an inspect
window"
  ;; This code is a very slightly hacked version of the system function
  ;; DEFAULT.INSPECTW.PROPCOMMANDFN.  We have to do this because the
  ;; standard version makes some nasty assumptions about
  ;; structure-objects that are not true for CLOS objects.
  (declare (special il:|SetPropertyMenu|))
  (case (il:menu (cond ((typep il:|SetPropertyMenu| 'il:menu)
			il:|SetPropertyMenu|)
		       (t (il:setq il:|SetPropertyMenu|
				   (il:|create| il:menu il:items il:_
				       '((set 'set 
					  "Allows a new value to be entered"
					  )))))))
    (set 
     ;; The user want to set the value
     (il:ersetq (prog ((il:oldvalueitem (il:itemofpropertyvalue slot-name 
								window))
		       il:newvalue il:pwindow)
		   (il:ttydisplaystream (il:setq il:pwindow
						 (il:getpromptwindow window 3)))
		   (il:clearbuf t t)
		   (il:resetlst
		    (il:resetsave (il:\\itemw.flipitem il:oldvalueitem window)
				  (list 'il:\\itemw.flipitem 
					il:oldvalueitem window))
		    (il:resetsave (il:tty.process (il:this.process)))
		    (il:resetsave (il:printlevel 4 3))
		    (il:|printout| t "Enter the new " 
			slot-name " for " x t 
			"The expression read will be EVALuated."
			t "> ")
		    (il:setq il:newvalue (il:lispx (il:lispxread t t)
						   '>))
					; clear tty buffer because it
					; sometimes has stuff left.
		    (il:clearbuf t t))
		   (il:closew il:pwindow)
		   (return (il:inspectw.replace window slot-name il:newvalue)))))))

(defmethod inspect-title (x window)
  "Return the title to use in an inspect window viewing x"
  (format nil "Inspecting a ~A" (class-name (class-of x))))

(defmethod inspect-title ((x standard-class) window)
  (format nil "Inspecting the class ~A" (class-name x)))


;;;  Debugger support for CLOS


(il:filesload clos-env-internal)

;; Non-CLOS specific changes to the debugger

;; Redefining the standard INTERESTING-FRAME-P function.  Now functions can be
;; declared uninteresting to BT by giving them an XCL::UNINTERESTINGP
;; property.

(dolist (fn '(si::*unwind-protect* il:*env*
	      evalhook xcl::nohook xcl::undohook
	      xcl::execa0001 xcl::execa0001a0002
	      xcl::|interpret-UNDOABLY|
	      cl::|interpret-IF| cl::|interpret-FLET|
	      cl::|interpret-LET| cl::|interpret-LETA0001|
	      cl::|interpret-BLOCK| cl::|interpret-BLOCKA0001|
	      il:do-event il:eval-input
	      apply t))
  (setf (get fn 'xcl::uninterestingp) t))

(defun xcl::interesting-frame-p (xcl::pos &optional xcl::interpflg)
  "Return TRUE iff the frame should be visible for a short backtrace."
  (declare (special il:openfns))
  (let ((xcl::name (if (il:stackp xcl::pos) (il:stkname xcl::pos) xcl::pos)))
    (typecase xcl::name
      (symbol (case xcl::name
		(il:*env*
		 ;; *ENV* is used by ENVEVAL etc.
		 nil)
		(il:errorset
		 (or (<= (il:stknargs xcl::pos) 1)
		     (not (eq (il:stkarg 2 xcl::pos nil)
			      'il:internal))))
		(il:eval
		 (or (<= (il:stknargs xcl::pos) 1)
		     (not (eq (il:stkarg 2 xcl::pos nil)
			      'xcl::internal))))
		(il:apply
		 (or (<= (il:stknargs xcl::pos) 2)
		     (not (il:stkarg 3 xcl::pos nil))))
		(otherwise
		 (cond ((get xcl::name 'xcl::uninterestingp)
			;; Explicitly declared uninteresting.
			nil)
		       ((eq (il:chcon1 xcl::name) (char-code #\\))
			;; Implicitly declared uninteresting by starting the
			;; name with a "\".
			nil)
		       ((or (member xcl::name il:openfns :test #'eq)
			    (eq xcl::name 'funcall))
			;;The function won't be seen when compiled, so only show
			;;it if INTERPFLG it true
			xcl::interpflg)
		       (t 
			;; Interesting by default.
			t)))))
       (cons (case (car xcl::name)
	       (:broken t)
	       (otherwise nil)))
       (otherwise nil))))

(setq il:*short-backtrace-filter* 'xcl::interesting-frame-p)


(eval-when (eval compile)
  (il:record il:bkmenuitem (il:label (il:bkmenuinfo il:frame-name))))


;;  Change the frame inspector to open up lexical environments

  ;; Since the DEFSTRUCT is going to build the accessors in the package that is
  ;; current at read-time, and we want the accessors to reside in the IL
  ;; package, we have got to make sure that the defstruct happens when the
  ;; package is IL.

(in-package "IL")

(cl:defstruct (frame-prop-name (:type cl:list))
  (label-fn 'nill)
  (value-fn
   (function
    (lambda (prop-name framespec)
     (frame-prop-name-data prop-name))))
  (setf-fn 'nill)
  (inspect-fn
   (function
    (lambda (value prop-name framespec window)
     (default.inspectw.valuecommandfn value prop-name (car framespec) window))))
  (data nil))

(cl:in-package "CLOS")

(defun il:debugger-stack-frame-prop-names (il:framespec) 
  ;; Frame prop-names are structures of the form
  ;; (LABEL-FN VALUE-FN SETF-FN EDIT-FN DATA)
  (let ((il:pos (car il:framespec))
	(il:backtrace-item (cadr il:framespec)))
    (il:if (eq 'eval (il:stkname il:pos))
     il:then
     (let ((il:expression (il:stkarg 1 il:pos))
	   (il:environment (il:stkarg 2 il:pos)))
       `(,(il:make-frame-prop-name :inspect-fn
	   (il:function
	    (il:lambda (il:value il:prop-name il:framespec il:window)
	      (il:inspect/as/function il:value (car il:framespec) il:window)))
	   :data il:expression)
	 ,(il:make-frame-prop-name :data "ENVIRONMENT")
	 ,@(il:for il:aspect il:in
	    `((,(and il:environment (il:environment-vars il:environment))
	       "vars")
	      (,(and il:environment (il:environment-functions il:environment))
	       "functions")
	      (,(and il:environment (il:environment-blocks il:environment))
	       "blocks")
	      (,(and il:environment (il:environment-tagbodies il:environment))
	       "tag bodies"))
	    il:bind il:group-name il:p-list
	    il:eachtime (il:setq il:group-name (cadr il:aspect))
	                (il:setq il:p-list (car il:aspect))
	    il:when (not (null il:p-list))
	    il:join
	    `(,(il:make-frame-prop-name :data il:group-name)
	      ,@(il:for il:p il:on il:p-list il:by cddr il:collect
		 (il:make-frame-prop-name :label-fn
		  (il:function (il:lambda (il:prop-name il:framespec)
				 (car (il:frame-prop-name-data il:prop-name))))
		  :value-fn
		  (il:function (il:lambda (il:prop-name il:framespec)
				 (cadr (il:frame-prop-name-data il:prop-name))))
		  :setf-fn
		  (il:function (il:lambda (il:prop-name il:framespec il:new-value)
				 (il:change (cadr (il:frame-prop-name-data
						   il:prop-name))
					    il:new-value)))
		  :data il:p))))))
     il:else
     (flet ((il:build-name (&key il:arg-name il:arg-number)
	      (il:make-frame-prop-name :label-fn
		  (il:function (il:lambda (il:prop-name il:framespec)
				 (car (il:frame-prop-name-data il:prop-name))))
		  :value-fn
		  (il:function (il:lambda (il:prop-name il:framespec)
				 (il:stkarg (cadr (il:frame-prop-name-data
						   il:prop-name))
					    (car il:framespec))))
		  :setf-fn
		  (il:function (il:lambda (il:prop-name il:framespec il:new-value)
				 (il:setstkarg (cadr (il:frame-prop-name-data
						      il:prop-name))
					       (car il:framespec)
					       il:new-value)))
		  :data
		  (list il:arg-name il:arg-number))))
       (let ((il:nargs (il:stknargs il:pos t))
	     (il:nargs1 (il:stknargs il:pos))
	     (il:fnname (il:stkname il:pos))
	     il:argname
	     (il:arglist))
	 (and (il:litatom il:fnname)
	      (il:ccodep il:fnname)
	      (il:setq il:arglist (il:listp (il:smartarglist il:fnname))))
	 `(,(il:make-frame-prop-name :inspect-fn
	     (il:function (il:lambda (il:value il:prop-name il:framespec
					       il:window)
			    (il:inspect/as/function il:value
						    (car il:framespec)
						    il:window)))
	     :data
	     (il:fetch (il:bkmenuitem il:frame-name) il:of il:backtrace-item))
	   ,@(il:bind il:mode il:for il:i il:from 1 il:to il:nargs1 il:collect
	      (progn (il:while (il:fmemb (il:setq il:argname (il:pop il:arglist))
					 lambda-list-keywords)
			       il:do
			       (il:setq il:mode il:argname))
		     (il:build-name :arg-name
				    (or (il:stkargname il:i il:pos)
					; special
					(if (case il:mode
					      ((nil &optional) il:argname)
					      (t nil))
					    (string il:argname)
					    (il:concat "arg " (- il:i 1))))
				    :arg-number il:i)))
	   ,@(let* ((il:novalue "No value")
		    (il:slots (il:for il:pvar il:from 0 il:as il:i il:from
				      (il:add1 il:nargs1)
				      il:to il:nargs il:by 1 il:when
				      (and (il:neq il:novalue (il:stkarg il:i il:pos
									 il:novalue))
					   (or (il:setq il:argname (il:stkargname
								    il:i il:pos))
					       (il:setq il:argname (il:concat 
								    "local " 
								    il:pvar)))
					   )
				      il:collect
				      (il:build-name :arg-name il:argname 
						     :arg-number il:i))))
               (and il:slots (cons (il:make-frame-prop-name :data "locals")
                                   il:slots)))))))))

(defun il:debugger-stack-frame-fetchfn (il:framespec il:prop-name)
  (il:apply* (il:frame-prop-name-value-fn il:prop-name)
	     il:prop-name il:framespec))

(defun il:debugger-stack-frame-storefn (il:framespec il:prop-name il:newvalue)
  (il:apply* (il:frame-prop-name-setf-fn il:prop-name)
	     il:prop-name il:framespec il:newvalue))

(defun il:debugger-stack-frame-value-command (il:datum il:prop-name 
						       il:framespec il:window)
  (il:apply* (il:frame-prop-name-inspect-fn il:prop-name)
	     il:datum il:prop-name il:framespec il:window))

(defun il:debugger-stack-frame-title (il:framespec &optional il:window)
  (declare (ignore il:window))
  (il:concat (il:stkname (car il:framespec)) "  Frame"))

(defun il:debugger-stack-frame-property (il:prop-name il:framespec)
  (il:apply* (il:frame-prop-name-label-fn il:prop-name)
	     il:prop-name il:framespec))

;; Teaching the debugger that there are other file-manager types that can
;; appear on the stack

(defvar xcl::*function-types* '(il:fns il:functions)
  "Manager types that can appear on the stack")

;; Redefine a couple of system functions to use the above stuff

#+Xerox-Lyric
(progn

(defun il:attach-backtrace-menu (&optional (il:ttywindow
					    (il:wfromds (il:ttydisplaystream)))
					   il:skip)
  (let ((il:bkmenu (il:|create| il:menu
		       il:items il:_
		       (il:collect-backtrace-items il:ttywindow il:skip)
		       il:whenselectedfn il:_
		       (il:function il:backtrace-item-selected)
		       il:whenheldfn il:_
		       #'(il:lambda (il:item il:menu il:button)
			   (declare (ignore il:item il:menu))
			   (case il:button
			     (il:left (il:promptprint 
				       "Open a frame inspector on this stack frame"
				       ))
			     (il:middle (il:promptprint 
					 "Inspect/Edit this function"))
			     ))
		       il:menuoutlinesize il:_ 0
		       il:menufont il:_ il:backtracefont
		       il:menucolumns il:_ 1))
	(il:ttyregion (il:windowprop il:ttywindow 'il:region))
	il:btw)
    (cond
      ((il:setq il:btw (il:|for| il:atw il:|in| (il:attachedwindows il:ttywindow)
			   il:|when| (and (il:setq il:btw (il:windowprop il:atw 'il:menu))
					  (eql (il:|fetch| (il:menu il:whenselectedfn)
						   il:|of| (car il:btw))
					       (il:function il:backtrace-item-selected)))
			   il:|do|                       
			   (return il:atw)))       
       (il:deletemenu (car (il:windowprop il:btw 'il:menu))
		      nil il:btw)
       (il:windowprop il:btw 'il:extent nil)
       (il:clearw il:btw))
      ((il:setq il:btw (il:createw (il:region-next-to (il:windowprop il:ttywindow 'il:region)
						      (il:widthifwindow (il:imin (il:|fetch| (il:menu 
											      il:imagewidth
											      )
										     il:|of| il:bkmenu)
										 il:|MaxBkMenuWidth|))
						      (il:|fetch| (il:region il:height) il:|of| il:ttyregion
							  )
						      'il:left)))   
       (il:attachwindow il:btw il:ttywindow (cond
					      ((il:igreaterp (il:|fetch| (il:region il:left)
								 il:|of| (il:windowprop
									  il:btw
									  'il:region))
							     (il:|fetch| (il:region il:left)
								 il:|of| il:ttyregion))
					       'il:right)
					      (t 'il:left))
			nil
			'il:localclose)
       (il:windowprop il:btw 'il:process (il:windowprop il:ttywindow 'il:process))

       ))
    (il:addmenu il:bkmenu il:btw (il:|create| il:_ il:position
				     il:xcoord il:_ 0
				     il:ycoord il:_ (il:idifference (il:windowprop
								     il:btw
								     'il:height)
								    (il:|fetch| (il:menu il:imageheight
											 ) il:|of| 
											   il:bkmenu
											   ))))))

(defun il:backtrace-item-selected (il:item il:menu il:button)
  (il:resetlst
   (prog (il:olditem il:ttywindow il:bkpos il:pos il:positions il:framewindow
		     (il:framespecn (il:|fetch| (il:bkmenuitem il:bkmenuinfo) il:|of| il:item)

				    ))
      (cond
	((il:setq il:olditem (il:|fetch| (il:menu il:menuuserdata) il:|of| il:menu))
	 (il:menudeselect il:olditem il:menu)        
	 ))
      (il:setq il:ttywindow (il:windowprop (il:wfrommenu il:menu)
					   'il:mainwindow))
      (il:setq il:bkpos (il:windowprop il:ttywindow 'il:stack-position))
      (il:setq il:pos (il:stknth (- il:framespecn)
				 il:bkpos))
      (let ((il:lp (il:windowprop il:ttywindow 'il:lastpos)))
	(and il:lp (il:stknth 0 il:pos il:lp)))
      (il:menuselect il:item il:menu)                
      (if (eq il:button 'il:middle)
	  (progn 


	    (il:resetsave nil (list 'il:relstk il:pos))
	    (il:inspect/as/function (il:|fetch| (il:bkmenuitem il:frame-name)
					il:|of| il:item)
				    il:pos il:ttywindow))
	  (progn 


	    (il:setq il:framewindow
		     (xcl:with-profile (il:process.eval
						  (il:windowprop il:ttywindow 'il:process)
						  '(let ((il:profile (xcl:copy-profile (xcl:find-profile
											"READ-PRINT"))))
						    (setf (xcl::profile-entry-value '
							   xcl:*eval-function* il:profile)
						     xcl:*eval-function*)
						    (xcl:save-profile il:profile))
						  t)
		       (il:inspectw.create (list il:pos il:item)
				   'il:debugger-stack-frame-prop-names
				   'il:debugger-stack-frame-fetchfn
				   'il:debugger-stack-frame-storefn nil '
				   il:debugger-stack-frame-value-command nil '
				   il:debugger-stack-frame-title nil (
								      il:make-frame-inspect-window
								      il:ttywindow)
				   'il:debugger-stack-frame-property)))
	    (cond
	      ((not (il:windowprop il:framewindow 'il:mainwindow))
	       (il:attachwindow il:framewindow il:ttywindow
				(cond
				  ((il:igreaterp (il:|fetch| (il:region il:bottom)
						     il:|of| (il:windowprop il:framewindow
									    'il:region))
						 (il:|fetch| (il:region il:bottom)
						     il:|of| (il:windowprop il:ttywindow 'il:region)))
				   'il:top)
				  (t 'il:bottom))
				nil
				'il:localclose)
	       (il:windowaddprop il:framewindow 'il:closefn (il:function il:detachwindow
									 ))))))
      (return))))

(defun il:collect-backtrace-items (xcl::tty-window xcl::skip)
   (let* ((xcl::items (cons nil nil))
          (xcl::items-tail xcl::items))
         (macrolet ((xcl::collect-item (xcl::new-item)
                           `(progn (setf (rest xcl::items-tail)
                                         (cons ,xcl::new-item nil))
                                   (pop xcl::items-tail))))
                (let* ((xcl::filter-fn (cond
                                          ((null xcl::skip)
                                           #'xcl:true)
                                          ((eq xcl::skip t)
                                           il:*short-backtrace-filter*)
                                          (t xcl::skip)))
                       (xcl::top-frame (il:stknth 0 (il:getwindowprop xcl::tty-window '
                                                           il:stack-position)))
                       (xcl::next-frame xcl::top-frame)
                       (xcl::frame-number 0)
                       xcl::interesting-p xcl::last-frame-consumed xcl::use-frame xcl::label)
                      (loop (when (null xcl::next-frame)
                                  (return))
                            (multiple-value-setq (xcl::interesting-p xcl::last-frame-consumed 
                                                        xcl::use-frame xcl::label)
                                   (funcall xcl::filter-fn xcl::next-frame))
                            (when (null xcl::last-frame-consumed)
                                                            
                                (setf xcl::last-frame-consumed xcl::next-frame))
                            (when xcl::interesting-p        
                                (when (null xcl::use-frame)
                                      (setf xcl::use-frame xcl::last-frame-consumed))
                                                             
                                (when (null xcl::label)
                                    (setf xcl::label (il:stkname xcl::use-frame))
                                    (if (member xcl::label '(eval il:eval il:apply apply)
                                               :test
                                               'eq)
                                        (setf xcl::label (il:stkarg 1 xcl::use-frame))))
                                                            
                                (loop (cond
                                         ((not (typep xcl::next-frame 'il:stackp))
                                          (error "~%Use-frame ~S not found" xcl::use-frame))
                                         ((xcl::stack-eql xcl::next-frame xcl::use-frame)
                                          (return))
                                         (t (incf xcl::frame-number)
                                            (setf xcl::next-frame (il:stknth -1 xcl::next-frame 
                                                                         xcl::next-frame)))))
                                                             
                                (xcl::collect-item (il:|create| il:bkmenuitem
                                                          il:label il:_ (let ((*print-level* 2)
                                                                              (*print-length* 3)
                                                                              (*print-escape* t)
                                                                              (*print-gensym* t)
                                                                              (*print-pretty* nil)
                                                                              (*print-circle* nil)
                                                                              (*print-radix* 10)
                                                                              (*print-array* nil)
                                                                              (il:*print-structure*
                                                                               nil))
                                                                             (prin1-to-string 
                                                                                    xcl::label))
                                                          il:bkmenuinfo il:_ xcl::frame-number
                                                          il:frame-name il:_ xcl::label)))
                                                             
                            (loop (cond
                                     ((not (typep xcl::next-frame 'il:stackp))
                                      (error "~%Last-frame-consumed ~S not found" 
                                             xcl::last-frame-consumed))
                                     ((prog1 (xcl::stack-eql xcl::next-frame xcl::last-frame-consumed
                                                    )
                                          (incf xcl::frame-number)
                                          (setf xcl::next-frame (il:stknth -1 xcl::next-frame 
                                                             
                                                                       xcl::next-frame)))
                                      (return)))))))
         (rest xcl::items)))

)
#+Xerox-Medley
(progn

(defun dbg::attach-backtrace-menu (&optional tty-window skip)
  (declare (special il:\\term.ofd il:backtracefont))
  (or tty-window (il:setq tty-window (il:wfromds (il:ttydisplaystream))))
  (prog (btw bkmenu
	     (tty-region (il:windowprop tty-window 'il:region))
	     ;; And, for the FORMAT below...
	     (*print-level* 2)
	     (*print-length* 3)
	     (*print-escape* t)
	     (*print-gensym* t)
	     (*print-pretty* nil)
	     (*print-circle* nil)
	     (*print-radix* 10)
	     (*print-array* nil)
	     (il:*print-structure* nil))
     (setq bkmenu
	   (il:|create| il:menu
	       il:items il:_ (dbg::collect-backtrace-items tty-window skip)
	       il:whenselectedfn il:_ 'dbg::backtrace-item-selected
	       il:menuoutlinesize il:_ 0
	       il:menufont il:_ il:backtracefont 
	       il:menucolumns il:_ 1
	       il:whenheldfn il:_
	       #'(il:lambda (item menu button)
		   (declare (ignore item menu))
		   (case button
		     (il:left
		      (il:promptprint
		       "Open a frame inspector on this stack frame"))
		     (il:middle
		      (il:promptprint "Inspect/Edit this function"))))))
     (cond ((setq btw
		  (dolist (atw  (il:attachedwindows tty-window))
		    ;; Test for an attached window that has a backtrace menu in
		    ;; it.
		    (when (and (setq btw (il:windowprop atw 'il:menu))
			   (eq (il:|fetch| (il:menu il:whenselectedfn)
				   il:|of| (car btw))
			       'dbg::backtrace-item-selected))
		      (return atw))))
	    ;; If there is alread a backtrace window, delete the old menu from
	    ;; it.
	    (il:deletemenu (car (il:windowprop btw 'il:menu)) nil btw)
	    (il:windowprop btw 'il:extent nil)
	    (il:clearw btw))
	   ((setq btw
		  (il:createw (dbg::region-next-to
			       (il:windowprop tty-window 'il:region)
			       (il:widthifwindow
				(il:imin (il:|fetch| (il:menu il:imagewidth)
					     il:|of| bkmenu)
					 il:|MaxBkMenuWidth|))
			       (il:|fetch| (il:region il:height)
				   il:|of| tty-region)
			       :left)))
					; put bt window at left of TTY
					; window unless ttywindow is
					; near left edge.
	    (il:attachwindow btw tty-window
			     (if (il:igreaterp (il:|fetch| (il:region il:left)
						   il:|of|
						   (il:windowprop btw
								  'il:region))
					       (il:|fetch| (il:region il:left)
						   il:|of| tty-region))
				 'il:right
				 'il:left)
			     nil
			     'il:localclose)
	    ;; So that button clicks will switch the TTY
	    (il:windowprop btw 'il:process
			   (il:windowprop tty-window 'il:process))))
     (il:addmenu bkmenu btw (il:|create| il:position
				il:xcoord il:_ 0 
				il:ycoord il:_ (- (il:windowprop btw 'il:height)
						  (il:|fetch| (il:menu 
							       il:imageheight)
						      il:|of| bkmenu))))
     ;; IL:ADDMENU sets up buttoneventfn for window that we don't
     ;; want.  We want to catch middle button events before the menu
     ;; handler, so that we can pop up edit/inspect menu for the frame
     ;; currently selected.  So replace the buttoneventfn, and can
     ;; nuke the cursorin and cursormoved guys, cause don't need them.
     (il:windowprop btw 'il:buttoneventfn 'dbg::backtrace-menu-buttoneventfn)
     (il:windowprop btw 'il:cursorinfn nil)
     (il:windowprop btw 'il:cursormovedfn nil)))

(defun dbg::collect-backtrace-items (tty-window skip)
  (xcl:with-collection
      ;;
      ;; There are a number of possibilities for the values returned by the
      ;; filter-fn.
      ;;
      ;; (1) INTERESTING-P is false, and the other values are all NIL.  This
      ;; is the simple case where the stack frame NEXT-POS should be ignored
      ;; completly, and processing should continue with the next frame.
      ;;
      ;; (2) INTERESTING-P is true, and the other values are all NIL.  This
      ;; is the simple case where the stack frame NEXT-POS should appear in
      ;; the backtrace as is, and processing should continue with the next
      ;; frame.
      ;;
      ;; [Note that these two cases take care of old values of the
      ;; filter-fn.]
      ;;
      ;; (3) INTERESTING-P is false, and LAST-FRAME-CONSUMED is a stack
      ;; frame.  In that case, ignore all stack frames from NEXT-POS to
      ;; LAST-FRAME-CONSUMED, inclusive.
      ;;
      ;; (4) INTERESTING-P is true, and LAST-FRAME-CONSUMED is a stack
      ;; frame.  In this case, the backtrace should include a single entry
      ;; coresponding to the frame USE-FRAME (which defaults to
      ;; LAST-FRAME-CONSUMED), and processing should continue with the next
      ;; frame after LAST-FRAME-CONSUMED.  If LABEL is non-NIL, it will be
      ;; the label that appears in the backtrace menu; otherwise the name of
      ;; USE-FRAME will be used (or the form being EVALed if the frame is an
      ;; EVAL frame).
      ;;
      (let* ((filter (cond ((null skip) #'xcl:true)
			   ((eq skip t) il:*short-backtrace-filter*)
			   (t skip)))
	     (top-frame (il:stknth 0 (il:getwindowprop tty-window
					      'dbg::stack-position)))
	     (next-frame top-frame)
	     (frame-number 0)
	     interestingp last-frame-consumed frame-to-use label-to-use)
	(loop (when (null next-frame) (return))
	      ;; Get the values of INTERSTINGP, LAST-FRAME-CONSUMED,
	      ;; FRAME-TO-USE, and LABEL-TO-USE
	      (multiple-value-setq (interestingp last-frame-consumed 
						 frame-to-use label-to-use)
		(funcall filter next-frame))
	      (when (null last-frame-consumed)
		(setf last-frame-consumed next-frame))
	      (when interestingp
		(when (null frame-to-use)
		  (setf frame-to-use last-frame-consumed))
		(when (null label-to-use)
		  (setf label-to-use (il:stkname frame-to-use))
		  (if (member label-to-use '(eval il:eval il:apply apply)
			      :test 'eq)
		      (setf label-to-use (il:stkarg 1 frame-to-use))))

		;; Walk the stack until we find the frame to use
		(loop (cond ((not (typep next-frame 'il:stackp))
			     (error "~%Use-frame ~S not found" frame-to-use))
			    ((xcl::stack-eql next-frame frame-to-use)
			     (return))
			    (t (incf frame-number)
			       (setf next-frame
				     (il:stknth -1 next-frame next-frame)))))

		;; Add the menu item to the list under construction
		(xcl:collect (il:|create| il:bkmenuitem
				 il:label il:_ (let ((*print-level* 2)
						     (*print-length* 3)
						     (*print-escape* t)
						     (*print-gensym* t)
						     (*print-pretty* nil)
						     (*print-circle* nil)
						     (*print-radix* 10)
						     (*print-array* nil)
						     (il:*print-structure* nil))
						 (prin1-to-string label-to-use))
				 il:bkmenuinfo il:_ frame-number
				 il:frame-name il:_ label-to-use)))

	      ;; Update NEXT-POS
	      (loop (cond ((not (typep next-frame 'il:stackp))
			   (error "~%Last-frame-consumed ~S not found" 
				  last-frame-consumed))
			  ((prog1
			       (xcl::stack-eql next-frame last-frame-consumed)
			     (incf frame-number)
			     (setf next-frame (il:stknth -1 next-frame
							 next-frame)))
			   (return))))))))

(defun dbg::backtrace-menu-buttoneventfn (window &aux menu)
  (setq menu (car (il:listp (il:windowprop window 'il:menu))))
  (unless (or (il:lastmousestate il:up) (null menu))
    (il:totopw window)
    (cond ((il:lastmousestate il:middle)
	   ;; look for a selected frame in this menu, and then pop up
	   ;; the editor invoke menu for that frame.  don't change the
	   ;; selection, just present the edit menu.
	   (let* ((selection (il:menu.handler menu
					  (il:windowprop window 'il:dsp)))
		  (tty-window (il:windowprop window 'il:mainwindow))
		  (last-pos (il:windowprop tty-window 'dbg::lastpos)))
                        
	     ;; don't have to worry about releasing POS because we
	     ;; only look at it here (nobody here hangs on to it)
	     ;; and we will be around for less time than LASTPOS. 
	     ;; The debugger is responsible for releasing LASTPOS.
	     (il:inspect/as/function (cond
				       ((and selection
					     (il:|fetch| (il:bkmenuitem il:frame-name)
						 il:|of| (car selection))))
				       ((and (symbolp (il:stkname last-pos))
					     (il:getd (il:stkname last-pos)))
					(il:stkname last-pos))
				       (t 'il:nill))
				     last-pos tty-window)))
	  (t (let ((selection (il:menu.handler menu
					   (il:windowprop window 'il:dsp))))
	       (when selection
		 (il:doselecteditem menu (car selection) (cdr selection))))))))

;; This function isn't really redefined, but it needs to be recomiled since we
;; changed the def'n of the BKMENUITEM record.

(defun dbg::backtrace-item-selected (item menu button)
  ;;When a frame name is selected in the backtrace menu, this is the function
  ;;that gets called.
  (declare (special il:brkenv) (ignore button))
  (let* ((frame-spec (il:|fetch| (il:bkmenuitem il:bkmenuinfo) il:|of| item))
	 (tty-window (il:windowprop (il:wfrommenu menu) 'il:mainwindow))
	 (bkpos (il:windowprop tty-window 'dbg::stack-position))
	 (pos (il:stknth (- frame-spec) bkpos)))
    (let ((lp (il:windowprop tty-window 'dbg::lastpos)))
      (and lp (il:stknth 0 pos lp)))
    ;; change the item selected from OLDITEM to ITEM.  Only do this on left
    ;; buttons now.  Middle just pops up the edit menu, doesn't select. -woz
    (let ((old-item (il:|fetch| (il:menu il:menuuserdata) il:|of| menu)))
      (when old-item (il:menudeselect old-item menu))
      (il:menuselect item menu))
    ;; Change the lexical environment so it is the one in effect as of this
    ;; frame.
    (il:process.eval (il:windowprop tty-window (quote dbg::process))
	       `(setq il:brkenv ',(il:find-lexical-environment pos))
	       t)
    (let ((frame-window (xcl:with-profile
			    (il:process.eval (il:windowprop tty-window
							    'il:process)
				       `(let ((profile (xcl:copy-profile
							(xcl:find-profile
							 "READ-PRINT"))))
					 (setf
					  (xcl::profile-entry-value
					   'xcl:*eval-function* profile)
					  xcl:*eval-function*)
					 (xcl:save-profile profile))
				       t)
			  (il:inspectw.create pos
				      #'(lambda (pos)
					  (dbg::stack-frame-properties pos t))
				      'dbg::stack-frame-fetchfn
				      'dbg::stack-frame-storefn
				      nil
				      'dbg::stack-frame-value-command
				      nil
				      (format nil "~S  Frame" (il:stkname pos))
				      nil (dbg::make-frame-inspect-window
					   tty-window)
				      'dbg::stack-frame-property))))
      (when (not (il:windowprop frame-window 'il:mainwindow))
	(il:attachwindow frame-window tty-window
			 (if (> (il:|fetch| (il:region il:bottom) il:|of|
				    (il:windowprop frame-window 'il:region))
				(il:|fetch| (il:region il:bottom) il:|of|
				    (il:windowprop tty-window 'il:region)))
			     'il:top 'il:bottom)
			 nil 'il:localclose)
	(il:windowaddprop frame-window 'il:closefn 'il:detachwindow)))))

)					;end of Xerox-Medley

(defun il:select.fns.editor (&optional function)
    ;; gives the user a menu choice of editors.
    (il:menu (il:|create| il:menu
		 il:items il:_ (cond ((il:ccodep function)
				      '((il:|InspectCode| 'il:inspectcode 
					 "Shows the compiled code.")
					(il:|DisplayEdit| 'ed 
					 "Edit it with the display editor")
					(il:|TtyEdit| 'il:ef 
					 "Edit it with the standard editor")))
				     ((il:closure-p function)
				      '((il:|Inspect| 'inspect 
					 "Inspect this object")))
				     (t '((il:|DisplayEdit| 'ed 
					   "Edit it with the display editor")
					  (il:|TtyEdit| 'il:ef 
					   "Edit it with the standard editor"))))
		 il:centerflg il:_ t)))

;; 


;; CLOS specific extensions to the debugger


;; There are some new things that act as functions, and that we want to be
;; able to edit from a backtrace window

(pushnew 'methods xcl::*function-types*)

(eval-when (eval compile load)
  (unless (generic-function-p (symbol-function 'il:inspect/as/function))
    (make-specializable 'il:inspect/as/function)))

(defmethod il:inspect/as/function (name stack-pointer debugger-window)
  ;; Calls an editor on function NAME.  STKP and WINDOW are the stack pointer
  ;; and window of the break in which this inspect command was called.
  (declare (ignore debugger-window))
  (let ((editor (il:select.fns.editor name)))
    (case editor
      ((nil) 
       ;; No editor chosen, so don't do anything
       nil)
      (il:inspectcode 
       ;; Inspect the compiled code
       (let ((frame (xcl::stack-pointer-frame stack-pointer)))
	 (if (and (il:stackp stack-pointer)
		  (xcl::stack-frame-valid-p frame))
	     (il:inspectcode (let ((code-base (xcl::stack-frame-fn-header frame)))
			       (cond ((eq (il:\\get-compiled-code-base name)
					  code-base)
				      name)
				     (t 
				      ;; Function executing in this frame is not
				      ;; the one in the definition cell of its
				      ;; name, so fetch the real code.  Have to
				      ;; pass a CCODEP
				      (il:make-compiled-closure code-base))))
                             nil nil nil (xcl::stack-frame-pc frame))
	     (il:inspectcode name))))
      (ed 
       ;; Use the standard editor.
       ;; This used to take care to apply the editor in the debugger
       ;; process, so forms evaluated in the editor happen in the
       ;; context of the break.  But that doesn't count for much any
       ;; more, now that lexical variables are the way to go.  Better to
       ;; use the LEX debugger command (thank you, Herbie) and
       ;; shift-select pieces of code from the editor into the debugger
       ;; window. 
       (ed name `(,@xcl::*function-types* :display)))
      (otherwise (funcall editor name)))))

(defmethod il:inspect/as/function ((name standard-object) stkp window)
  (when (il:menu (il:|create| il:menu
		     il:items il:_ '(("Inspect" t "Inspect this object"))))
    (inspect name)))

(defmethod il:inspect/as/function ((x standard-method) stkp window)
  (let* ((generic-function-name (slot-value (slot-value x 'generic-function)
					    'name))
	 (method-name (full-method-name x))
	 (editor (il:select.fns.editor method-name)))
    (il:allow.button.events)
    (case editor
      (ed (ed method-name '(:display methods)))
      (il:inspectcode (il:inspectcode (slot-value x 'function)))
      ((nil) nil)
      (otherwise (funcall editor method-name)))))

;; A replacement for the vanilla IL:INTERESTING-FRAME-P so we can see methods
;; and generic-functions on the stack.

(defun interesting-frame-p (stack-pos &optional interp-flag)
  ;; Return up to four values:  INTERESTING-P LAST-FRAME-CONSUMED USE-FRAME and
  ;; LABEL.  See the function IL:COLLECT-BACKTRACE-ITEMS for a full description
  ;; of how these values are used.
  (labels
      ((function-matches-frame-p (function frame)
	   "Is the function being called in this frame?"
	   (let* ((frame-name (il:stkname frame))
		  (code-being-run (cond
				    ((typep frame-name 'il:closure)
				     frame-name)
				    ((and (consp frame-name)
					  (eq 'il:\\interpreter
					      (xcl::stack-frame-name
					       (il:\\stackargptr frame))))
				     frame-name)
				    (t (xcl::stack-frame-fn-header
					(il:\\stackargptr frame))))))
	     (or (eq function code-being-run)
		 (and (typep function 'il:compiled-closure)
		      (eq (xcl::compiled-closure-fnheader function)
			  code-being-run)))))
       (generic-function-from-frame (frame)
	 "If this the frame of a generic function return the gf, otherwise
          return NIL."
	 ;; Generic functions are implemented as compiled closures.  On the
	 ;; stack, we only see the fnheader for the the closure.  This could
	 ;; be a discriminator code, or in the default method only case it
	 ;; will be the actual method function.  To tell if this is a generic
	 ;; function frame, we have to check very carefully to see if the
	 ;; right stuff is on the stack.  Specifically, the closure's ccode,
	 ;; and the first local variable has to be a ptrhunk big enough to be
	 ;; a FIN environment, and fin-env-fin of that ptrhunk has to point
	 ;; to a generic function whose ccode and environment match. 
	 (let ((n-args (il:stknargs frame))
	       (env nil)
	       (gf nil))
	   (if (and ;; is there at least one local?
		(> (il:stknargs frame t) n-args)
		;; and does the local contain something that might be
		;; the closure environment of a funcallable instance?
		(setf env (il:stkarg (1+ n-args) frame))
		;; and does the local contain something that might be
		;; the closure environment of a funcallable instance?
		(typep env *fin-env-type*)
		(setf gf (fin-env-fin env))
		;; whose fin-env-fin points to a generic function?
		(generic-function-p gf)
		;; whose environment is the same as env?
		(eq (xcl::compiled-closure-env gf) env)
		;; and whose code is the same as the code for this
		;; frame? 
		(function-matches-frame-p gf frame))
	       gf
	       nil))))
    (let ((frame-name (il:stkname stack-pos)))
      ;; See if there is a generic-function on the stack at this
      ;; location.
      (let ((gf (generic-function-from-frame stack-pos)))
	(when gf
	  (return-from interesting-frame-p (values t stack-pos stack-pos gf))))
      ;; See if this is an interpreted method.  The method body is
      ;; wrapped in a (BLOCK <function-name> ...).  We look for an
      ;; interpreted call to BLOCK whose block-name is the name of
      ;; generic-function.
      (when (and (eq frame-name 'eval)
		 (consp (il:stkarg 1 stack-pos))
		 (eq (first (il:stkarg 1 stack-pos)) 'block)
		 (symbolp (second (il:stkarg 1 stack-pos)))
		 (fboundp (second (il:stkarg 1 stack-pos)))
		 (generic-function-p
		     (symbol-function (second (il:stkarg 1 stack-pos)))))
	(let* ((form (il:stkarg 1 stack-pos))
	       (block-name (second form))
	       (generic-function (symbol-function block-name))
	       (methods (generic-function-methods (symbol-function block-name))))
	  ;; If this is really a method being called from a
	  ;; generic-function, the g-f should be no more than a
	  ;; few(?) frames up the stack.  Check for the method call
	  ;; by looking for a call to APPLY, where the function
	  ;; being applied is the code in one of the methods.
	  (do ((i 100 (1- i))
	       (previous-pos stack-pos current-pos)
	       (current-pos (il:stknth -1 stack-pos) (il:stknth -1 current-pos))
	       (found-method nil)
	       (method-pos))
	      ((or (null current-pos) (<= i 0)) nil)
	    (cond ((equalp generic-function
			   (generic-function-from-frame current-pos))
		   (if found-method
		       (return-from interesting-frame-p
			 (values t previous-pos method-pos found-method))
		       (return)))
		  (found-method nil)
		  ((eq (il:stkname current-pos) 'apply)
		   (dolist (method methods)
		     (when (eq (method-function method)
			       (il:stkarg 1 current-pos))
		       (setq method-pos current-pos)
		       (setq found-method method)
		       (return))))))))
      ;; Try to handle compiled methods
      (when (and (symbolp frame-name)
		 (not (fboundp frame-name))
		 (eq (il:chcon1 frame-name)
		     (il:charcode il:\())
		 (or (string-equal "(method " (symbol-name frame-name)
			      :start2 0 :end2 13)
		     (string-equal "(method " (symbol-name frame-name)
			      :start2 0 :end2 12)
		     (string-equal "(method " (symbol-name frame-name)
			      :start2 0 :end2 8)))
	;; Looks like a name that CLOS consed up.  See if there is a
	;; GF nearby up the stack.  If there is, use it to help
	;; determine which method we have.
	(do ((i 30 (1- i))
	     (current-pos (il:stknth -1 stack-pos)
			  (il:stknth -1 current-pos))
	     (gf))
	    ((or (null current-pos)
		 (<= i 0))
	     nil)
	  (setq gf (generic-function-from-frame current-pos))
	  (when gf
	    (dolist (method (generic-function-methods gf))
	      (when (function-matches-frame-p (method-function method)
					      stack-pos)
		(return-from interesting-frame-p
		  (values t stack-pos stack-pos method))))
	    (return))))
      ;; If we haven't already returned, use the default method.
      (xcl::interesting-frame-p stack-pos interp-flag))))


(setq il:*short-backtrace-filter* 'interesting-frame-p)

;;; Support for undo

 (defun undoable-setf-slot-value (object slot-name new-value)
    (if (slot-boundp object slot-name)
      (il:undosave (list 'undoable-setf-slot-value
                         object slot-name (slot-value object slot-name)))
      (il:undosave (list 'slot-makunbound object slot-name)))
    (setf (slot-value object slot-name) new-value))

  (setf (get 'slot-value :undoable-setf-inverse) 'undoable-setf-slot-value)


;;; Support for ?= and friends

;; The arglists for generic-functions are built using gensyms, and don't reflect
;; any keywords (they are all included in an &REST arg).  Rather then use the
;; arglist in the code, we use the one that CLOS kindly keeps in the generic-function.

(xcl:advise-function 'il:smartarglist
  '(if (and il:explainflg
	(symbolp il:fn)
	(fboundp il:fn)
	(generic-function-p (symbol-function il:fn)))
    (generic-function-pretty-arglist (symbol-function il:fn))
    (xcl:inner))
  :when :around :priority :last)

(setf (get 'defclass 'il:argnames)
      '(nil (class-name (#\{ superclass-name #\} #\*)
	     (#\{ slot-specifier #\} #\*)
	     #\{ slot-option #\} #\*)))

(setf (get 'defmethod 'il:argnames)
      '(nil (#\{ name #\| (setf name) #\} #\{ method-qualifier #\} #\*
	     specialized-lambda-list #\{ declaration #\| doc-string #\} #\*
	     #\{ form #\} #\*)))

;;; Prettyprinting support, the result of Harley Davis.

;; Support the standard Prettyprinter.  This is really minimal right now.  If
;; anybody wants to fix this, I'd be happy to include their code.  In fact,
;; there is almost no support for Commonlisp in the standard Prettyprinter, so
;; the field is wide open to hackers with time on their hands.


(setf (get 'defmethod :definition-print-template) ;Not quite right, since it
      '(:name :arglist :body))		          ; doesn't handle qualifiers,
		          		          ; but it will have to do.

(defun defclass-prettyprint (form)
  (let ((left (il:dspxposition))
	(char-width (il:charwidth (il:charcode x) *standard-output*)))
    (xcl:destructuring-bind (defclass name supers slots . options) form
      (princ "(")
      (prin1 defclass)
      (princ " ")
      (prin1 name)
      (princ " ")
      (if (null supers)
	  (princ "()")			;Print "()" instead of "nil"
	  (il:sequential.prettyprint (list supers) (il:dspxposition)))
      (if (null slots)
	  (progn (il:prinendline (+ left (* 4 char-width)) *standard-output*)
		 (princ "()"))
	  (il:sequential.prettyprint (list slots) (+ left (* 4 char-width))))
      (when options
	(il:sequential.prettyprint options (+ left (* 2 char-width))))
      (princ ")")
      nil)))

(let ((pprint-macro (assoc 'defclass il:prettyprintmacros)))
  (if (null pprint-macro)
      (push (cons 'defclass 'defclass-prettyprint)
	    il:prettyprintmacros)
      (setf (cdr pprint-macro) 'defclass-prettyprint)))

(defun binder-prettyprint (form)
  ;; Prettyprints expressions like MULTIPLE-VALUE-BIND and WITH-SLOTS
  ;; that are of the form (fn (var ...) form &rest body).
  ;; This code is far from correct, but it's better than nothing.
  (if (and (consp form)
	   (not (null (cdddr form))))
      ;; I have no idea what I'm doing here.  Seems I can copy and edit somebody
      ;; elses code without understanding it.
      (let ((body-indent (+ (il:dspxposition)
			    (* 2 (il:charwidth (il:charcode x)
					       *standard-output*))))
	    (form-indent (+ (il:dspxposition)
			    (* 4 (il:charwidth (il:charcode x)
					       *standard-output*)))))
	(princ "(")
	(prin1 (first form))
	(princ " ")
	(il:superprint (second form) form nil *standard-output*)
	(il:sequential.prettyprint (list (third form)) form-indent)
	(il:sequential.prettyprint (cdddr form) body-indent)
	(princ ")")
	nil)				;Return NIL to indicate that we did
					; the printing
      t))				;Return true to use default printing


(dolist (fn '(multiple-value-bind with-accessors with-slots))
  (let ((pprint-macro (assoc fn 'il:prettyprintmacros)))
    (if (null pprint-macro)
	(push (cons fn 'binder-prettyprint)
	      il:prettyprintmacros)
	(setf (cdr pprint-macro) 'binder-prettyprint))))



;; SEdit has its own prettyprinter, so we need to support that too.  This is due
;; to Harley Davis.  Really.

(push (cons :slot-spec
	    '(((sedit::prev-keyword? (sedit::next-inline? 1 break sedit::from-indent . 1)
		break sedit::from-indent . 0)
	       (sedit::set-indent . 1)
	       (sedit::next-inline? 1 break sedit::from-indent . 1)
	       (sedit::prev-keyword? (sedit::next-inline? 1 break sedit::from-indent . 1)
		break sedit::from-indent . 0))
	      ((sedit::prev-keyword? (sedit::next-inline? 1 break sedit::from-indent . 1)
		break sedit::from-indent . 0)
	       (sedit::set-indent . 1)
	       (sedit::next-inline? 1 break sedit::from-indent . 1)
	       (sedit::prev-keyword? (sedit::next-inline? 1 break sedit::from-indent . 1)
		break sedit::from-indent . 0))))
    sedit:*indent-alist*)

(setf (sedit:get-format :slot-spec)
      '(:indent :slot-spec :inline t))

(setf (sedit:get-format :slot-spec-list)
      '(:indent :binding-list :args (:slot-spec) :inline nil))

(setf (sedit:get-format 'defclass)
      '(:indent ((2) 1)
	:args (:keyword nil nil :slot-spec-list nil)
	:sublists (4)))

(setf (sedit:get-format 'defmethod)
      '(:indent ((2))
	:args (:keyword nil :lambda-list nil)
	:sublists (3)))

(setf (sedit:get-format 'defgeneric) 'defun)

(setf (sedit:get-format 'generic-flet) 'flet)

(setf (sedit:get-format 'generic-labels) 'flet)

(setf (sedit:get-format 'call-next-method)
      '(:indent (1) :args (:keyword nil)))

(setf (sedit:get-format 'symbol-macrolet) 'let)

(setf (sedit:get-format 'with-accessors)
      '(:indent ((1) 1)
	:args (:keyword :binding-list nil)
	:sublists (2)
	:miser :never))

(setf (sedit:get-format 'with-slots) 'with-accessors)

(setf (sedit:get-format 'make-instance)
      '(:indent ((1))
	:args (:keyword nil :slot-spec-list)))

(setf (sedit:get-format '*make-instance) 'make-instance)

;;; PrettyFileIndex stuff, the product of Harley Davis.

(defvar *pfi-class-type* '(class defclass pfi-class-namer))

(defvar *pfi-method-type* '(method defmethod pfi-method-namer)
  "Handles method for prettyfileindex")

(defvar *pfi-index-accessors* nil
  "t -> each slot accessor gets a listing in the index.")

(defvar *pfi-method-index* :group
  ":group, :separate, :both, or nil")

(defun pfi-add-class-type ()
  (pushnew *pfi-class-type* il:*pfi-types*))

(defun pfi-add-method-type ()
  (pushnew *pfi-method-type* il:*pfi-types*))

(defun pfi-class-namer (expression entry)
  (let ((class-name (second expression)))
    ;; Following adds all slot readers/writers/accessors as separate entries in
    ;; the index.  Probably a mistake.
    (if *pfi-index-accessors*
	(let ((slot-list (fourth expression))
	      (accessor-names nil))
	  (labels ((add-accessor (method-index name-index)
		     (push (case *pfi-method-index*
			     (:group method-index)
			     (:separate name-index)
			     ((t :both) (list method-index name-index))
			     ((nil) nil)
			     (otherwise (error "Illegal value for *pfi-method-index*: ~S"
					       *pfi-method-index*)))
			   accessor-names))
		   (add-reader (reader-name)
		     (add-accessor `(method (,reader-name (,class-name)))
				   `(,reader-name (,class-name))))
		   (add-writer (writer-name)
		     (add-accessor `(method ((setf ,writer-name) (t ,class-name)))
				   `((setf ,writer-name) (t ,class-name)))))
	    (dolist (slot-def slot-list)
	      (do* ((rest-slot-args (cdr slot-def) (cddr rest-slot-args))
		    (slot-arg (first  rest-slot-args)  (first rest-slot-args)))
		   ((null rest-slot-args))
 		(case slot-arg
		  (:reader (add-reader (second rest-slot-args)))
		  (:writer (add-writer (second rest-slot-args)))
		  (:accessor (add-reader (second rest-slot-args))
			     (add-writer (second rest-slot-args)))
		  (otherwise nil))))
	    (cons `(class (,class-name)) accessor-names)))
	class-name)))

(defun pfi-method-namer (expression entry)
  (let ((method-name (second expression))
	(specializers nil)
	(qualifiers nil)
	lambda-list)
    (do* ((rest-qualifiers (cddr expression) (cdr rest-qualifiers))
	  (qualifier (first rest-qualifiers) (first rest-qualifiers)))
	 ((listp qualifier) (setq lambda-list qualifier)
	                    (setq qualifiers (reverse qualifiers)) qualifiers)
      (push qualifier qualifiers))
    (do* ((rest-lambda-list lambda-list (cdr rest-lambda-list))
	  (arg (first rest-lambda-list) (first rest-lambda-list)))
	 ((or (member arg lambda-list-keywords) (null rest-lambda-list))
	  (setq specializers (reverse specializers)))
      (push (if (listp arg) (second arg) t) specializers))
    (let ((method-index `(method (,method-name ,@qualifiers ,specializers)))
	  (name-index `(,method-name ,@qualifiers ,specializers)))
      (case *pfi-method-index*
	(:group method-index)
	(:separate name-index)
	((t :both) (list method-index name-index))
	((nil) nil)
	(otherwise (error "Illegal value for *pfi-method-index*: ~S" *pfi-method-index*))))))

(defun pfi-install-clos ()
  (pfi-add-method-type)
  (pfi-add-class-type))

(eval-when (eval load)
  (when (boundp (quote il:*pfi-types*))
    (pfi-install-clos))
  )
