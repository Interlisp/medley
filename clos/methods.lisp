;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;;. Copyright (c) 1991 by Venue

(in-package "CLOS")



;;; METHODS Methods themselves are simple inanimate objects.  Most properties of methods are
;;; immutable, methods cannot be reinitialized.  The following properties of methods can be changed:
;;; METHOD-GENERIC-FUNCTION METHOD-FUNCTION            ?? 

(defclass method (metaobject) ())

(defclass standard-method (definition-source-mixin documentation-mixin method)
     ((generic-function
	:initform nil	
	:accessor method-generic-function)
;     (qualifiers
;	:initform ()
;	:initarg  :qualifiers
;	:reader method-qualifiers)
      (specializers
	:initform ()
	:initarg  :specializers
	:reader method-specializers)
      (lambda-list
	:initform ()
	:initarg  :lambda-list
	:reader method-lambda-list)
      (function
	:initform nil
	:initarg :function
	:reader method-function)		;writer defined by hand
;     (documentation
;	:initform ""
;	:initarg  :documentation)
      ))

(defclass standard-accessor-method (standard-method)
     ((slot-name :initform nil
		 :initarg :slot-name)))


;;; This method has to be defined by hand!  Don't try to define it using :accessor or :reader.  It
;;; can't be an automatically generated reader method because that would break the way the special
;;; discriminator code which uses this feature works.  -- Probably false now 8/21 


(defmethod accessor-method-slot-name ((m standard-accessor-method))
       (slot-value m 'slot-name))

(defclass standard-reader-method (standard-accessor-method) ())
(defclass standard-writer-method (standard-accessor-method) ())

(defmethod print-object ((method standard-method)
                         stream)
       (printing-random-thing (method stream)
              (let ((generic-function (method-generic-function method))
                    (class-name (capitalize-words (class-name (class-of method)))))
                   (format stream "~A ~S ~{~S ~}~:S" class-name (and generic-function (
                                                                                generic-function-name
                                                                                       
                                                                                     generic-function
                                                                                       ))
                          (method-qualifiers method)
                          (unparse-specializers method)))))

(defmethod print-object ((method standard-accessor-method)
                         stream)
       (printing-random-thing (method stream)
              (let ((generic-function (method-generic-function method))
                    (class-name (capitalize-words (class-name (class-of method)))))
                   (format stream "~A ~S, slot:~S, ~:S" class-name (and generic-function (
                                                                                generic-function-name
                                                                                          
                                                                                     generic-function
                                                                                          ))
                          (accessor-method-slot-name method)
                          (unparse-specializers method)))))


;;; INITIALIZATION Error checking is done in before methods.  Because of the simplicity of standard
;;; method objects the standard primary method can fill the slots. Methods are not reinitializable. 


(defmethod reinitialize-instance ((method standard-method)
                                  &rest initargs)
       (declare (ignore initargs))
       (error 
        "Attempt to reinitialize the method ~S.~%~
          Method objects cannot be reinitialized." method))

(defmethod shared-initialize :before ((method standard-method)
                                      slot-names &key qualifiers lambda-list specializers function 
                                      documentation)
       (declare (ignore slot-names))
       (flet ((lose (initarg value string)
                    (error "When initializing the method ~S:~%~
                   The ~S initialization argument was: ~S.~%~
                   which ~A." method initarg value string)))
             (let ((check-qualifiers (legal-std-qualifiers-p qualifiers))
                   (check-lambda-list (legal-std-lambda-list-p lambda-list))
                   (check-specializers (legal-std-specializers-p specializers))
                   (check-function (legal-std-method-function-p function))
                   (check-documentation (legal-std-documentation-p documentation)))
                  (unless (eq check-qualifiers t)
                         (lose :qualifiers qualifiers check-qualifiers))
                  (unless (eq check-lambda-list t)
                         (lose :lambda-list lambda-list check-lambda-list))
                  (unless (eq check-specializers t)
                         (lose :specializers specializers check-specializers))
                  (unless (eq check-function t)
                         (lose :function function check-function))
                  (unless (eq check-documentation t)
                         (lose :documentation documentation check-documentation)))))

(defmethod shared-initialize :before ((method standard-accessor-method)
                                      slot-names &key slot-name)
       (declare (ignore slot-names))
       (let ((legalp (legal-std-slot-name-p slot-name)))
            (unless (eq legalp t)
                   (error "The value of the :SLOT-NAME initarg ~A." legalp))))

(defmethod shared-initialize :after ((method standard-method)
                                     slot-names &key qualifiers)
       (setf (plist-value method 'qualifiers)
             qualifiers))

(defmethod method-qualifiers ((method standard-method))
       (plist-value method 'qualifiers))

(defclass generic-function (dependent-update-mixin
			    definition-source-mixin
			    metaobject)
     ()
  (:metaclass funcallable-standard-class))
    
(defclass standard-generic-function (generic-function)
     ((name
	:initform nil
	:initarg :name
	:accessor generic-function-name)
      (methods
	:initform ()
	:accessor generic-function-methods)
      (method-class
	:initarg :method-class
	:accessor generic-function-method-class)
      (method-combination
	:initarg :method-combination
	:accessor generic-function-method-combination)

;     (permutation
;	:accessor gf-permutation)
      (arg-info
	:initform ()
	:accessor gf-arg-info)
      (dfun-state
	:initform ()
	:accessor gf-dfun-state)
      (effective-method-functions		;((methods . fn) ..)
	:initform ()
	:accessor gf-effective-method-functions)
      (valid-p
	:initform nil
	:accessor gf-valid-p)
      (pretty-arglist
	:initform ()
	:accessor gf-pretty-arglist)
      )
  (:metaclass funcallable-standard-class)
  (:default-initargs :method-class *the-class-standard-method*
		     :method-combination *standard-method-combination*))


(define-gf-predicate generic-function-p generic-function)

(define-gf-predicate method-p method)

(define-gf-predicate standard-accessor-method-p standard-accessor-method)

(define-gf-predicate standard-reader-method-p standard-reader-method)

(define-gf-predicate standard-writer-method-p standard-writer-method)

(defvar *the-class-method* (find-class 'method))

(defvar *the-class-standard-method* (find-class 'standard-method))

(defvar *the-class-generic-function* (find-class 'generic-function))

(defvar *the-class-standard-generic-function* (find-class 'standard-generic-function))

(defmethod print-object ((generic-function generic-function)
                         stream)
       (named-object-print-function generic-function stream (list (length (generic-function-methods
                                                                           generic-function)))))

(defmethod shared-initialize :before ((generic-function standard-generic-function)
                                      slot-names &key (name nil namep)
                                      (lambda-list nil lambda-list-p)
                                      argument-precedence-order declarations documentation
                                      (method-class nil method-class-supplied-p)
                                      (method-combination nil method-combination-supplied-p))
       (declare (ignore slot-names declarations argument-precedence-order lambda-list lambda-list-p 
                       name))
       (when namep (set-function-name generic-function name))
       (flet ((initarg-error (initarg value string)
                     (error "When initializing the generic-function ~S:~%~
                   The ~S initialization argument was: ~A.~%~
                   It must be ~A." generic-function initarg value string)))
             (cond (method-class-supplied-p (when (symbolp method-class)
                                                (setq method-class (find-class method-class)))
                          (unless (and (classp method-class)
                                       (*subtypep method-class *the-class-method*))
                                 (initarg-error :method-class method-class 
                                        "a subclass of the class METHOD"))
                          (setf (slot-value generic-function 'method-class)
                                method-class))
                   ((slot-boundp generic-function 'method-class))
                   (t (initarg-error :method-class "not supplied" "a subclass of the class METHOD")))
             (cond (method-combination-supplied-p (unless (method-combination-p method-combination)
                                                         (initarg-error :method-combination 
                                                                method-combination 
                                                                "a method combination object")))
                   ((slot-boundp generic-function 'method-combination))
                   (t (initarg-error :method-combination "not supplied" "a method combination object"
                             )))))

(defmethod initialize-instance :after ((gf standard-generic-function)
                                       &key lambda-list argument-precedence-order)
       (declare (ignore slot-names))
       (when lambda-list
           (setf (gf-arg-info gf)
                 (new-arg-info-from-generic-function lambda-list argument-precedence-order))))

(defmethod reinitialize-instance ((generic-function standard-generic-function)
                                  &rest initargs &key name lambda-list argument-precedence-order 
                                  declarations documentation method-class method-combination)
       (declare (ignore documentation declarations argument-precedence-order lambda-list name 
                       method-class method-combination))
       (macrolet ((add-initarg (check name slot-name)
                         `(unless ,check
                              (push (slot-value generic-function ,slot-name)
                                    initargs)
                              (push ,name initargs))))
                                                             ; (add-initarg name :name 'name)
                                                             ; (add-initarg lambda-list :lambda-list
                                                             ; 'lambda-list) (add-initarg
                                                             ; argument-precedence-order
                                                             ; :argument-precedence-order
                                                             ; 'argument-precedence-order)
                                                             ; (add-initarg declarations
                                                             ; :declarations 'declarations)
                                                             ; (add-initarg documentation
                                                             ; :documentation 'documentation)
                                                             ; (add-initarg method-class
                                                             ; :method-class 'method-class)
                                                             ; (add-initarg method-combination
                                                             ; :method-combination
                                                             ; 'method-combination) 
              (apply #'call-next-method generic-function initargs)))


;;; These three are scheduled for demolition. 


(defmethod remove-named-method (generic-function-name argument-specifiers &optional extra)
       (let ((generic-function nil)
             (method nil))
            (cond ((or (null (fboundp generic-function-name))
                       (not (generic-function-p (setq generic-function (symbol-function 
                                                                              generic-function-name))
                                   )))
                   (error "~S does not name a generic-function." generic-function-name))
                  ((null (setq method (get-method generic-function extra (parse-specializers 
                                                                                argument-specifiers)
                                             nil)))
                   (error "There is no method for the generic-function ~S~%~
                   which matches the argument-specifiers ~S." generic-function argument-specifiers))
                  (t (remove-method generic-function method)))))

(defun real-add-named-method (generic-function-name qualifiers specializers lambda-list function 
                                    &rest other-initargs)
       
       ;; What about changing the class of the generic-function if there is one.  Whose job is that
       ;; anyways.  Do we need something kind of like class-for-redefinition? 
       (let* ((generic-function (ensure-generic-function generic-function-name :lambda-list
                                       (method-ll->generic-function-ll lambda-list)))
              (specs (parse-specializers specializers))
                                                             ; (existing (get-method
                                                             ; generic-function qualifiers specs
                                                             ; nil))
              (proto (method-prototype-for-gf generic-function-name))
              (new (apply #'make-instance (class-of proto)
                          :qualifiers qualifiers :specializers specs :lambda-list lambda-list 
                          :function function other-initargs)))
                                                             ; (when existing (remove-method
                                                             ; generic-function existing))
             (add-method generic-function new)))

(defun make-specializable (function-name &key (arglist nil arglistp))
       (cond ((not (null arglistp)))
             ((not (fboundp function-name)))
             ((fboundp 'function-arglist)
              
              ;; function-arglist exists, get the arglist from it.
              (setq arglist (function-arglist function-name)))
             (t (error "The :arglist argument to make-specializable was not supplied~%~
            and there is no version of FUNCTION-ARGLIST defined for this~%~
            port of Portable CommonLoops.~%~
            You must either define a version of FUNCTION-ARGLIST (which~%~
            should be easy), and send it off to the Portable CommonLoops~%~
            people or you should call make-specializable again with the~%~
            :arglist keyword to specify the arglist.")))
       (let ((original (and (fboundp function-name)
                            (symbol-function function-name)))
             (generic-function (make-instance 'standard-generic-function :name function-name))
             (nrequireds 0))
            (if (generic-function-p original)
                original
                (progn (dolist (arg arglist)
                           (if (memq arg lambda-list-keywords)
                               (return)
                               (incf nrequireds)))
                       (setf (symbol-function function-name)
                             generic-function)
                       (set-function-name generic-function function-name)
                       (when arglistp
                           (setf (gf-pretty-arglist generic-function)
                                 arglist))
                       (when original
                           (add-named-method function-name nil (make-list nrequireds :initial-element
                                                                      't)
                                  arglist original))
                       generic-function))))

(defun real-get-method (generic-function qualifiers specializers &optional (errorp t))
       (let ((hit (dolist (method (generic-function-methods generic-function))
                      (when (and (equal qualifiers (method-qualifiers method))
                                 (every #'same-specializer-p specializers (method-specializers method
                                                                                 )))
                            (return method)))))
            (cond (hit hit)
                  ((null errorp)
                   nil)
                  (t (error "No method on ~S with qualifiers ~:S and specializers ~:S." 
                            generic-function qualifiers specializers)))))


;;; Compute various information about a generic-function's arglist by looking at the argument lists
;;; of the methods.  The hair for trying not to use &rest arguments lives here. The values returned
;;; are: number-of-required-arguments the number of required arguments to this generic-function's
;;; discriminating function &rest-argument-p whether or not this generic-function's discriminating
;;; function takes an &rest argument. specialized-argument-positions a list of the positions of the
;;; arguments this generic-function specializes (e.g. for a classical generic-function this is the
;;; list: (1)). 


(defmethod compute-discriminating-function-arglist-info ((generic-function standard-generic-function)
                                                         )
       (declare (values number-of-required-arguments &rest-argument-p specialized-argument-postions))
       (let ((number-required nil)
             (restp nil)
             (specialized-positions nil)
             (methods (generic-function-methods generic-function)))
            (dolist (method methods)
                (multiple-value-setq (number-required restp specialized-positions)
                       (compute-discriminating-function-arglist-info-internal generic-function method
                              number-required restp specialized-positions)))
            (values number-required restp (sort specialized-positions #'<))))

(defun compute-discriminating-function-arglist-info-internal (generic-function method 
                                                                    number-of-requireds restp 
                                                                    specialized-argument-positions)
       (declare (ignore generic-function))
       (let ((requireds 0))
            
            ;; Go through this methods arguments seeing how many are required, and whether there is
            ;; an &rest argument. 
            (dolist (arg (method-lambda-list method))
                (cond ((eq arg '&aux)
                       (return))
                      ((memq arg '(&optional &rest &key))
                       (return (setq restp t)))
                      ((memq arg lambda-list-keywords))
                      (t (incf requireds))))
            
            ;; Now go through this method's type specifiers to see which argument positions are type
            ;; specified.  Treat T specially in the usual sort of way.  For efficiency don't bother
            ;; to keep specialized-argument-positions sorted, rather depend on our caller to do
            ;; that. 
            (iterate ((type-spec (list-elements (method-specializers method)))
                      (pos (interval :from 0)))
                   (unless (eq type-spec *the-class-t*)
                          (pushnew pos specialized-argument-positions)))
            
            ;; Finally merge the values for this method into the values for the exisiting methods
            ;; and return them.  Note that if num-of-requireds is NIL it means this is the first
            ;; method and we depend on that. 
            (values (min (or number-of-requireds requireds)
                         requireds)
                   (or restp (and number-of-requireds (/= number-of-requireds requireds)))
                   specialized-argument-positions)))

(defun make-discriminating-function-arglist (number-required-arguments restp)
       (nconc (gathering ((args (collecting)))
                     (iterate ((i (interval :from 0 :below number-required-arguments)))
                            (gather (intern (format nil "Discriminating Function Arg ~D" i))
                                   args)))
              (when restp
                  `(&rest ,(intern "Discriminating Function &rest Arg")))))


;;; 


(defun make-arg-info (precedence metatypes number-optional key/rest-p keywords)
       (let ((new (make-array 6 :adjustable nil)))
            (setf (svref new 0)
                  'arg-info
                  (svref new 1)
                  precedence
                  (svref new 2)
                  metatypes
                  (svref new 3)
                  number-optional
                  (svref new 4)
                  key/rest-p
                  (svref new 5)
                  keywords)
                                                             ; nil         no keyword or rest
                                                             ; allowed (k1 k2 ..)  each method must
                                                             ; accept these keyword arguments T     
                                                             ; must have &key or &rest 
            new))

(defun check-arg-info (x)
       (or (and (simple-vector-p x)
                (= (array-dimension x 0)
                   6)
                (eq (svref x 0)
                    'arg-info))
           (error "~S is not an ARG-INFO." x)))

(defun arg-info-precedence (arg-info)
       (check-arg-info arg-info)
       (svref arg-info 1))

(defun arg-info-metatypes (arg-info)
       (check-arg-info arg-info)
       (svref arg-info 2))

(defun arg-info-number-optional (arg-info)
       (check-arg-info arg-info)
       (svref arg-info 3))

(defun arg-info-key/rest-p (arg-info)
       (check-arg-info arg-info)
       (svref arg-info 4))

(defun arg-info-keywords (arg-info)
       (check-arg-info arg-info)
       (svref arg-info 5))

(defun arg-info-applyp (arg-info)
       (check-arg-info arg-info)
       (or (plusp (arg-info-number-optional arg-info))
           (arg-info-key/rest-p arg-info)))

(defun arg-info-number-required (arg-info)
       (check-arg-info arg-info)
       (length (arg-info-metatypes arg-info)))

(defun arg-info-nkeys (arg-info)
       (count-if #'(lambda (x)
                          (neq x 't))
              (arg-info-metatypes arg-info)))

(defun new-arg-info-from-generic-function (lambda-list argument-precedence-order)
       (multiple-value-bind (nreq nopt keysp restp allow-other-keys-p keywords)
           (analyze-lambda-list lambda-list)
         (declare (ignore allow-other-keys-p))
         (let ((metatypes (make-list nreq))
               (precedence (compute-precedence lambda-list nreq argument-precedence-order)))
              (make-arg-info precedence metatypes nopt (or keysp restp)
                     keywords))))

(defun new-arg-info-from-method (method)
       (multiple-value-bind (nreq nopt keysp restp)
           (analyze-lambda-list (method-lambda-list method))
         (make-arg-info (compute-precedence (method-lambda-list method)
                               nreq nil)
                (mapcar #'raise-metatype (make-list nreq)
                       (method-specializers method))
                nopt
                (or keysp restp)
                nil)))

(defun add-arg-info (generic-function method arg-info)
       (flet ((lose (string &rest args)
                    (error 
              "Attempt to add the method ~S to the generic function ~S.~%~
                   But ~A" method generic-function (apply #'format nil string args)))
              (compare (x y)
                     (if (> x y)
                         "more"
                         "fewer")))
             (multiple-value-bind (nreq nopt keysp restp allow-other-keys-p keywords)
                 (analyze-lambda-list (method-lambda-list method))
               (let ((gf-nreq (arg-info-number-required arg-info))
                     (gf-nopt (arg-info-number-optional arg-info))
                     (gf-key/rest-p (arg-info-key/rest-p arg-info))
                     (gf-keywords (arg-info-keywords arg-info)))
                    (unless (= nreq gf-nreq)
                        (lose "the method has ~A required arguments than the generic function."
                              (compare nreq gf-nreq)))
                    (unless (= nopt gf-nopt)
                        (lose "the method has ~S optional arguments than the generic function."
                              (compare nopt gf-nopt)))
                    (unless (eq (or keysp restp)
                                gf-key/rest-p)
                           (error "the method and generic function differ in whether they accept~%~
                  rest or keyword arguments."))
                    (when gf-keywords
                        (unless (or (and restp (not keysp))
                                    allow-other-keys-p
                                    (every #'(lambda (k)
                                                    (memq k keywords))
                                           gf-keywords))
                               (error "the generic function requires each method to accept the keyword arguments~%~
               ~S.  The method does not all of accept these." gf-keywords)))
                    (make-arg-info (arg-info-precedence arg-info)
                           (mapcar #'raise-metatype (arg-info-metatypes arg-info)
                                  (method-specializers method))
                           gf-nopt gf-key/rest-p gf-keywords)))))

(defun remove-arg-info (generic-function method arg-info)
       (declare (ignore generic-function method))
       arg-info)


;;; 


(defun compute-precedence (lambda-list nreq argument-precedence-order)
       (let ((nreq (analyze-lambda-list lambda-list)))
            (if (null argument-precedence-order)
                (let ((c -1))
                     (gathering1 (collecting)
                            (dotimes (i nreq)
                                (gather1 (incf c)))))
                (mapcar #'(lambda (x)
                                 (position x lambda-list))
                       argument-precedence-order))))

(defmethod no-applicable-method (generic-function &rest args)
       (cerror "Retry call to ~S" 
         "No matching method for the generic-function ~S,~@
          when called with arguments ~S." generic-function args)
       (let ((*invalid-dfuns-on-stack* (remove generic-function *invalid-dfuns-on-stack*)))
            (invalidate-discriminating-function generic-function)
            (apply generic-function args)))

(defun real-add-method (generic-function method)
       (if (method-generic-function method)
           (error "The method ~S is already part of the generic~@
              function ~S.  It can't be added to another generic~@
              function until it is removed from the first one." method (method-generic-function
                                                                        method))
           (let* ((qualifiers (method-qualifiers method))
                  (lambda-list (method-lambda-list method))
                  (specializers (method-specializers method))
                  (existing (get-method generic-function qualifiers specializers nil)))
                 
                 ;; If there is already a method like this one then we must get rid of it before
                 ;; proceeding.  Note that we call the generic function remove-method to remove it
                 ;; rather than doing it in some internal way. 
                 (when existing (remove-method generic-function existing))
                 
                 ;; 
                 (let ((arg-info (gf-arg-info generic-function)))
                      (setf (gf-arg-info generic-function)
                            (if (null arg-info)
                                (new-arg-info-from-method method)
                                (add-arg-info generic-function method arg-info)))
                      (setf (method-generic-function method)
                            generic-function)
                      (pushnew method (generic-function-methods generic-function))
                      (dolist (specializer specializers)
                          (add-method-on-specializer method specializer))
                      (invalidate-discriminating-function generic-function)
                      (maybe-update-constructors generic-function method)
                      method))))

(defun real-remove-method (generic-function method)
       (if (neq generic-function (method-generic-function method))
           (error "The method ~S is attached to the generic function~@
               ~S.  It can't be removed from the generic function~@
               to which it is not attached." method (method-generic-function method))
           (let* ((methods (generic-function-methods generic-function))
                  (new-methods (remove method methods))
                  (new-arg-info (remove-arg-info generic-function method (gf-arg-info 
                                                                                generic-function))))
                 (setf (method-generic-function method)
                       nil)
                 (setf (generic-function-methods generic-function)
                       new-methods)
                 (dolist (specializer (method-specializers method))
                     (remove-method-on-specializer method specializer))
                 (setf (gf-arg-info generic-function)
                       new-arg-info)
                 (invalidate-discriminating-function generic-function)
                 (maybe-update-constructors generic-function method)
                 generic-function)))


;;; This is it.  You have reached the special place where everything comes together.  This is where
;;; we ensure that the metacircularity will bottom out properly. Remember once again that the source
;;; of the problem is that the specified behavior clearly calls for the process of method lookup to
;;; itself call generic functions.  This implies that for a given generic function in the method
;;; lookup protocol (compute-applicable-methods for example), we can end up in the unfortunate
;;; situation of having to call that generic function in order to call it! So, we must arrange to
;;; snap this infinite regress. The strategy taken here is to identify a particular subset of calls
;;; to method lookup protocol generic functions and snap the recursion there. This subset of generic
;;; function calls has the following properties: - Any generic function call in the world will,
;;; eventually reach one of these generic function calls.  That is we are sure that if we can
;;; arrange for these calls not to recurse we know we are all set. - These calls themselves don't
;;; recurse.  We arrange, by magic, for the method lookup and application involved in these calls
;;; not to call any other generic functions. 


(defvar *magic-generic-functions* '((compute-discriminating-function ((standard-generic-function)
                                                                      (standard-generic-function)))
                                    (compute-applicable-methods ((standard-generic-function t)
                                                                 (generic-function t)))
                                    (compute-applicable-methods-using-classes ((
                                                                            standard-generic-function
                                                                                t)
                                                                               (generic-function
                                                                                t)))
                                                             ; (same-specializer-p      
                                                             ; ((standard-class standard-class) (t
                                                             ; t))) (specializer-applicable-p
                                                             ; ((standard-class t) (class t))) 
                                    (specializer-applicable-using-class-p ((standard-class t)
                                                                           (class t))
                                           ((built-in-class t)
                                            (class t)))
                                    (order-specializers-using-class ((standard-class standard-class t
                                                                            )
                                                                     (class class t)))
                                    (compute-effective-method ((standard-generic-function
                                                                (eql *standard-method-combination*)
                                                                t)
                                                               (generic-function 
                                                                      standard-method-combination t))
                                           )
                                    (method-p ((standard-method)
                                               (method))
                                           ((standard-reader-method)
                                            (method))
                                           ((standard-writer-method)
                                            (method)))
                                    (standard-accessor-method-p ((standard-method)
                                                                 (t))
                                           ((standard-reader-method)
                                            (standard-accessor-method))
                                           ((standard-writer-method)
                                            (standard-accessor-method)))
                                    (standard-reader-method-p ((standard-method)
                                                               (t))
                                           ((standard-reader-method)
                                            (standard-reader-method))
                                           ((standard-writer-method)
                                            (t)))
                                    (standard-writer-method-p ((standard-method)
                                                               (t))
                                           ((standard-reader-method)
                                            (t))
                                           ((standard-writer-method)
                                            (standard-writer-method)))
                                    (method-qualifiers ((standard-method)
                                                        (standard-method))
                                           ((standard-reader-method)
                                            (standard-method)))
                                    (method-specializers ((standard-method)
                                                          (standard-method))
                                           ((standard-reader-method)
                                            (standard-method)))
                                    (method-lambda-list ((standard-method)
                                                         (standard-method))
                                           ((standard-reader-method)
                                            (standard-method)))
                                    (method-function ((standard-method)
                                                      (standard-method))
                                           ((standard-reader-method)
                                            (standard-method)))
                                    (accessor-method-slot-name ((standard-reader-method)
                                                                (standard-accessor-method))
                                           ((standard-writer-method)
                                            (standard-accessor-method)))
                                    (classp ((standard-class)
                                             (class))
                                           ((built-in-class)
                                            (class)))
                                    (class-precedence-list ((standard-class)
                                                            (clos-class)))
                                    (class-finalized-p ((standard-class)
                                                        (clos-class)))
                                    (generic-function-methods ((standard-generic-function)
                                                               (standard-generic-function)))
                                    (generic-function-method-combination ((standard-generic-function)
                                                                          (standard-generic-function)
                                                                          ))
                                    (gf-arg-info ((standard-generic-function)
                                                  (standard-generic-function)))
                                    (gf-dfun-state ((standard-generic-function)
                                                    (standard-generic-function)))
                                    (gf-effective-method-functions ((standard-generic-function)
                                                                    (standard-generic-function)))
                                    ((setf gf-effective-method-functions)
                                     ((t standard-generic-function)
                                      (t standard-generic-function)))
                                                             ; (gf-permutation                      
                                                             ; ((standard-generic-function)
                                                             ; (standard-generic-function))) 
                                    (slot-value-using-class ((standard-class t 
                                                                   standard-effective-slot-definition
                                                                    )
                                                             ; the first t is a bug
                                                             (std-class standard-object 
                                                                   standard-effective-slot-definition
                                                                    ))
                                           ((funcallable-standard-class t 
                                                   standard-effective-slot-definition)
                                            (std-class standard-object 
                                                   standard-effective-slot-definition)))
                                    ((setf slot-value-using-class)
                                     ((t standard-class t standard-effective-slot-definition)
                                      (t std-class standard-object standard-effective-slot-definition
                                         ))
                                     ((t funcallable-standard-class t 
                                         standard-effective-slot-definition)
                                      (t std-class standard-object standard-effective-slot-definition
                                         )))))

(defvar *magic-generic-functions-1* nil)

(defun
 fixup-magic-generic-function
 (gfspec early-methods gf methods)
 (flet
  ((get-specls (names convert-t-p)
          (mapcar #'(lambda (s)
                           (cond ((consp s)
                                  `(eql ,(eval (cadr s))))
                                 ((eq s t)
                                  (if convert-t-p
                                      (find-class t)
                                      t))
                                 (t (find-class s))))
                 names)))
  (let
   ((e (assoc gfspec *magic-generic-functions* :test #'equal)))
   (when e
       (push (list* gf (make-arg-info
                        nil
                        (apply #'mapcar #'(lambda (&rest args)
                                                 (if (every #'(lambda (arg)
                                                                     (eq arg 't))
                                                            args)
                                                     't
                                                     'standard-instance))
                               (mapcar #'second (cdr e)))
                        nil nil nil)
                    (gathering1 (collecting)
                           (dolist (pair (cdr e))
                               (iterate ((em (list-elements early-methods))
                                         (m (list-elements methods)))
                                      (when (equal (early-method-specializers em t)
                                                   (get-specls (cadr pair)
                                                          t))
                                          (gather1 (list (get-specls (car pair)
                                                                nil)
                                                         (list m)
                                                         (early-method-function em)))
                                          (return t))))))
             *magic-generic-functions-1*)))))

(defun get-secondary-dispatch-function (generic-function args)
       (declare (values compiled-secondary-dispatch-function methods arg-info))
       (multiple-value-bind (fn methods arg-info)
           (get-magic-secondary-dispatch-function generic-function args)
         (if fn
             (values fn methods arg-info)
             (get-normal-secondary-dispatch-function generic-function args))))

(defun get-magic-secondary-dispatch-function (generic-function args)
       (let ((e (assq generic-function *magic-generic-functions-1*)))
            (when e
                (dolist (entry (cddr e))
                    (destructuring-bind (specls appl function)
                           entry
                           (unless (iterate ((arg (list-elements args))
                                             (specl (list-elements specls)))
                                          (let ((class (class-of arg)))
                                               (unless (if (consp specl)
                                                           (eql (cadr specl)
                                                                arg)
                                                           (or (eq specl t)
                                                               (eq specl class)))
                                                      (return t))))
                               (return (values function appl (cadr e)))))))))

(defmacro protect-cache-miss-code (gf args &body body)
       (let ((wrappers (gensym))
             (invalidp (gensym))
             #'(gensym)
             (appl (gensym)))
            (once-only (gf args)
                   `(if (memq ,gf *invalid-dfuns-on-stack*)
                        (multiple-value-bind (,wrappers ,invalidp ,function ,appl)
                            (cache-miss-values ,gf ,args)
                          (declare (ignore ,wrappers ,invalidp))
                          (if (null ,appl)
                              (apply #'no-applicable-method ,gf ,args)
                              (apply ,function ,args)))
                        (let ((*invalid-dfuns-on-stack* (cons ,gf *invalid-dfuns-on-stack*)))
                             ,@body)))))

(defmethod same-specializer-p (specl1 specl2)
       (eq specl1 specl2))

(defmethod specializer-applicable-p ((specializer class)
                                     object)
       (memq specializer (class-precedence-list (class-of object))))

(defmethod specializer-applicable-using-class-p ((specializer class)
                                                 class)
       (*subtypep class specializer))

(defmethod order-specializers-using-class ((specl1 class)
                                           (specl2 class)
                                           class)
       (cond ((eq specl1 specl2)
              nil)
             ((memq specl2 (memq specl1 (class-precedence-list class)))
              specl1)
             (t specl2)))

(defmethod compute-applicable-methods ((generic-function generic-function)
                                       arguments)
       (labels ((filter (method)
                       (let ((arguments-tail arguments))
                            (dolist (m-spec (method-specializers method)
                                           t)
                                (unless arguments-tail
                                    (error "The function ~S requires at least ~D arguments"
                                           (generic-function-name generic-function)
                                           (arg-info-number-required (gf-arg-info generic-function))))
                                (unless (specializer-applicable-p m-spec (pop arguments-tail))
                                       (return nil)))))
                (sorter (method-1 method-2)
                       (dolist (index (arg-info-precedence (gf-arg-info generic-function)))
                           (let* ((specl1 (nth index (method-specializers method-1)))
                                  (specl2 (nth index (method-specializers method-2)))
                                  (class (class-of (nth index arguments)))
                                  (order (order-specializers-using-class specl1 specl2 class)))
                                 (when order
                                     (return-from sorter (eq order specl1)))))))
              (let ((methods (generic-function-methods generic-function)))
                   (stable-sort (copy-list (remove-if-not #'filter methods))
                          #'sorter))))

(defmethod compute-applicable-methods-using-classes ((generic-function generic-function)
                                                     classes)
       (labels ((filter (method)
                       (let ((classes-tail classes))
                            (dolist (m-spec (method-specializers method)
                                           t)
                                (unless classes-tail
                                    (error "The function ~S requires at least ~D arguments"
                                           (generic-function-name generic-function)
                                           (arg-info-number-required (gf-arg-info generic-function))))
                                (unless (specializer-applicable-using-class-p m-spec (pop 
                                                                                         classes-tail
                                                                                          ))
                                       (return nil)))))
                (sorter (method-1 method-2)
                       (dolist (index (arg-info-precedence (gf-arg-info generic-function)))
                           (let* ((specl1 (nth index (method-specializers method-1)))
                                  (specl2 (nth index (method-specializers method-2)))
                                  (class (nth index classes))
                                  (order (order-specializers-using-class specl1 specl2 class)))
                                 (when order
                                     (return-from sorter (eq order specl1)))))))
              (let ((methods (generic-function-methods generic-function)))
                   (stable-sort (copy-list (remove-if-not #'filter methods))
                          #'sorter))))

(defun get-normal-secondary-dispatch-function (generic-function args)
       (let* ((classes (mapcar #'(lambda (arg mt)
                                        (declare (ignore mt))
                                        (class-of arg))
                              args
                              (arg-info-metatypes (gf-arg-info generic-function))))
              (methods (compute-applicable-methods-using-classes generic-function classes))
              (net (generate-discrimination-net generic-function methods))
              (arg-info (gf-arg-info generic-function))
              (metatypes (arg-info-metatypes arg-info))
              (applyp (arg-info-applyp arg-info)))
             (flet ((net-test-converter (form)
                           (if (and (consp form)
                                    (eq (car form)
                                        'methods))
                               '.methods.
                               (default-test-converter form)))
                    (net-code-converter (form)
                           (if (and (consp form)
                                    (eq (car form)
                                        'methods))
                               (let ((gensym (gensym)))
                                    (values (make-dfun-call metatypes applyp gensym)
                                           (list gensym)))
                               (default-code-converter form)))
                    (net-constant-converter (form)
                           (if (and (consp form)
                                    (eq (car form)
                                        'methods))
                               (list (get-effective-method-function generic-function (cdr form)))
                               (default-constant-converter form))))
                   (if (eq (car net)
                           'methods)
                       (and (cdr net)
                            (values (get-effective-method-function generic-function (cdr net))
                                   methods))
                       (values (get-function `(lambda ,(make-dfun-lambda-list metatypes applyp)
                                                     ,net)
                                      #'net-test-converter
                                      #'net-code-converter
                                      #'net-constant-converter)
                              methods)))))

(defun get-effective-method-function (generic-function methods)
       (let ((combin (generic-function-method-combination generic-function))
             (precomputed (gf-effective-method-functions generic-function)))
            
            ;; NOTE: We are assuming a restriction on user code that the method combination must not
            ;; change once it is connected to the generic function. This has to be legal, because
            ;; otherwise any kind of method lookup caching couldn't work.  See this by saying that
            ;; this cache, is just a backing cache for the fast cache.  If that cache is legal, this
            ;; one must be too. Should altering the set of methods flush this cache? 
            (let ((entry (assoc methods precomputed :test #'equal)))
                 (if entry
                     (values (cdr entry)
                            (car entry))
                     (let* ((effective (compute-effective-method generic-function combin methods))
                            (fn (make-effective-method-function generic-function effective)))
                           (setf (gf-effective-method-functions generic-function)
                                 (cons (cons methods fn)
                                       precomputed))
                           (values fn methods))))))

(defun
 generate-discrimination-net
 (generic-function methods)
 (let* ((arg-info (gf-arg-info generic-function))
        (nreq (arg-info-number-required arg-info))
        (metatypes (arg-info-metatypes arg-info)))
       (labels ((do-column (position contenders)
                       (if (< position nreq)
                           (if (eq (nth position metatypes)
                                   't)
                               (do-column (1+ position)
                                      contenders)
                               (do-methods position contenders nil nil))
                           `(methods ,@contenders)))
                (do-methods
                 (position contenders known-outcomes winners)
                 
                 ;; <contenders> is a (sorted) list of methods that must be discriminated
                 ;; <known-outcomes> is a list of outcomes from tests already made on this argument
                 ;; each outcome looks like (<specializer> [t | nil]) <winners> is a (sorted) list
                 ;; of methods that are potentially applicable after the discrimination has been
                 ;; made. 
                 (if (null contenders)
                     (do-column (1+ position)
                            winners)
                     (let* ((method (car contenders))
                            (specl (nth position (method-specializers method))))
                           (flet ((determined-to-be (truth-value)
                                         (if (classp specl)
                                             truth-value
                                             (some #'(lambda (outcome)
                                                            (outcome-implies-p generic-function
                                                                   (car outcome)
                                                                   (cadr outcome)
                                                                   specl truth-value))
                                                   known-outcomes)))
                                  (if-true nil (do-methods position (cdr contenders)
                                                      (if (not (classp specl))
                                                          (cons `(,specl t)
                                                                known-outcomes)
                                                          known-outcomes)
                                                      (append winners `(,method))))
                                  (if-false nil (do-methods position (cdr contenders)
                                                       (if (not (classp specl))
                                                           (cons `(,specl nil)
                                                                 known-outcomes)
                                                           known-outcomes)
                                                       winners)))
                                 (cond ((determined-to-be nil)
                                        (if-false))
                                       ((determined-to-be t)
                                        (if-true))
                                       (t `(if ,(compute-argument-test-form generic-function
                                                       (dfun-arg-symbol position)
                                                       specl)
                                               ,(if-true)
                                               ,(if-false)))))))))
              (do-column 0 methods))))

(define-gf-predicate eql-specializer-p eql-specializer)

(defmethod same-specializer-p ((specl1 eql-specializer)
                               (specl2 eql-specializer))
       (eql (eql-specializer-object specl1)
            (eql-specializer-object specl2)))

(defmethod specializer-applicable-p ((specializer eql-specializer)
                                     object)
       (eql (eql-specializer-object specializer)
            object))

(defmethod specializer-applicable-using-class-p ((specializer eql-specializer)
                                                 class)
       (eq class (class-of (eql-specializer-object specializer))))

                                                             ; It would be most egregious to use
                                                             ; *subtypep here. 


(defmethod order-specializers-using-class ((specl1 eql-specializer)
                                           (specl2 eql-specializer)
                                           argument-class)
       (declare (ignore argument-class))
       nil)

(defmethod order-specializers-using-class ((specl1 class)
                                           (specl2 eql-specializer)
                                           argument-class)
       (declare (ignore argument-class))
       specl2)

(defmethod order-specializers-using-class ((specl1 eql-specializer)
                                           (specl2 class)
                                           argument-class)
       (declare (ignore argument-class))
       specl1)


;;; Does a given pair of values for {<specializer1> <truth1>} imply a given pair of values for
;;; {<specializer2> <truth2>}. 


(defmethod outcome-implies-p ((generic-function generic-function)
                              (specl1 eql-specializer)
                              value1
                              (specl2 eql-specializer)
                              value2)
       (flet ((same-truth-value (x y)
                     (or (and x y)
                         (and (not x)
                              (not y)))))
             (let ((obj1 (eql-specializer-object specl1))
                   (obj2 (eql-specializer-object specl2)))
                  (or (and (eql obj1 obj2)
                           (same-truth-value value1 value2))
                      (and (not (eql obj1 obj2))
                           value1
                           (not value2))))))


;;; Return a form which tests a given argument against a given specializer. 


(defmethod compute-argument-test-form ((generic-function generic-function)
                                       argument-form
                                       (specializer eql-specializer))
       `(eql ,argument-form ',(eql-specializer-object specializer)))


;;; The value returned by compute-discriminating-function is a function object.  It is called a
;;; discriminating function because it is called when the generic function is called and its role is
;;; to discriminate on the arguments to the generic function and then call appropriate method
;;; functions. A discriminating function can only be called when it is installed as the funcallable
;;; instance function of the generic function for which it was computed. More precisely, if
;;; compute-discriminating-function is called with an argument <gf1>, and returns a result <df1>,
;;; that result must not be passed to apply or funcall directly.  Rather, <df1> must be stored as
;;; the funcallable instance function of the same generic function <gf1> (using
;;; set-funcallable-instance-function).  Then the generic function can be passed to funcall or
;;; apply. An important exception is that methods on this generic function are permitted to return a
;;; function which itself ends up calling the value returned by a more specific method.  This kind
;;; of `encapsulation' of discriminating function is critical to many uses of the MOP. As an
;;; example, the following canonical case is legal: (defmethod compute-discriminating-function ((gf
;;; my-generic-function)) (let ((std (call-next-method))) #'(lambda (arg) (print (list 'call-to-gf
;;; gf arg)) (funcall std arg)))) Because many discriminating functions would like to use a dynamic
;;; strategy in which the precise discriminating function changes with time it is important to
;;; specify how a discriminating function is permitted itself to change the funcallable instance
;;; function of the generic function. Discriminating functions are may set the funcallable instance
;;; function of the generic function, but the new value must be generated by making a call to
;;; COMPUTE-DISCRIMINATING-FUNCTION.  This is to ensure that any more specific methods which may
;;; have encapsulated the discriminating function will get a chance to encapsulate the new, inner
;;; discriminating function. This implies that if a discriminating function wants to modify itself
;;; it should first store some information in the generic function proper, and then call
;;; compute-discriminating-function.  The appropriate method on compute-discriminating-function will
;;; see the information stored in the generic function and generate a discriminating function
;;; accordingly. The following is an example of a discriminating function which modifies itself in
;;; accordance with this protocol: (defmethod compute-discriminating-function ((gf
;;; my-generic-function)) #'(lambda (arg) (cond (<some condition> <store some info in the generic
;;; function> (set-funcallable-instance-function gf (compute-discriminating-function gf)) (funcall
;;; gf arg)) (t <call-a-method-of-gf>)))) Whereas this code would not be legal: (defmethod
;;; compute-discriminating-function ((gf my-generic-function)) #'(lambda (arg) (cond (<some
;;; condition> (set-funcallable-instance-function gf #'(lambda (a) ..)) (funcall gf arg)) (t
;;; <call-a-method-of-gf>)))) NOTE:  All the examples above assume that all instances of the class
;;; my generic function accept only one argument. 


(defmethod compute-discriminating-function ((gf standard-generic-function))
       (let* ((state (gf-dfun-state gf))
              (dfun (typecase state
                        (null (make-initial-dfun gf))
                        (function state)
                        (cons (car state)))))
             (doctor-dfun-for-the-debugger gf dfun)))

(defun update-dfun (generic-function dfun &optional cache)
       (let ((ostate (gf-dfun-state generic-function)))
            (unless (typep ostate '(or null function))
                (free-cache (cdr ostate)))
            (setf (gf-dfun-state generic-function)
                  (if cache
                      (cons dfun cache)
                      dfun))
            (invalidate-dfun-internal generic-function)))

(defvar *generate-random-code-segments* nil)

(defun invalidate-discriminating-function (generic-function)
       (let ((ostate (gf-dfun-state generic-function)))
            (unless (typep ostate '(or null function))
                (free-cache (cdr ostate)))
            (setf (gf-dfun-state generic-function)
                  nil)
            (setf (gf-effective-method-functions generic-function)
                  nil)
            (invalidate-dfun-internal generic-function)
            (when *generate-random-code-segments*
                (let ((*generate-random-code-segments* nil))
                     (generate-random-code-segments generic-function)))))

(defun invalidate-dfun-internal (generic-function)
       
       ;; Set the funcallable instance function to something that just calls invalid-dfun, that is,
       ;; arrange to use lazy evaluation to update the dfun later. 
       (set-funcallable-instance-function generic-function #'(lambda (&rest args)
                                                                    (invalid-dfun generic-function 
                                                                           args)))
       
       ;; Except that during bootstrapping, we would like to update the dfun right away, and this
       ;; arranges for that. 
       (when *invalidate-discriminating-function-force-p*
           (let ((*invalid-dfuns-on-stack* (cons generic-function *invalid-dfuns-on-stack*)))
                (set-funcallable-instance-function generic-function (compute-discriminating-function
                                                                     generic-function)))))

(defun invalid-dfun (gf args)
       (protect-cache-miss-code gf args (let ((new-dfun (compute-discriminating-function gf)))
                                             (set-funcallable-instance-function gf new-dfun)
                                             (apply gf args))))


;;; 


(defmethod function-keywords ((method standard-method))
       (multiple-value-bind (nreq nopt keysp restp allow-other-keys-p keywords)
           (analyze-lambda-list (method-lambda-list method))
         (declare (ignore nreq nopt keysp restp))
         (values keywords allow-other-keys-p)))

(defun analyze-lambda-list (lambda-list)
       (declare (values nrequired noptional keysp restp allow-other-keys-p keywords 
                       keyword-parameters))
       (flet ((parse-keyword-argument (arg)
                     (if (listp arg)
                         (if (listp (car arg))
                             (cadar arg)
                             (make-keyword (car arg)))
                         (make-keyword arg))))
             (let ((nrequired 0)
                   (noptional 0)
                   (keysp nil)
                   (restp nil)
                   (allow-other-keys-p nil)
                   (keywords nil)
                   (keyword-parameters nil)
                   (state 'required))
                  (dolist (x lambda-list)
                      (if (memq x lambda-list-keywords)
                          (case x
                              (&optional (setq state 'optional))
                              (&key (setq keysp 't state 'key))
                              (&allow-other-keys (setq allow-other-keys-p 't))
                              (&rest (setq restp 't state 'rest))
                              (&aux (return t))
                              (otherwise (error 
                                               "Encountered the non-standard lambda list keyword ~S."
                                                x)))
                          (ecase state
                              (required (incf nrequired))
                              (optional (incf noptional))
                              (key 
                                 (push (parse-keyword-argument x)
                                       keywords)
                                 (push x keyword-parameters))
                              (rest nil))))
                  (values nrequired noptional keysp restp allow-other-keys-p (reverse keywords)
                         (reverse keyword-parameters)))))

(defun method-ll->generic-function-ll (ll)
       (multiple-value-bind (nreq nopt keysp restp allow-other-keys-p keywords keyword-parameters)
           (analyze-lambda-list ll)
         (declare (ignore nreq nopt keysp restp allow-other-keys-p keywords))
         (remove-if #'(lambda (s)
                             (or (memq s keyword-parameters)
                                 (eq s '&allow-other-keys)))
                ll)))


;;; This is based on the rules of method lambda list congruency defined in the spec.  The lambda
;;; list it constructs is the pretty union of the lambda lists of all the methods.  It doesn't take
;;; method applicability into account at all yet. 


(defmethod generic-function-pretty-arglist ((generic-function standard-generic-function))
       (let ((methods (generic-function-methods generic-function))
             (arglist nil))
            (when methods
                (multiple-value-bind (required optional rest key allow-other-keys)
                    (method-pretty-arglist (car methods))
                  (dolist (m (cdr methods))
                      (multiple-value-bind (method-key-keywords method-allow-other-keys method-key)
                          (function-keywords m)
                        
                        ;; we've modified function-keywords to return what we want as the third
                        ;; value, no other change here. 
                        (declare (ignore method-key-keywords))
                        (setq key (union key method-key))
                        (setq allow-other-keys (or allow-other-keys method-allow-other-keys))))
                  (when allow-other-keys
                      (setq arglist '(&allow-other-keys)))
                  (when key
                      (setq arglist (nconc (list '&key)
                                           key arglist)))
                  (when rest
                      (setq arglist (nconc (list '&rest rest)
                                           arglist)))
                  (when optional
                      (setq arglist (nconc (list '&optional)
                                           optional arglist)))
                  (nconc required arglist)))))

(defmethod method-pretty-arglist ((method standard-method))
       (let ((required nil)
             (optional nil)
             (rest nil)
             (key nil)
             (allow-other-keys nil)
             (state 'required)
             (arglist (method-lambda-list method)))
            (dolist (arg arglist)
                (cond ((eq arg '&optional)
                       (setq state 'optional))
                      ((eq arg '&rest)
                       (setq state 'rest))
                      ((eq arg '&key)
                       (setq state 'key))
                      ((eq arg '&allow-other-keys)
                       (setq allow-other-keys 't))
                      ((memq arg lambda-list-keywords))
                      (t (ecase state
                             (required (push arg required))
                             (optional (push arg optional))
                             (key (push arg key))
                             (rest (setq rest arg))))))
            (values (nreverse required)
                   (nreverse optional)
                   rest
                   (nreverse key)
                   allow-other-keys)))
