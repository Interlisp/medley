;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-
;;;. Copyright (c) 1991 by Venue


(in-package "CLOS")

(eval-when (compile load eval)
       (defvar *defclass-times* '(load eval compile))	;Probably have to change this
						;if you use defconstructor.
(defvar *defmethod-times*  '(load eval compile))
(defvar *defgeneric-times* '(load eval compile))
)


;;; Convert a function name to its standard setf function name.  We have to do this hack because not
;;; all Common Lisps have yet converted to having setf function specs. In a port that does have setf
;;; function specs you can use those just by making the obvious simple changes to these functions. 
;;; The rest of CLOS believes that there are function names like (SETF <foo>), this is the only place
;;; that knows about this hack. 


(eval-when (compile load eval)
       (defvar *setf-function-names* (make-hash-table :size 200 :test #'eq))
(defun get-setf-function-name (name)
  (or (gethash name *setf-function-names*)
      (setf (gethash name *setf-function-names*)
	    (intern (format nil
			    "SETF ~A ~A"
			    (package-name (symbol-package name))
			    (symbol-name name))
		    *the-clos-package*))))

;;;
;;; Call this to define a setf macro for a function with the same behavior as
;;; specified by the SETF function cleanup proposal.  Specifically, this will
;;; cause: (SETF (FOO a b) x) to expand to (|SETF FOO| x a b).
;;;
;;; do-standard-defsetf                  A macro interface for use at top level
;;;                                      in files.  Unfortunately, users may
;;;                                      have to use this for a while.
;;;                                      
;;; do-standard-defsetfs-for-defclass    A special version called by defclass.
;;; 
;;; do-standard-defsetf-1                A functional interface called by the
;;;                                      above, defmethod and defgeneric.
;;;                                      Since this is all a crock anyways,
;;;                                      users are free to call this as well.
;;;
(defmacro do-standard-defsetf (&rest function-names)
  `(eval-when (compile load eval)
     (dolist (fn-name ',function-names) (do-standard-defsetf-1 fn-name))))

(defun do-standard-defsetfs-for-defclass (accessors)
  (dolist (name accessors) (do-standard-defsetf-1 name)))

(defun do-standard-defsetf-1 (function-name)
  (unless (setfboundp function-name)
    (let* ((setf-function-name (get-setf-function-name function-name)))
    
  (flet ((setf-expander (body env)
	       (declare (ignore env))
	       (let ((temps
		       (mapcar #'(lambda (x) (declare (ignore x)) (gensym))
			       (cdr body)))
		     (forms (cdr body))
		     (vars (list (gensym))))
		 (values temps
			 forms
			 vars
			 `(,setf-function-name ,@vars ,@temps)
			 `(,function-name ,@temps)))))
	(let ((setf-method-expander (intern (concatenate 'string
						         (symbol-name function-name)
						         "-setf-expander")
				     (symbol-package function-name))))
	  (setf (get function-name :setf-method-expander) setf-method-expander
		(symbol-function setf-method-expander) #'setf-expander)))

     )))
(defun setfboundp (symbol)
(or (get symbol :setf-inverse)
	       (get symbol 'il:setf-inverse)
	       (get symbol 'il:setfn)
	       (get symbol :shared-setf-inverse)
	       (get symbol :setf-method-expander)
	       (get symbol 'il:setf-method-expander)))
)

                                                             ; eval-when



;;; CLOS, like user code, must endure the fact that we don't have a properly working setf.  Many
;;; things work because they get mentioned by a defclass or defmethod before they are used, but
;;; others have to be done by hand. 


(do-standard-defsetf 
	class-wrapper                           ; ***
     generic-function-name 
	method-function-plist 
	method-function-get 
	gdefinition 
     slot-value-using-class)

(defsetf slot-value set-slot-value)


;;; This is like fdefinition on the Lispm.  If Common Lisp had something like function specs I
;;; wouldn't need this.  On the other hand, I don't like the way this really works so maybe function
;;; specs aren't really right either? I also don't understand the real implications of a Lisp-1 on
;;; this sort of thing.  Certainly some of the lossage in all of this is because these SPECs name
;;; global definitions. Note that this implementation is set up so that an implementation which has
;;; a 'real' function spec mechanism can use that instead and in that way get rid of setf generic
;;; function names. 


(defmacro parse-gspec (spec (non-setf-var . non-setf-case)
                            (setf-var . setf-case))
              (once-only (spec)
              `(cond ((symbolp ,spec)
                      (let ((,non-setf-var ,spec))
                           ,@non-setf-case))
                     ((and (listp ,spec)
                           (eq (car ,spec)
                               'setf)
                           (symbolp (cadr ,spec)))
                      (let ((,setf-var (cadr ,spec)))
                           ,@setf-case))
                     (t (error "Can't understand ~S as a generic function specifier.~%~
               It must be either a symbol which can name a function or~%~
               a list like ~S, where the car is the symbol ~S and the cadr~%~
               is a symbol which can name a generic function." ,spec '(setf <foo>)
                               'setf)))))


;;; If symbol names a function which is traced or advised, return the unadvised, traced etc.
;;; definition.  This lets me get at the generic function object even when it is traced. 


(defun unencapsulated-fdefinition (symbol)
       (il:virginfn symbol))


;;; If symbol names a function which is traced or advised, redefine the `real' definition without
;;; affecting the advise. 


(defun fdefine-carefully (symbol new-definition)
       (let ((advisedp (member symbol il:advisedfns :test #'eq))
             (brokenp (member symbol il:brokenfns :test #'eq)))
            
            ;; In XeroxLisp (late of envos) tracing is implemented as a special case of "breaking". 
            ;; Advising, however, is treated specially. 
            (xcl:unadvise-function symbol :no-error t)
            (xcl:unbreak-function symbol :no-error t)
            (setf (symbol-function symbol)
                  new-definition)
            (when brokenp (xcl:rebreak-function symbol))
            (when advisedp (xcl:readvise-function symbol)))
       new-definition)

(defun gboundp (spec)
       (parse-gspec spec (name (fboundp name))
              (name (fboundp (get-setf-function-name name)))))

(defun gmakunbound (spec)
       (parse-gspec spec (name (fmakunbound name))
              (name (fmakunbound (get-setf-function-name name)))))

(defun gdefinition (spec)
       (parse-gspec spec (name (or (macro-function name)
                                                             ; ??
                                   (unencapsulated-fdefinition name)))
              (name (unencapsulated-fdefinition (get-setf-function-name name)))))

(defun SETF\ CLOS\ GDEFINITION (new-value spec)
       (parse-gspec spec (name (fdefine-carefully name new-value))
              (name (fdefine-carefully (get-setf-function-name name)
                           new-value))))


;;; These functions are a pale imitiation of their namesake.  They accept class objects or types
;;; where they should. 


(defun *typep (object type)
       (if (classp type)
           (let ((class (class-of object)))
                (if class
                    (memq type (class-precedence-list class))
                    nil))
           (let ((class (find-class type nil)))
                (if class
                    (*typep object class)
                    (typep object type)))))

(defun *subtypep (type1 type2)
       (let ((c1 (if (classp type1)
                     type1
                     (find-class type1 nil)))
             (c2 (if (classp type2)
                     type2
                     (find-class type2 nil))))
            (if (and c1 c2)
                (memq c2 (class-precedence-list c1))
                (if (or c1 c2)
                    nil
                                                             ; This isn't quite right, but...
                    (subtypep type1 type2)))))

(defun do-satisfies-deftype (name predicate)
       (let* ((specifier `(satisfies ,predicate))
              (expand-fn #'(lambda (&rest ignore)
                                  (declare (ignore ignore))
                                  specifier)))
             
             ;; Specific ports can insert their own way of doing this.  Many ports may find the
             ;; expand-fn defined above useful. 
             (or 
                 ;; This is the default for ports for which we don't know any better.  Note that for
                 ;; most ports, providing this definition should just speed up class definition.  It
                 ;; shouldn't have an effect on performance of most user code. 
                 (eval `(deftype ,name nil '(satisfies ,predicate))))))

(defun make-type-predicate-name (name)
       (intern (format nil "TYPE-PREDICATE ~A ~A" (package-name (symbol-package name))
                      (symbol-name name))
              *the-clos-package*))

(proclaim '(special *the-class-t* *the-class-vector* *the-class-symbol* *the-class-string* 
                  *the-class-sequence* *the-class-rational* *the-class-ratio* *the-class-number* 
                  *the-class-null* *the-class-list* *the-class-integer* *the-class-float* 
                  *the-class-cons* *the-class-complex* *the-class-character* *the-class-bit-vector* 
                  *the-class-array* *the-class-standard-object* *the-class-class* *the-class-method*
                  *the-class-generic-function* *the-class-standard-class* *the-class-standard-method*
                  *the-class-standard-generic-function* 
                  *the-class-standard-effective-slot-definition* *the-eslotd-standard-class-slots*))

(proclaim '(special *the-wrapper-of-t* *the-wrapper-of-vector* *the-wrapper-of-symbol* 
                  *the-wrapper-of-string* *the-wrapper-of-sequence* *the-wrapper-of-rational* 
                  *the-wrapper-of-ratio* *the-wrapper-of-number* *the-wrapper-of-null* 
                  *the-wrapper-of-list* *the-wrapper-of-integer* *the-wrapper-of-float* 
                  *the-wrapper-of-cons* *the-wrapper-of-complex* *the-wrapper-of-character* 
                  *the-wrapper-of-bit-vector* *the-wrapper-of-array*))

(defvar *built-in-class-symbols* nil)

(defvar *built-in-wrapper-symbols* nil)

(defun get-built-in-class-symbol (class-name)
       (or (cadr (assq class-name *built-in-class-symbols*))
           (let ((symbol (intern (format nil "*THE-CLASS-~A*" (symbol-name class-name))
                                *the-clos-package*)))
                (push (list class-name symbol)
                      *built-in-class-symbols*)
                symbol)))

(defun get-built-in-wrapper-symbol (class-name)
       (or (cadr (assq class-name *built-in-wrapper-symbols*))
           (let ((symbol (intern (format nil "*THE-WRAPPER-OF-~A*" (symbol-name class-name))
                                *the-clos-package*)))
                (push (list class-name symbol)
                      *built-in-wrapper-symbols*)
                symbol)))

(pushnew 'class *variable-declarations*)

(pushnew 'variable-rebinding *variable-declarations*)

(defun variable-class (var env)
       (caddr (variable-declaration 'class var env)))

(defvar *boot-state* nil)
                                                             ; NIL EARLY BRAID COMPLETE 


(eval-when (load eval)
       (when (eq *boot-state* 'complete)
             (error "Trying to load (or compile) CLOS in an environment in which it~%~
            has already been loaded.  This doesn't work, you will have to~%~
            get a fresh lisp (reboot) and then load CLOS."))
       (when *boot-state* (cerror "Try loading (or compiling) CLOS anyways." "Trying to load (or compile) CLOS in an environment in which it~%~
             has already been partially loaded.  This may not work, you may~%~
             need to get a fresh lisp (reboot) and then load CLOS.")))


;;; This is used by combined methods to communicate the next methods to the methods they call.  This
;;; variable is captured by a lexical variable of the methods to give it the proper lexical scope. 


(defvar *next-methods* nil)

(defvar *not-an-eql-specializer* '(not-an-eql-specializer))

(defvar *umi-gfs*)

(defvar *umi-complete-classes*)

(defvar *umi-reorder*)

(defvar *invalidate-discriminating-function-force-p* nil)

(defvar *invalid-dfuns-on-stack* nil)

(defvar *standard-method-combination*)

(defvar *slotd-unsupplied* (list '*slotd-unsupplied*))

                                                             ; ***


(defmacro define-gf-predicate (predicate &rest classes)
       `(progn (defmethod ,predicate ((x t))
                      nil)
               ,@(mapcar #'(lambda (c)
                                  `(defmethod ,predicate ((x ,c))
                                          t))
                        classes)))

(defmacro plist-value (object name)
       `(with-slots (plist)
               ,object
               (getf plist ,name)))

(defsetf plist-value (object name)
       (new-value)
       (once-only (new-value)
              `(with-slots (plist)
                      ,object
                      (if ,new-value
                          (setf (getf plist ,name)
                                ,new-value)
                          (progn (remf plist ,name)
                                 nil)))))

(defvar *built-in-classes* 

       ;; name       supers     subs                     cdr of cpl 
       '((number (t) (complex float rational)
                (t))
         (complex (number)
                nil
                (number t))
         (float (number)
                nil
                (number t))
         (rational (number)
                (integer ratio)
                (number t))
         (integer (rational)
                nil
                (rational number t))
         (ratio (rational)
                nil
                (rational number t))
         (sequence (t)
                (list vector)
                (t))
         (list (sequence)
               (cons null)
               (sequence t))
         (cons (list)
               nil
               (list sequence t))
         (array (t)
                (vector)
                (t))
         (vector (array sequence)
                (string bit-vector)
                (array sequence t))
         (string (vector)
                nil
                (vector array sequence t))
         (bit-vector (vector)
                nil
                (vector array sequence t))
         (character (t)
                nil
                (t))
         (symbol (t)
                (null)
                (t))
         (null (symbol)
               nil
               (symbol list sequence t))))


;;; The classes that define the kernel of the metabraid. 


(defclass t nil nil (:metaclass built-in-class))

(defclass standard-object (t)
       nil)

(defclass metaobject (standard-object)
       nil)

(defclass specializer (metaobject)
       nil)

(defclass definition-source-mixin (standard-object)
       ((source :initform (load-truename)
               :reader definition-source :initarg :definition-source)))

(defclass plist-mixin (standard-object)
       ((plist :initform nil)))

(defclass documentation-mixin (plist-mixin)
       nil)

(defclass dependent-update-mixin (plist-mixin)
       nil)


;;; The class CLASS is a specified basic class.  It is the common superclass of any kind of class. 
;;; That is any class that can be a metaclass must have the class CLASS in its class precedence
;;; list. 


(defclass class (documentation-mixin dependent-update-mixin definition-source-mixin specializer)
       ((name :initform nil :initarg :name :accessor class-name)
        (direct-superclasses :initform nil :reader class-direct-superclasses)
        (direct-subclasses :initform nil :reader class-direct-subclasses)
        (direct-methods :initform (cons nil nil))))


;;; The class CLOS-CLASS is an implementation-specific common superclass of all specified subclasses
;;; of the class CLASS. 


(defclass clos-class (class)
       ((class-precedence-list :initform nil)
        (wrapper :initform nil)))


;;; The class STD-CLASS is an implementation-specific common superclass of the classes
;;; STANDARD-CLASS and FUNCALLABLE-STANDARD-CLASS. 


(defclass std-class (clos-class)
       ((direct-slots :initform nil :accessor class-direct-slots)
        (slots :initform nil :accessor class-slots)
        (no-of-instance-slots                                ; *** MOVE TO WRAPPER ***
               :initform 0 :accessor class-no-of-instance-slots)
        (prototype :initform nil)))

(defclass standard-class (std-class)
       nil)

(defclass funcallable-standard-class (std-class)
       nil)

(defclass forward-referenced-class (clos-class)
       nil)

(defclass built-in-class (clos-class)
       nil)


;;; Slot definitions. Note that throughout CLOS, "SLOT-DEFINITION" is abbreviated as "SLOTD". 


(defclass slot-definition (metaobject)
       nil)

(defclass direct-slot-definition (slot-definition)
       nil)

(defclass effective-slot-definition (slot-definition)
       nil)
;
(defclass standard-slot-definition (slot-definition)
       ((name :initform nil :accessor slotd-name)
        (initform :initform *slotd-unsupplied* :accessor slotd-initform)
        (initfunction :initform *slotd-unsupplied* :accessor slotd-initfunction)
        (readers :initform nil :accessor slotd-readers)
        (writers :initform nil :accessor slotd-writers)
        (initargs :initform nil :accessor slotd-initargs)
        (allocation :initform nil :accessor slotd-allocation)
        (type :initform nil :accessor slotd-type)
        (documentation :initform "" :initarg :documentation)
        (class :initform nil :accessor slotd-class)
        (instance-index :initform nil :accessor slotd-instance-index)))

(defclass standard-direct-slot-definition (standard-slot-definition direct-slot-definition)
       nil)

                                                             ; Adding slots here may involve extra
                                                             ; work to the code in braid.lisp 


(defclass standard-effective-slot-definition (standard-slot-definition effective-slot-definition)
       nil)

                                                             ; Adding slots here may involve extra
                                                             ; work to the code in braid.lisp 


(defclass eql-specializer (specializer)
       ((object :initarg :object :reader eql-specializer-object)))


;;; 


(defmacro dolist-carefully ((var list improper-list-handler)
                            &body body)
       `(let ((,var nil)
              (.dolist-carefully. ,list))
             (loop (when (null .dolist-carefully.)
                         (return nil))
                   (if (consp .dolist-carefully.)
                       (progn (setq ,var (pop .dolist-carefully.))
                              ,@body)
                       (,improper-list-handler)))))

(defun legal-std-documentation-p (x)
       (if (or (null x)
               (stringp x))
           t
           "a string or NULL"))

(defun legal-std-lambda-list-p (x)
       (declare (ignore x))
       t)

(defun legal-std-method-function-p (x)
       (if (functionp x)
           t
           "a function"))

(defun legal-std-qualifiers-p (x)
       (flet ((improper-list nil (return-from legal-std-qualifiers-p "Is not a proper list.")))
             (dolist-carefully (q x improper-list)
                    (let ((ok (legal-std-qualifier-p q)))
                         (unless (eq ok t)
                             (return-from legal-std-qualifiers-p (format nil "Contains ~S which ~A" q
                                                                        ok)))))
             t))

(defun legal-std-qualifier-p (x)
       (if (and x (atom x))
           t
           "is not a non-null atom"))

(defun legal-std-slot-name-p (x)
       (cond ((not (symbolp x))
              "is not a symbol and so cannot be bound")
             ((keywordp x)
              "is a keyword and so cannot be bound")
             ((memq x '(t nil))
              "cannot be bound")
             (t t)))

(defun legal-std-specializers-p (x)
       (flet ((improper-list nil (return-from legal-std-specializers-p "Is not a proper list.")))
             (dolist-carefully (s x improper-list)
                    (let ((ok (legal-std-specializer-p s)))
                         (unless (eq ok t)
                             (return-from legal-std-specializers-p (format nil "Contains ~S which ~A"
                                                                          s ok)))))
             t))

(defun legal-std-specializer-p (x)
       (if (or (classp x)
               (eql-specializer-p x))
           t
           "is neither a class object nor an eql specializer"))
