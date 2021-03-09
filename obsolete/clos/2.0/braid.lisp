;;;-*-Mode:LISP; Package:(CLOS (LISP WALKER)); Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;;
;;; Bootstrapping the meta-braid.
;;;
;;; The code in this file takes the early definitions that have been saved
;;; up and actually builds those class objects.  This work is largely driven
;;; off of those class definitions, but the fact that STANDARD-CLASS is the
;;; class of all metaclasses in the braid is built into this code pretty
;;; deeply.
;;;
;;; 

(in-package 'clos)

(defun early-class-definition (class-name)
  (or (find class-name *early-class-definitions* :key #'ecd-class-name)
      (error "~S is not a class in *early-class-definitions*." class-name)))

(defun canonical-slot-name (canonical-slot)
  (getf canonical-slot :name))

(defun early-collect-inheritance (class-name)
  (declare (values slots cpl default-initargs direct-subclasses))
  (let ((cpl (early-collect-cpl class-name)))
    (values (early-collect-slots cpl)
	    cpl
	    (early-collect-default-initargs cpl)
	    (gathering1 (collecting)
	      (dolist (definition *early-class-definitions*)
		(when (memq class-name (ecd-superclass-names definition))
		  (gather1 (ecd-class-name definition))))))))

(defun early-collect-cpl (class-name)
  (labels ((walk (c)
	     (let* ((definition (early-class-definition c))
		    (supers (ecd-superclass-names definition)))
	       (cons c
		     (apply #'append (mapcar #'early-collect-cpl supers))))))
    (remove-duplicates (walk class-name) :from-end nil :test #'eq)))

(defun early-collect-slots (cpl)
  (let* ((definitions (mapcar #'early-class-definition cpl))
	 (super-slots (mapcar #'ecd-canonical-slots definitions))
	 (slots (apply #'append (reverse super-slots))))
    (dolist (s1 slots)
      (let ((name1 (canonical-slot-name s1)))
	(dolist (s2 (cdr (memq s1 slots)))
	  (when (eq name1 (canonical-slot-name s2))
	    (error "More than one early class defines a slot with the~%~
                    name ~S.  This can't work because the bootstrap~%~
                    object system doesn't know how to compute effective~%~
                    slots."
		   name1)))))
    slots))

(defun early-collect-default-initargs (cpl)
  (let ((default-initargs ()))
    (dolist (class-name cpl)
      (let ((definition (early-class-definition class-name)))
	(dolist (option (ecd-other-initargs definition))
	  (unless (eq (car option) :default-initargs)
	    (error "The defclass option ~S is not supported by the bootstrap~%~
                    object system."
		   (car option)))
	  (setq default-initargs
		(nconc default-initargs (reverse (cdr option)))))))
    (reverse default-initargs)))


;;;
;;; bootstrap-get-slot and bootstrap-set-slot are used to access and change
;;; the values of slots during bootstrapping.  During bootstrapping, there
;;; are only two kinds of objects whose slots we need to access, CLASSes
;;; and SLOTDs.  The first argument to these functions tells whether the
;;; object is a CLASS or a SLOTD.
;;;
;;; Note that the way this works it stores the slot in the same place in
;;; memory that the full object system will expect to find it later.  This
;;; is critical to the bootstrapping process, the whole changeover to the
;;; full object system is predicated on this.
;;;
;;; One important point is that the layout of standard classes and standard
;;; slots must be computed the same way in this file as it is by the full
;;; object system later.
;;; 
(defun bootstrap-get-slot (type object slot-name)
  (let ((index (bootstrap-slot-index type slot-name)))
    (svref (std-instance-slots object) index)))

(defun bootstrap-set-slot (type object slot-name new-value)
  (let ((index (bootstrap-slot-index type slot-name)))
    (setf (svref (std-instance-slots object) index) new-value)))

(defvar *std-class-slots*
	(mapcar #'canonical-slot-name
		(early-collect-inheritance 'standard-class)))

(defvar *bin-class-slots*
	(mapcar #'canonical-slot-name
		(early-collect-inheritance 'built-in-class)))

(defvar *std-slotd-slots*
	(mapcar #'canonical-slot-name
		(early-collect-inheritance 'standard-slot-definition)))

(defun bootstrap-slot-index (type slot-name)
  (or (position slot-name (ecase type
			    (std-class *std-class-slots*)
			    (bin-class *bin-class-slots*)
			    (std-slotd *std-slotd-slots*)))
      (error "~S not found" slot-name)))


;;;
;;; bootstrap-meta-braid
;;;
;;; This function builds the base metabraid from the early class definitions.
;;;   
(defun bootstrap-meta-braid ()
  (let* ((std-class-size (length *std-class-slots*))
         (std-class (%allocate-instance--class std-class-size))
         (std-class-wrapper (make-wrapper std-class))
	 (built-in-class (%allocate-instance--class std-class-size))
	 (built-in-class-wrapper (make-wrapper built-in-class))
	 (direct-slotd    (%allocate-instance--class std-class-size))
	 (effective-slotd (%allocate-instance--class std-class-size))
	 (direct-slotd-wrapper    (make-wrapper direct-slotd))
	 (effective-slotd-wrapper (make-wrapper effective-slotd)))
    ;;
    ;; First, make a class metaobject for each of the early classes.  For
    ;; each metaobject we also set its wrapper.  Except for the class T,
    ;; the wrapper is always that of STANDARD-CLASS.
    ;; 
    (dolist (definition *early-class-definitions*)
      (let* ((name (ecd-class-name definition))
	     (meta (ecd-metaclass definition))
             (class (case name
                      (standard-class                     std-class)
                      (standard-direct-slot-definition    direct-slotd)
		      (standard-effective-slot-definition effective-slotd)
		      (built-in-class                     built-in-class)
                      (otherwise
			(%allocate-instance--class std-class-size)))))
	(unless (eq name t)
	  (inform-type-system-about-class class name))
	(setf (std-instance-wrapper class)
	      (ecase meta
		(standard-class std-class-wrapper)
		(built-in-class built-in-class-wrapper)))
        (setf (find-class name) class)))
    ;;
    ;;
    ;;
    (dolist (definition *early-class-definitions*)
      (let ((name (ecd-class-name definition))
	    (source (ecd-source definition))
	    (direct-supers (ecd-superclass-names definition))
	    (direct-slots  (ecd-canonical-slots definition))
	    (other-initargs (ecd-other-initargs definition)))
	(let ((direct-default-initargs
		(getf other-initargs :default-initargs)))
	  (multiple-value-bind (slots cpl default-initargs direct-subclasses)
	      (early-collect-inheritance name)
	    (let* ((class (find-class name))
		   (wrapper
		     (cond
		       ((eq class std-class)       std-class-wrapper)
		       ((eq class direct-slotd)    direct-slotd-wrapper)
		       ((eq class effective-slotd) effective-slotd-wrapper)
		       ((eq class built-in-class)  built-in-class-wrapper)
		       (t (make-wrapper class))))
		   (proto nil))
	      (cond ((eq name 't)
		     (setq *the-wrapper-of-t* wrapper
			   *the-class-t* class))
		    ((memq name '(standard-object 
				  standard-class
				  standard-effective-slot-definition))
		     (set (intern (format nil "*THE-CLASS-~A*" (symbol-name name))
				  *the-clos-package*)
			  class)))
	      (dolist (slot slots)
		(unless (eq (getf slot :allocation :instance) :instance)
		  (error "Slot allocation ~S not supported in bootstrap.")))
	      
	      (setf (wrapper-instance-slots-layout wrapper)
		    (mapcar #'canonical-slot-name slots))
	      (setf (wrapper-class-slots wrapper)
		    ())
	      
	      (setq proto (%allocate-instance--class (length slots)))
	      (setf (std-instance-wrapper proto) wrapper)
	    
	      (setq direct-slots
		    (bootstrap-make-slot-definitions name direct-slots
						     direct-slotd-wrapper nil))
	      (setq slots
		    (bootstrap-make-slot-definitions name slots
						     effective-slotd-wrapper t))
	      
	      (bootstrap-initialize-std-class
		class name source
		direct-supers direct-subclasses cpl wrapper
		direct-slots slots direct-default-initargs default-initargs
		proto)
	      
	      (dolist (slotd direct-slots)
		(bootstrap-accessor-definitions
		  name
		  (bootstrap-get-slot 'std-slotd slotd 'name)
		  (bootstrap-get-slot 'std-slotd slotd 'readers)
		  (bootstrap-get-slot 'std-slotd slotd 'writers))))))))))

(defun bootstrap-accessor-definitions (class-name slot-name readers writers)
  (flet ((do-reader-definition (reader)
	   (add-method
	     (ensure-generic-function reader)
	     (make-a-method
	       'standard-reader-method
	       ()
	       (list class-name)
	       (list class-name)
	       (make-std-reader-method-function slot-name)
	       "automatically generated reader method"
	       slot-name)))
	 (do-writer-definition (writer)
	   (add-method
	     (ensure-generic-function writer)
	     (make-a-method
	       'standard-writer-method
	       ()
	       (list 'new-value class-name)
	       (list 't class-name)
	       (make-std-writer-method-function slot-name)
	       "automatically generated writer method"
	       slot-name))))
    (dolist (reader readers) (do-reader-definition reader))
    (dolist (writer writers) (do-writer-definition writer))))

;;;
;;; Initialize a standard class metaobject.
;;;
(defun bootstrap-initialize-std-class
       (class
	name definition-source direct-supers direct-subclasses cpl wrapper
	direct-slots slots direct-default-initargs default-initargs proto)
  (flet ((classes (names) (mapcar #'find-class names))
	 (set-slot (slot-name value)
	   (bootstrap-set-slot 'std-class class slot-name value)))
    
    (set-slot 'name name)
    (set-slot 'source definition-source)
    (set-slot 'class-precedence-list (classes cpl))
    (set-slot 'direct-superclasses (classes direct-supers))
    (set-slot 'direct-slots direct-slots)
    (set-slot 'direct-subclasses (classes direct-subclasses))
    (set-slot 'direct-methods (cons nil nil))
    (set-slot 'no-of-instance-slots (length slots))
    (set-slot 'slots slots)
    (set-slot 'wrapper wrapper)
    (set-slot 'prototype proto)
    (set-slot 'plist
	      `(,@(and direct-default-initargs
		       `(direct-default-initargs ,direct-default-initargs))
		,@(and default-initargs
		       `(default-initargs ,default-initargs))))
    ))

;;;
;;; Initialize a built-in-class metaobject.
;;;
(defun bootstrap-initialize-bin-class
       (class
	name definition-source direct-supers direct-subclasses cpl wrapper)
  (flet ((classes (names) (mapcar #'find-class names))
	 (set-slot (slot-name value)
	   (bootstrap-set-slot 'bin-class class slot-name value)))
    
    (set-slot 'name name)
    (set-slot 'source definition-source)
    (set-slot 'direct-superclasses (classes direct-supers))
    (set-slot 'direct-subclasses (classes direct-subclasses))
    (set-slot 'direct-methods (cons nil nil))
    (set-slot 'class-precedence-list (classes cpl))
    (set-slot 'wrapper wrapper)))

(defun bootstrap-make-slot-definitions (name slots wrapper e-p)
  (mapcar #'(lambda (slot) (bootstrap-make-slot-definition name slot wrapper e-p))
          slots))

(defun bootstrap-make-slot-definition (name slot wrapper e-p)  
  (let ((slotd (%allocate-instance--class (length *std-slotd-slots*))))
    (setf (std-instance-wrapper slotd) wrapper)
    (flet ((get-val (name) (getf slot name))
	   (set-val (name val) (bootstrap-set-slot 'std-slotd slotd name val)))
      (set-val 'name         (get-val :name))
      (set-val 'initform     (get-val :initform))
      (set-val 'initfunction (get-val :initfunction))      
      (set-val 'initargs     (get-val :initargs))
      (set-val 'readers      (get-val :readers))
      (set-val 'writers      (get-val :writers))
      (set-val 'allocation   :instance)
      (set-val 'type         (get-val :type))
      (set-val 'class        nil)
      (set-val 'instance-index nil)
      (when (and (eq name 'standard-class) (eq (get-val :name) 'slots) e-p)
	(setq *the-eslotd-standard-class-slots* slotd))
      slotd)))

(defun bootstrap-built-in-classes ()
  ;;
  ;; First make sure that all the supers listed in *built-in-class-lattice*
  ;; are themselves defined by *built-in-class-lattice*.  This is just to
  ;; check for typos and other sorts of brainos.
  ;; 
  (dolist (e *built-in-classes*)
    (dolist (super (cadr e))
      (unless (or (eq super 't)
		  (assq super *built-in-classes*))
	(error "In *built-in-classes*: ~S has ~S as a super,~%~
                but ~S is not itself a class in *built-in-classes*."
	       (car e) super super))))

  ;;
  ;; In the first pass, we create a skeletal object to be bound to the
  ;; class name.
  ;;
  (let* ((built-in-class (find-class 'built-in-class))
	 (built-in-class-wrapper (class-wrapper built-in-class))
	 (bin-class-size (length *bin-class-slots*)))
    (dolist (e *built-in-classes*)
      (let ((class (%allocate-instance--class bin-class-size)))
	(setf (std-instance-wrapper class) built-in-class-wrapper)
	(setf (find-class (car e)) class))))

  ;;
  ;; In the second pass, we initialize the class objects.
  ;;
  (dolist (e *built-in-classes*)
    (destructuring-bind (name supers subs cpl) e
      (let* ((class (find-class name))
	     (wrapper (make-wrapper class)))
	(set (get-built-in-class-symbol name) class)
	(set (get-built-in-wrapper-symbol name) wrapper)

	(setf (wrapper-instance-slots-layout wrapper) ()
	      (wrapper-class-slots wrapper) ())

	(bootstrap-initialize-bin-class class
					name nil
					supers subs
					(cons name cpl) wrapper)
	))))


;;;
;;;
;;;

(defun class-of (x) (wrapper-class (wrapper-of x)))

(defun wrapper-of (x) 
  (or (and (std-instance-p x)
	   (std-instance-wrapper x))
      (and (fsc-instance-p x)
	   (fsc-instance-wrapper x))
      (built-in-wrapper-of x)
      (error "Can't determine wrapper of ~S" x)))


(eval-when (compile eval)

(defun make-built-in-class-subs ()
  (mapcar #'(lambda (e)
	      (let ((class (car e))
		    (class-subs ()))
		(dolist (s *built-in-classes*)
		  (when (memq class (cadr s)) (pushnew (car s) class-subs)))
		(cons class class-subs)))
	  (cons '(t) *built-in-classes*)))

(defun make-built-in-class-tree ()
  (let ((subs (make-built-in-class-subs)))
    (labels ((descend (class)
	       (cons class (mapcar #'descend (cdr (assq class subs))))))
      (descend 't))))

(defun make-built-in-wrapper-of-body ()
  (make-built-in-wrapper-of-body-1 (make-built-in-class-tree)
				   'x
				   #'get-built-in-wrapper-symbol))

(defun make-built-in-wrapper-of-body-1 (tree var get-symbol)
  (let ((*specials* ()))
    (declare (special *specials*))
    (let ((inner (make-built-in-wrapper-of-body-2 tree var get-symbol)))
      `(locally (declare (special .,*specials*)) ,inner))))

(defun make-built-in-wrapper-of-body-2 (tree var get-symbol)
  (declare (special *specials*))
  (let ((symbol (funcall get-symbol (car tree))))
    (push symbol *specials*)
    (let ((sub-tests
	    (mapcar #'(lambda (x)
			(make-built-in-wrapper-of-body-2 x var get-symbol))
		    (cdr tree))))
      `(and (typep ,var ',(car tree))
	    ,(if sub-tests
		 `(or ,.sub-tests ,symbol)
		 symbol)))))
)

(defun built-in-wrapper-of (x)
  #.(make-built-in-wrapper-of-body))




(eval-when (load eval)
  (clrhash *find-class*)
  (bootstrap-meta-braid)
  (bootstrap-built-in-classes)
  (setq *boot-state* 'braid)
  (setf (symbol-function 'load-defclass) #'real-load-defclass)
  )


;;;
;;; All of these method definitions must appear here because the bootstrap
;;; only allows one method per generic function until the braid is fully
;;; built.
;;;
(defmethod print-object (instance stream)
  (printing-random-thing (instance stream)
    (let ((name (class-name (class-of instance))))
      (if name
	  (format stream "~S" name)
	  (format stream "Instance")))))

(defmethod print-object ((class class) stream)
  (named-object-print-function class stream))

(defmethod print-object ((slotd standard-slot-definition) stream)
  (named-object-print-function slotd stream))

(defun named-object-print-function (instance stream
				    &optional (extra nil extra-p))
  (printing-random-thing (instance stream)
    (if extra-p					
	(format stream "~A ~S ~:S"
		(capitalize-words (class-name (class-of instance)))
		(slot-value-or-default instance 'name)
		extra)
	(format stream "~A ~S"
		(capitalize-words (class-name (class-of instance)))
		(slot-value-or-default instance 'name)))))


;;;
;;;
;;;
;(defmethod shared-initialize :after ((class class) slot-names &key name)
;  (declare (ignore slot-names))
;  (setf (slot-value class 'name) name))
;
;
;(defmethod shared-initialize :after ((class std-class)
;				     slot-names
;				     &key direct-superclasses
;					  direct-slots)
; (declare (ignore slot-names))
; (setf (slot-value class 'direct-superclasses) direct-superclasses
;	(slot-value class 'direct-slots) direct-slots))

;;;
;;;
;;;
(defmethod shared-initialize :after ((slotd standard-slot-definition)
				     slot-names
				     &key class
					  name
					  initform
					  initfunction
					  initargs 
					  (allocation :instance)
					  (type t)
					  readers
					  writers)
  (declare (ignore slot-names))
  (setf (slot-value slotd 'name) name
	(slot-value slotd 'initform) initform
	(slot-value slotd 'initfunction) initfunction
	(slot-value slotd 'initargs) initargs 
	(slot-value slotd 'allocation) (if (eq allocation :class) class allocation)
	(slot-value slotd 'type) type
	(slot-value slotd 'readers) readers
	(slot-value slotd 'writers) writers))

