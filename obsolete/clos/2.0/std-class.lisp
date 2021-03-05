
;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;; File converted on 10-Apr-91 22:24:19 from source std-class
;;;. Original source {dsk}<usr>local>users>welch>lisp>clos>rev4>il-format>std-class.;4 created 20-Feb-91 13:07:14

;;;. Copyright (c) 1991 by Venue


(in-package "CLOS")



(define-gf-predicate classp class)

(define-gf-predicate standard-class-p standard-class)

(define-gf-predicate forward-referenced-class-p forward-referenced-class)

(defmethod shared-initialize :after ((object documentation-mixin)
                                     slot-names &key documentation)
       (declare (ignore slot-names))
       (setf (plist-value object 'documentation)
             documentation))

(defmethod documentation (object &optional doc-type)
       (cl:documentation object doc-type))

(defmethod (setf documentation)
       (new-value object &optional doc-type)
       (declare (ignore new-value doc-type))
       (error "Can't change the documentation of ~S." object))

(defmethod documentation ((object documentation-mixin)
                          &optional doc-type)
  (declare (ignore doc-type))
  (car (plist-value object 'documentation)))

(defmethod (setf documentation)
       (new-value (object documentation-mixin)
              &optional doc-type)
       (declare (ignore doc-type))
       (setf (plist-value object 'documentation)
             new-value))

(defmethod documentation ((slotd standard-slot-definition)
                          &optional doc-type)
       (declare (ignore doc-type))
       (slot-value slotd 'documentation))

(defmethod (setf documentation)
       (new-value (slotd standard-slot-definition)
              &optional doc-type)
       (declare (ignore doc-type))
       (setf (slot-value slotd 'documentation)
             new-value))

(defmethod documentation ((method standard-method) &optional doc-type)
  (declare (ignore doc-type))
  (plist-value method 'documentation))

(defmethod (setf documentation)
	   (new-value (method standard-method)
		      &optional doc-type)
  (declare (ignore doc-type))
  (setf (plist-value method 'documentation) new-value))

;;; Various class accessors that are a little more complicated than can be done with automatically
;;; generated reader methods. 


(defmethod class-wrapper ((class clos-class))
       (with-slots (wrapper)
           class
         (let ((w? wrapper))
              (if (consp w?)
                  (let ((new (make-wrapper class)))
                       (setf (wrapper-instance-slots-layout new)
                             (car w?)
                             (wrapper-class-slots new)
                             (cdr w?))
                       (setq wrapper new))
                  w?))))

(defmethod class-precedence-list ((class clos-class))
       (unless (class-finalized-p class)
              (finalize-inheritance class))
       (with-slots (class-precedence-list)
           class
         class-precedence-list))

(defmethod class-finalized-p ((class clos-class))
       (with-slots (wrapper)
           class
         (not (null wrapper))))

(defmethod class-prototype ((class std-class))
       (with-slots (prototype)
           class
         (or prototype (setq prototype (allocate-instance class)))))

(defmethod class-direct-default-initargs ((class std-class))
       (plist-value class 'direct-default-initargs))

(defmethod class-default-initargs ((class std-class))
       (plist-value class 'default-initargs))

(defmethod class-constructors ((class std-class))
       (plist-value class 'constructors))

(defmethod class-slot-cells ((class std-class))
       (plist-value class 'class-slot-cells))


;;; Class accessors that are even a little bit more complicated than those above.  These have a
;;; protocol for updating them, we must implement that protocol. Maintaining the direct subclasses
;;; backpointers.  The update methods are here, the values are read by an automatically generated
;;; reader method. 


(defmethod add-direct-subclass ((class class)
                                (subclass class))
       (with-slots (direct-subclasses)
           class
         (pushnew subclass direct-subclasses)
         subclass))

(defmethod remove-direct-subclass ((class class)
                                   (subclass class))
       (with-slots (direct-subclasses)
           class
         (setq direct-subclasses (remove subclass direct-subclasses))
         subclass))


;;; Maintaining the direct-methods and direct-generic-functions backpointers. There are four generic
;;; functions involved, each has one method for the class case and another method for the damned EQL
;;; specializers. All of these are specified methods and appear in their specified place in the
;;; class graph. ADD-METHOD-ON-SPECIALIZER REMOVE-METHOD-ON-SPECIALIZER SPECIALIZER-METHODS
;;; SPECIALIZER-GENERIC-FUNCTIONS In each case, we maintain one value which is a cons.  The car is
;;; the list methods.  The cdr is a list of the generic functions.  The cdr is always computed
;;; lazily. 


(defmethod add-method-on-specializer ((method method)
                                      (specializer class))
       (with-slots (direct-methods)
           specializer
         (setf (car direct-methods)
               (adjoin method (car direct-methods))
               (cdr direct-methods)
               nil))
       method)

(defmethod remove-method-on-specializer ((method method)
                                         (specializer class))
       (with-slots (direct-methods)
           specializer
         (setf (car direct-methods)
               (remove method (car direct-methods))
               (cdr direct-methods)
               nil))
       method)

(defmethod specializer-methods ((specializer class))
       (with-slots (direct-methods)
           specializer
         (car direct-methods)))

(defmethod specializer-generic-functions ((specializer class))
       (with-slots (direct-methods)
           specializer
         (or (cdr direct-methods)
             (setf (cdr direct-methods)
                   (gathering1 (collecting-once)
                          (dolist (m (car direct-methods))
                              (gather1 (method-generic-function m))))))))


;;; This hash table is used to store the direct methods and direct generic functions of EQL
;;; specializers.  Each value in the table is the cons. 


(defvar *eql-specializer-methods* (make-hash-table :test #'eql))

(defmethod add-method-on-specializer ((method method)
                                      (specializer eql-specializer))
       (let* ((object (eql-specializer-object specializer))
              (entry (gethash object *eql-specializer-methods*)))
             (unless entry
                 (setq entry (setf (gethash object *eql-specializer-methods*)
                                   (cons nil nil))))
             (setf (car entry)
                   (adjoin method (car entry))
                   (cdr entry)
                   nil)
             method))

(defmethod remove-method-on-specializer ((method method)
                                         (specializer eql-specializer))
       (let* ((object (eql-specializer-object specializer))
              (entry (gethash object *eql-specializer-methods*)))
             (when entry
                 (setf (car entry)
                       (remove method (car entry))
                       (cdr entry)
                       nil))
             method))

(defmethod specializer-methods ((specializer eql-specializer))
       (car (gethash (eql-specializer-object specializer)
                   *eql-specializer-methods*)))

(defmethod specializer-generic-functions ((specializer eql-specializer))
       (let* ((object (eql-specializer-object specializer))
              (entry (gethash object *eql-specializer-methods*)))
             (when entry
                 (or (cdr entry)
                     (setf (cdr entry)
                           (gathering1 (collecting-once)
                                  (dolist (m (car entry))
                                      (gather1 (method-generic-function m)))))))))

(defun real-load-defclass (name metaclass-name supers slots other accessors)
       (do-standard-defsetfs-for-defclass accessors)
                                                             ; ***
       (apply #'ensure-class name :metaclass metaclass-name :direct-superclasses supers :direct-slots
              slots :definition-source `((defclass ,name ()
                                             ())
                                         ,(load-truename))
              other))

(defun ensure-class (name &rest all)
       (apply #'ensure-class-using-class name (find-class name nil)
              all))

(defmethod ensure-class-using-class (name (class null)
                                          &rest args &key)
       (multiple-value-bind (meta initargs)
           (ensure-class-values class args)
         (setf class (apply #'make-instance meta :name name initargs)
               (find-class name)
               class)
	 (inform-type-system-about-class class name)
                                                             ; ***
         class))

(defmethod ensure-class-using-class (name (class clos-class)
                                          &rest args &key)
       (multiple-value-bind (meta initargs)
           (ensure-class-values class args)
         (unless (eq (class-of class)
                     meta)
                (change-class class meta))
         (apply #'reinitialize-instance class initargs)
         (inform-type-system-about-class class name)
                                                             ; ***
         class))

(defun ensure-class-values (class args)
       (let* ((initargs (copy-list args))
              (unsupplied (list 1))
              (supplied-meta (getf initargs :metaclass unsupplied))
              (supplied-supers (getf initargs :direct-superclasses unsupplied))
              (supplied-slots (getf initargs :direct-slots unsupplied))
              (meta (cond ((neq supplied-meta unsupplied)
                           (find-class supplied-meta))
                          ((or (null class)
                               (forward-referenced-class-p class))
                           *the-class-standard-class*)
                          (t (class-of class))))
              (proto (class-prototype meta)))
             (flet ((fix-super (s)
                           (cond ((classp s)
                                  s)
                                 ((not (legal-class-name-p s))
                                  (error "~S is not a class or a legal class name." s))
                                 (t (or (find-class s nil)
                                        (setf (find-class s)
                                              (make-instance 'forward-referenced-class :name s)))))))
                   (loop (unless (remf initargs :metaclass)
                                (return)))
                   (loop (unless (remf initargs :direct-superclasses)
                                (return)))
                   (loop (unless (remf initargs :direct-slots)
                                (return)))
                   (values meta (list* :direct-superclasses (and (neq supplied-supers unsupplied)
                                                                 (mapcar #'fix-super supplied-supers)
                                                                 )
                                       :direct-slots
                                       (and (neq supplied-slots unsupplied)
                                            supplied-slots)
                                       initargs)))))


;;; 


(defmethod shared-initialize :before ((class std-class)
                                      slot-names &key direct-superclasses)
       (declare (ignore slot-names))
       
       ;; *** error checking
       )

(defmethod shared-initialize :after ((class std-class)
                                     slot-names 
				     &key (direct-superclasses 
					   nil direct-superclasses-p)
                                     (direct-slots nil direct-slots-p)
                                     (direct-default-initargs 
				      nil direct-default-initargs-p))
  (declare (ignore slot-names))
  (setq direct-superclasses (if direct-superclasses-p
				(setf (slot-value class 'direct-superclasses)
				      (or direct-superclasses 
					  (list *the-class-standard-object*)
					  ))
				(slot-value class 'direct-superclasses)))
  (setq direct-slots (if direct-slots-p
			 (setf (slot-value class 'direct-slots)
			       (mapcar #'(lambda (pl)
					   (make-direct-slotd class pl))
				       direct-slots))
			 (slot-value class 'direct-slots)))
  (if direct-default-initargs-p
      (setf (plist-value class 'direct-default-initargs)
	    direct-default-initargs)
      (setq direct-default-initargs
	    (plist-value class 'direct-default-initargs)))
  (setf (plist-value class 'class-slot-cells)
	(gathering1 (collecting)
                    (dolist (dslotd direct-slots)
		      (when (eq (slotd-allocation dslotd)
				class)
			(let ((initfunction (slotd-initfunction dslotd)))
			  (gather1 (cons (slotd-name dslotd)
					 (if initfunction
					     (funcall initfunction)
					     *slot-unbound*))))))))
  (add-direct-subclasses class direct-superclasses)
  (add-slot-accessors class direct-slots))

(defmethod reinitialize-instance :before ((class std-class)
                                          &key direct-superclasses direct-slots 
                                          direct-default-initargs)
       (declare (ignore direct-default-initargs))
       (remove-direct-subclasses class (class-direct-superclasses class))
       (remove-slot-accessors class (class-direct-slots class)))

(defmethod reinitialize-instance :after ((class std-class)
                                         &rest initargs &key)
       (update-class class nil)
       (map-dependents class #'(lambda (dependent)
                                      (apply #'update-dependent class dependent initargs))))

(defun add-slot-accessors (class dslotds)
       (fix-slot-accessors class dslotds 'add))

(defun remove-slot-accessors (class dslotds)
       (fix-slot-accessors class dslotds 'remove))

(defun fix-slot-accessors (class dslotds add/remove)
       (flet ((fix (gfspec name r/w)
                   (let ((gf (ensure-generic-function gfspec)))
                        (case r/w
                            (r (if (eq add/remove 'add)
                                   (add-reader-method class gf name)
                                   (remove-reader-method class gf)))
                            (w (if (eq add/remove 'add)
                                   (add-writer-method class gf name)
                                   (remove-writer-method class gf)))))))
             (dolist (dslotd dslotds)
                 (let ((slot-name (slotd-name dslotd)))
                      (dolist (r (slotd-readers dslotd))
                          (fix r slot-name 'r))
                      (dolist (w (slotd-writers dslotd))
                          (fix w slot-name 'w))))))

(defun add-direct-subclasses (class new)
       (dolist (n new)
           (unless (memq class (class-direct-subclasses class))
                  (add-direct-subclass n class))))

(defun remove-direct-subclasses (class new)
       (let ((old (class-direct-superclasses class)))
            (dolist (o (set-difference old new))
                (remove-direct-subclass o class))))


;;; 


(defmethod finalize-inheritance ((class std-class))
       (update-class class t))


;;; Called by :after reinitialize instance whenever a class is reinitialized. The class may or may
;;; not be finalized. 


(defun update-class (class finalizep)
       (when (or finalizep (class-finalized-p class))
           (let* ((dsupers (class-direct-superclasses class))
                  (dslotds (class-direct-slots class))
                  (dinits (class-direct-default-initargs class))
                  (cpl (compute-class-precedence-list class dsupers))
                  (eslotds (compute-slots class cpl dslotds))
                  (inits (compute-default-initargs class cpl dinits)))
                 (update-cpl class cpl)
                 (update-slots class cpl eslotds)
		 (update-dinits class dinits)
                 (update-inits class inits)
                 (update-constructors class)))
       (unless finalizep
           (dolist (sub (class-direct-subclasses class))
               (update-class sub nil))))

(defun update-cpl (class cpl)
       (when (class-finalized-p class)
           (unless (equal (class-precedence-list class)
                          cpl)
                  (force-cache-flushes class)))
       (setf (slot-value class 'class-precedence-list)
             cpl))

(defun update-slots (class cpl eslotds)
       (multiple-value-bind (nlayout nwrapper-class-slots)
           (compute-storage-info cpl eslotds)
         
         ;; If there is a change in the shape of the instances then the old class is now obsolete. 
         (let* ((owrapper (class-wrapper class))
                (olayout (and owrapper (wrapper-instance-slots-layout owrapper)))
                (owrapper-class-slots (and owrapper (wrapper-class-slots owrapper)))
                (nwrapper (cond ((null owrapper)
                                 (make-wrapper class))
                                ((and (equal nlayout olayout)
                                      (not (iterate ((o (list-elements owrapper-class-slots))
                                                     (n (list-elements nwrapper-class-slots)))
                                                  (unless (eq (car o)
                                                              (car n))
                                                         (return t)))))
                                 owrapper)
                                (t 

                                 ;; This will initialize the new wrapper to have the same state as
                                 ;; the old wrapper.  We will then have to change that.  This may
                                 ;; seem like wasted work (it is), but the spec requires that we
                                 ;; call make-instances-obsolete. 
                                   (make-instances-obsolete class)
                                   (class-wrapper class)))))
               (with-slots (wrapper no-of-instance-slots slots)
                   class
                 (setf no-of-instance-slots (length nlayout)
                       slots eslotds (wrapper-instance-slots-layout nwrapper)
                       nlayout
                       (wrapper-class-slots nwrapper)
                       nwrapper-class-slots wrapper nwrapper))
               (dolist (eslotd eslotds)
                   (setf (slotd-class eslotd)
                         class)
                   (setf (slotd-instance-index eslotd)
                         (instance-slot-index nwrapper (slotd-name eslotd)))))))

(defun compute-storage-info (cpl eslotds)
       (let ((instance nil)
             (class nil))
            (dolist (eslotd eslotds)
                (let ((alloc (slotd-allocation eslotd)))
                     (cond ((eq alloc :instance)
                            (push eslotd instance))
                           ((classp alloc)
                            (push eslotd class)))))
            (values (compute-layout cpl instance)
                   (compute-class-slots class))))

(defun compute-layout (cpl instance-eslotds)
       (let* ((names (gathering1 (collecting)
                            (dolist (eslotd instance-eslotds)
                                (when (eq (slotd-allocation eslotd)
                                          :instance)
                                    (gather1 (slotd-name eslotd))))))
              (order nil))
             (labels ((rwalk (tail)
                             (when tail
                                 (rwalk (cdr tail))
                                 (dolist (ss (class-slots (car tail)))
                                     (let ((n (slotd-name ss)))
                                          (when (memq n names)
                                              (setq order (cons n order)
                                                    names
                                                    (remove n names))))))))
                    (rwalk cpl)
                    (reverse (append names order)))))

(defun compute-class-slots (eslotds)
       (gathering1 (collecting)
              (dolist (eslotd eslotds)
                  (gather1 (assoc (slotd-name eslotd)
                                  (class-slot-cells (slotd-allocation eslotd)))))))
(defun update-dinits (class dinits)
  (setf (plist-value class 'direct-default-initargs) 
	(remove-invalid dinits (class-slots class))))

(defun update-inits (class inits)
       (setf (plist-value class 'default-initargs) 
	     (remove-invalid inits (class-slots class))))

;; bug: :default-initargs aren't updated with slots are removed, so
;; update-inits removes initargs that don't have corresponding slots.

(defun remove-invalid (inits slotds &aux (return nil))
  (dolist (element inits)
    (dolist (slotd slotds)
      (if (member (car element) (slot-value slotd 'initargs))
	  (pushnew element return))))
  return)



(defmethod compute-default-initargs ((class std-class)
                                     cpl direct)
       (labels ((walk (tail)
                      (if (null tail)
                          nil
                          (let ((c (pop tail)))
                               (append (if (eq c class)
                                           direct
                                           (class-direct-default-initargs c))
                                      (walk tail))))))
              (let ((initargs (walk cpl)))
		(delete-duplicates initargs 
				   :test #'eq :key #'car :from-end t))))


;;; Protocols for constructing direct and effective slot definitions. 


(defmethod direct-slot-definition-class ((class std-class)
                                         initargs)
       (declare (ignore initargs))
       (find-class 'standard-direct-slot-definition))

(defun make-direct-slotd (class initargs)
       (let ((initargs (list* :class class initargs)))
            (apply #'make-instance (direct-slot-definition-class class initargs)
                   initargs)))


;;; 


(defmethod compute-slots ((class std-class)
                          cpl class-direct-slots)
       
       ;; As specified, we must call COMPUTE-EFFECTIVE-SLOT-DEFINITION once for each different slot
       ;; name we find in our superclasses.  Each call receives the class and a list of the dslotds
       ;; with that name. The list is in most-specific-first order. 
       (let ((name-dslotds-alist nil))
            (labels ((collect-one-class (dslotds)
                            (dolist (d dslotds)
                                (let* ((name (slotd-name d))
                                       (entry (assq name name-dslotds-alist)))
                                      (if entry
                                          (push d (cdr entry))
                                          (push (list name d)
                                                name-dslotds-alist))))))
                   (collect-one-class class-direct-slots)
                   (dolist (c (cdr cpl))
                       (collect-one-class (class-direct-slots c)))
                   (mapcar #'(lambda (direct)
                                    (compute-effective-slot-definition class (nreverse (cdr direct)))
                                    )
                          name-dslotds-alist))))

(defmethod compute-effective-slot-definition ((class std-class)
                                              dslotds)
       (let* ((initargs (compute-effective-slot-definition-initargs class dslotds))
              (class (effective-slot-definition-class class initargs)))
             (apply #'make-instance class initargs)))

(defmethod effective-slot-definition-class ((class std-class)
                                            initargs)
       (declare (ignore initargs))
       (find-class 'standard-effective-slot-definition))

(defmethod compute-effective-slot-definition-initargs ((class std-class)
                                                       direct-slotds)
       (let* ((name nil)
              (initfunction nil)
              (initform nil)
              (initargs nil)
              (allocation nil)
              (type t)
              (namep nil)
              (initp nil)
              (allocp nil))
             (dolist (slotd direct-slotds)
                 (when slotd
                     (unless namep
                         (setq name (slotd-name slotd)
                               namep t))
                     (unless initp
                         (when (slotd-initfunction slotd)
                             (setq initform (slotd-initform slotd)
                                   initfunction
                                   (slotd-initfunction slotd)
                                   initp t)))
                     (unless allocp
                         (setq allocation (slotd-allocation slotd)
                               allocp t))
                     (setq initargs (append (slotd-initargs slotd)
                                           initargs))
                     (let ((slotd-type (slotd-type slotd)))
                          (setq type (cond ((null type)
                                            slotd-type)
                                           ((subtypep type slotd-type)
                                            type)
                                           (t `(and ,type ,slotd-type)))))))
             (list :name name :initform initform :initfunction initfunction :initargs initargs 
                   :allocation allocation :type type)))


;;; NOTE: For bootstrapping considerations, these can't use make-instance to make the method object.
;;; They have to use make-a-method which is a specially bootstrapped mechanism for making standard
;;; methods. 


(defmethod add-reader-method ((class std-class)
                              generic-function slot-name)
       (let* ((name (class-name class))
              (method (make-a-method 'standard-reader-method nil (list (or name 'standard-object))
                             (list class)
                             (make-reader-method-function class slot-name)
                             "automatically generated reader method" slot-name)))
             (add-method generic-function method)))

(defmethod add-writer-method ((class std-class)
                              generic-function slot-name)
       (let* ((name (class-name class))
              (method (make-a-method 'standard-writer-method nil (list 'new-value (or name
                                                                                      
                                                                                      '
                                                                                      standard-object
                                                                                      ))
                             (list *the-class-t* class)
                             (make-writer-method-function class slot-name)
                             "automatically generated writer method" slot-name)))
             (add-method generic-function method)))

(defmethod remove-reader-method ((class std-class)
                                 generic-function)
       (let ((method (get-method generic-function nil (list class)
                            nil)))
            (when method (remove-method generic-function method))))

(defmethod remove-writer-method ((class std-class)
                                 generic-function)
       (let ((method (get-method generic-function nil (list *the-class-t* class)
                            nil)))
            (when method (remove-method generic-function method))))


;;; make-reader-method-function and make-write-method function are NOT part of the standard
;;; protocol.  They are however useful, CLOS makes uses makes use of them internally and documents
;;; them for CLOS users. *** This needs work to make type testing by the writer functions which ***
;;; do type testing faster.  The idea would be to have one constructor *** for each possible type
;;; test.  In order to do this it would be nice *** to have help from inform-type-system-about-class
;;; and friends. *** There is a subtle bug here which is going to have to be fixed. *** Namely, the
;;; simplistic use of the template has to be fixed.  We *** have to give the optimize-slot-value
;;; method the user might have *** defined for this metclass a chance to run. 


(defmethod make-reader-method-function ((class standard-class)
                                        slot-name)
       (make-std-reader-method-function slot-name))

(defmethod make-writer-method-function ((class standard-class)
                                        slot-name)
       (make-std-writer-method-function slot-name))

(defun make-std-reader-method-function (slot-name)
       #'(lambda (instance)
                (slot-value instance slot-name)))

(defun make-std-writer-method-function (slot-name)
       #'(lambda (nv instance)
                (setf (slot-value instance slot-name)
                      nv)))

                                                             ; inform-type-system-about-class
                                                             ; make-type-predicate 



;;; These are NOT part of the standard protocol.  They are internal mechanism which CLOS uses to
;;; *try* and tell the type system about class definitions. In a more fully integrated
;;; implementation of CLOS, the type system would know about class objects and class names in a more
;;; fundamental way and the mechanism used to inform the type system about new classes would be
;;; different. 


(defmethod inform-type-system-about-class ((class std-class)
                                           name)
       (let ((predicate-name (make-type-predicate-name name)))
            (setf (symbol-function predicate-name)
                  (make-type-predicate name))
            (do-satisfies-deftype name predicate-name)
	    (setf (gethash name lisp::*typep-hash-table*)
		  predicate-name))) ;makes typep significantly faster...

(defun make-type-predicate (name)
       #'(lambda (x)
                (not (null (memq (find-class name)
                                 (cond ((std-instance-p x)
                                        (class-precedence-list (std-instance-class x)))
                                       ((fsc-instance-p x)
                                        (class-precedence-list (fsc-instance-class x)))))))))


;;; These 4 definitions appear here for bootstrapping reasons.  Logically, they should be in the
;;; construct file.  For documentation purposes, a copy of these definitions appears in the
;;; construct file.  If you change one of the definitions here, be sure to change the copy there. 


(defvar *initialization-generic-functions* (list #'make-instance #'default-initargs 
                                                 #'allocate-instance #'initialize-instance
                                                 #'shared-initialize))

(defmethod maybe-update-constructors ((generic-function generic-function)
                                      (method method))
       (when (memq generic-function *initialization-generic-functions*)
           (labels ((recurse (class)
                           (update-constructors class)
                           (dolist (subclass (class-direct-subclasses class))
                               (recurse subclass))))
                  (when (classp (car (method-specializers method)))
                      (recurse (car (method-specializers method)))))))

(defmethod update-constructors ((class std-class))
       (dolist (cons (class-constructors class))
           (install-lazy-constructor-installer cons)))

(defmethod update-constructors ((class class))
       nil)

(defmethod compatible-meta-class-change-p (class proto-new-class)
       (eq (class-of class)
           (class-of proto-new-class)))

(defmethod check-super-metaclass-compatibility ((class t)
                                                (new-super t))
       (unless (eq (class-of class)
                   (class-of new-super))
           (error "The class ~S was specified as a~%super-class of the class ~S;~%~
            but the meta-classes ~S and~%~S are incompatible." new-super class (class-of new-super)
                  (class-of class))))


;;; 


(defun force-cache-flushes (class)
       (let* ((owrapper (class-wrapper class))
              (state (wrapper-state owrapper)))
             
             ;; We only need to do something if the state is still T.  If the state isn't T, it will
             ;; be FLUSH or OBSOLETE, and both of those will already be doing what we want.  In
             ;; particular, we must be sure we never change an OBSOLETE into a FLUSH since OBSOLETE
             ;; means do what FLUSH does and then some. 
             (when (eq state 't)
                 (let ((nwrapper (make-wrapper class)))
                      (setf (wrapper-instance-slots-layout nwrapper)
                            (wrapper-instance-slots-layout owrapper))
                      (setf (wrapper-class-slots nwrapper)
                            (wrapper-class-slots owrapper))
                      (without-interrupts (setf (slot-value class 'wrapper)
                                                nwrapper)
                             (invalidate-wrapper owrapper 'flush nwrapper))
                      (update-constructors class)))))

                                                             ; ??? ***


(defun flush-cache-trap (owrapper nwrapper instance)
       (declare (ignore owrapper))
       (set-wrapper instance nwrapper))


;;; make-instances-obsolete can be called by user code.  It will cause the next access to the
;;; instance (as defined in 88-002R) to trap through the update-instance-for-redefined-class
;;; mechanism. 


(defmethod make-instances-obsolete ((class std-class))
       (let ((owrapper (class-wrapper class))
             (nwrapper (make-wrapper class)))
            (setf (wrapper-instance-slots-layout nwrapper)
                  (wrapper-instance-slots-layout owrapper))
            (setf (wrapper-class-slots nwrapper)
                  (wrapper-class-slots owrapper))
            (without-interrupts (setf (slot-value class 'wrapper)
                                      nwrapper)
                   (invalidate-wrapper owrapper 'obsolete nwrapper)
                   class)))

(defmethod make-instances-obsolete ((class symbol))
       (make-instances-obsolete (find-class class)))


;;; obsolete-instance-trap is the internal trap that is called when we see an obsolete instance. 
;;; The times when it is called are: - when the instance is involved in method lookup - when
;;; attempting to access a slot of an instance It is not called by class-of, wrapper-of, or any of
;;; the low-level instance access macros. Of course these times when it is called are an internal
;;; implementation detail of CLOS and are not part of the documented description of when the obsolete
;;; instance update happens.  The documented description is as it appears in 88-002R. This has to
;;; return the new wrapper, so it counts on all the methods on obsolete-instance-trap-internal to
;;; return the new wrapper.  It also does a little internal error checking to make sure that the
;;; traps are only happening when they should, and that the trap methods are computing apropriate
;;; new wrappers. 


(defun obsolete-instance-trap (owrapper nwrapper instance)
       
       ;; local  --> local        transfer local  --> shared       discard local  -->  --         
       ;; discard shared --> local        transfer shared --> shared       discard shared -->  --   
       ;; discard --    --> local        add --    --> shared        -- 
       (let* ((class (wrapper-class nwrapper))
              (guts (allocate-instance class))
                                                             ; ??? allocate-instance ???
              (olayout (wrapper-instance-slots-layout owrapper))
              (nlayout (wrapper-instance-slots-layout nwrapper))
              (oslots (get-slots instance))
              (nslots (get-slots guts))
              (oclass-slots (wrapper-class-slots owrapper))
              (added nil)
              (discarded nil)
              (plist nil))
             
             ;; Go through all the old local slots. 
             (iterate ((name (list-elements olayout))
                       (opos (interval :from 0)))
                    (let ((npos (posq name nlayout)))
                         (if npos
                             (setf (svref nslots npos)
                                   (svref oslots opos))
                             (progn (push name discarded)
                                    (unless (eq (svref oslots opos)
                                                *slot-unbound*)
                                        (setf (getf plist name)
                                              (svref oslots opos)))))))
             
             ;; Go through all the old shared slots. 
             (iterate ((oclass-slot-and-val (list-elements oclass-slots)))
                    (let ((name (car oclass-slot-and-val))
                          (val (cdr oclass-slot-and-val)))
                         (let ((npos (posq name nlayout)))
                              (if npos
                                  (setf (svref nslots npos)
                                        (cdr oclass-slot-and-val))
                                  (progn (push name discarded)
                                         (unless (eq val *slot-unbound*)
                                             (setf (getf plist name)
                                                   val)))))))
             
             ;; Go through all the new local slots to compute the added slots. 
             (dolist (nlocal nlayout)
                 (unless (or (memq nlocal olayout)
                             (assq nlocal oclass-slots))
                        (push nlocal added)))
             (without-interrupts (set-wrapper instance nwrapper)
                    (set-slots instance nslots))
             (update-instance-for-redefined-class instance added discarded plist)
             nwrapper))


;;; 


(defmacro change-class-internal (wrapper-fetcher slots-fetcher alloc)
       `(let* ((old-class (class-of instance))
               (copy (,alloc old-class))
               (guts (,alloc new-class))
               (new-wrapper (,wrapper-fetcher guts))
               (old-wrapper (class-wrapper old-class))
               (old-layout (wrapper-instance-slots-layout old-wrapper))
               (new-layout (wrapper-instance-slots-layout new-wrapper))
               (old-slots (,slots-fetcher instance))
               (new-slots (,slots-fetcher guts))
               (old-class-slots (wrapper-class-slots old-wrapper)))
              
              ;; "The values of local slots specified by both the class Cto and Cfrom are retained. 
              ;; If such a local slot was unbound, it remains unbound." 
              (iterate ((new-slot (list-elements new-layout))
                        (new-position (interval :from 0)))
                     (let ((old-position (position new-slot old-layout :test #'eq)))
                          (when old-position
                              (setf (svref new-slots new-position)
                                    (svref old-slots old-position)))))
              
              ;; "The values of slots specified as shared in the class Cfrom and as local in the
              ;; class Cto are retained." 
              (iterate ((slot-and-val (list-elements old-class-slots)))
                     (let ((position (position (car slot-and-val)
                                            new-layout :test #'eq)))
                          (when position
                              (setf (svref new-slots position)
                                    (cdr slot-and-val)))))
              
              ;; Make the copy point to the old instance's storage, and make the old instance point
              ;; to the new storage. 
              (without-interrupts (setf (,slots-fetcher copy)
                                        old-slots)
                     (setf (,wrapper-fetcher instance)
                           new-wrapper)
                     (setf (,slots-fetcher instance)
                           new-slots))
              (update-instance-for-different-class copy instance)
              instance))

(defmethod change-class ((instance standard-object)
                         (new-class standard-class))
       (unless (std-instance-p instance)
           (error "Can't change the class of ~S to ~S~@
            because it isn't already an instance with metaclass~%~S." instance new-class 
                  'standard-class))
       (change-class-internal std-instance-wrapper std-instance-slots allocate-instance))

(defmethod change-class ((instance standard-object)
                         (new-class funcallable-standard-class))
       (unless (fsc-instance-p instance)
           (error "Can't change the class of ~S to ~S~@
            because it isn't already an instance with metaclass~%~S." instance new-class 
                  'funcallable-standard-class))
       (change-class-internal fsc-instance-wrapper fsc-instance-slots allocate-instance))

(defmethod change-class ((instance t)
                         (new-class-name symbol))
       (change-class instance (find-class new-class-name)))


;;; The metaclass BUILT-IN-CLASS This metaclass is something of a weird creature.  By this point,
;;; all instances of it which will exist have been created, and no instance is ever created by
;;; calling MAKE-INSTANCE. But, there are other parts of the protcol we must follow and those
;;; definitions appear here. 


(defmethod shared-initialize :before ((class built-in-class)
                                      slot-names &rest initargs)
       (declare (ignore slot-names))
       (error "Attempt to initialize or reinitialize a built in class."))

(defmethod class-direct-slots ((class built-in-class))
       nil)

(defmethod class-slots ((class built-in-class))
       nil)

(defmethod class-direct-default-initargs ((class built-in-class))
       nil)

(defmethod class-default-initargs ((class built-in-class))
       nil)

(defmethod check-super-metaclass-compatibility ((c class)
                                                (s built-in-class))
       (or (eq s *the-class-t*)
           (error "~S cannot have ~S as a super.~%~
              The class ~S is the only built in class that can be a~%~
              superclass of a standard class." c s *the-class-t*)))


;;; 


(defmethod check-super-metaclass-compatibility ((c std-class)
                                                (f forward-referenced-class))
       't)


;;; 


(defmethod add-dependent ((metaobject dependent-update-mixin)
                          dependent)
       (pushnew dependent (plist-value metaobject 'dependents)))

(defmethod remove-dependent ((metaobject dependent-update-mixin)
                             dependent)
       (setf (plist-value metaobject 'dependents)
             (delete dependent (plist-value metaobject 'dependents))))

(defmethod map-dependents ((metaobject dependent-update-mixin)
                           function)
       (dolist (dependent (plist-value metaobject 'dependents))
           (funcall function dependent)))
