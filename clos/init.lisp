;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-

;;;. Copyright (c) 1991 by Venue

(in-package "CLOS")

;;; this file defines the
;;; initialization and related protocols. 


(defmethod make-instance ((class std-class)
                          &rest initargs)
       (unless (class-finalized-p class)
              (finalize-inheritance class))
       (setq initargs (default-initargs class initargs))
       (when initargs
           (when (and (eq *boot-state* 'complete)
                      (let ((tail initargs))
                           (loop (unless tail (return t))
                                 (when (eq (car tail)
                                           ':allow-other-keys)
                                       (return nil))
                                 (setq tail (cddr tail)))))
               (check-initargs-1 class initargs (append (compute-applicable-methods 
                                                               #'allocate-instance (list class))
                                                       (compute-applicable-methods
                                                        #'initialize-instance
                                                        (list (class-prototype class)))
                                                       (compute-applicable-methods
                                                        #'shared-initialize
                                                        (list (class-prototype class)
                                                              t))))))
       (let ((instance (apply #'allocate-instance class initargs)))
            (apply #'initialize-instance instance initargs)
            instance))

(defmethod make-instance ((class-name symbol)
                          &rest initargs)
       (apply #'make-instance (find-class class-name)
              initargs))

(defvar *default-initargs-flag* (list nil))

(defmethod default-initargs ((class std-class)
                             supplied-initargs)
       
       ;; This implementation of default initargs is critically dependent on all-default-initargs
       ;; not having any duplicate initargs in it. 
       (let ((all-default (class-default-initargs class))
             (miss *default-initargs-flag*))
            (flet ((getf* (plist key)
                          (do nil
                              ((null plist)
                               miss)
                            (if (eq (car plist)
                                    key)
                                (return (cadr plist))
                                (setq plist (cddr plist))))))
                  (labels ((default-1 (tail)
                                  (if (null tail)
                                      nil
                                      (if (eq (getf* supplied-initargs (caar tail))
                                              miss)
                                          (list* (caar tail)
                                                 (funcall (cadar tail))
                                                 (default-1 (cdr tail)))
                                          (default-1 (cdr tail))))))
                         (append supplied-initargs (default-1 all-default))))))

(defmethod initialize-instance ((instance standard-object)
                                &rest initargs)
       (apply #'shared-initialize instance t initargs))

(defmethod reinitialize-instance ((instance standard-object)
                                  &rest initargs)
       (when initargs
           (when (eq *boot-state* 'complete)
               (check-initargs-1 (class-of instance)
                      initargs
                      (append (compute-applicable-methods #'reinitialize-instance (list instance))
                             (compute-applicable-methods #'shared-initialize (list instance t))))))
       (apply #'shared-initialize instance nil initargs)
       instance)

(defmethod update-instance-for-different-class ((previous standard-object)
                                                (current standard-object)
                                                &rest initargs)
       (when initargs
           (check-initargs-1 (class-of current)
                  initargs
                  (append (compute-applicable-methods #'update-instance-for-different-class
                                 (list previous current))
                         (compute-applicable-methods #'shared-initialize (list current t)))))
       
       ;; First we must compute the newly added slots.  The spec defines newly added slots as "those
       ;; local slots for which no slot of the same name exists in the previous class." 
       (let ((added-slots 'nil)
             (current-slotds (class-slots (class-of current)))
             (previous-slot-names (mapcar #'slotd-name (class-slots (class-of previous)))))
            (dolist (slotd current-slotds)
                (if (and (not (memq (slotd-name slotd)
                                    previous-slot-names))
                         (eq (slotd-allocation slotd)
                             ':instance))
                    (push (slotd-name slotd)
                          added-slots)))
            (apply #'shared-initialize current added-slots initargs)))

(defmethod update-instance-for-redefined-class ((instance standard-object)
                                                added-slots discarded-slots property-list &rest 
                                                initargs)
       (declare (ignore discarded-slots property-list))
       (when initargs
           (check-initargs-1 (class-of instance)
                  initargs
                  (append (compute-applicable-methods #'update-instance-for-redefined-class
                                 (list instance))
                         (compute-applicable-methods #'shared-initialize (list instance nil)))))
       (apply #'shared-initialize instance added-slots initargs))

(defmethod shared-initialize ((instance standard-object)
                              slot-names &rest initargs)
       
       ;; initialize the instance's slots in a two step process 1) A slot for which one of the
       ;; initargs in initargs can set the slot, should be set by that initarg.  If more than one
       ;; initarg in initargs can set the slot, the leftmost one should set it. 2) Any slot not set
       ;; by step 1, may be set from its initform by step 2.  Only those slots specified by the
       ;; slot-names argument are set.  If slot-names is: T any slot not set in step 1 is set from
       ;; its initform <list of slot names> any slot in the list, and not set in step 1 is set from
       ;; its initform () no slots are set from initforms 
       (let* ((class (class-of instance))
              (slotds (class-slots class)))
             (dolist (slotd slotds)
                 (let ((slot-name (slotd-name slotd))
                       (slot-initargs (slotd-initargs slotd)))
                      (flet ((from-initargs nil 

                                    ;; Try to initialize the slot from one of the initargs. If we
                                    ;; succeed return T, otherwise return nil. 
                                    (doplist (initarg val)
                                           initargs
                                           (when (memq initarg slot-initargs)
                                               (setf (slot-value instance slot-name)
                                                     val)
                                               (return 't))))
                             (from-initforms nil 

                                    ;; Try to initialize the slot from its initform.  This returns
                                    ;; no meaningful value. 
                                    (if (and slot-names (or (eq slot-names 't)
                                                            (memq slot-name slot-names))
                                             (not (slot-boundp instance slot-name)))
                                        (let ((initfunction (slotd-initfunction slotd)))
                                             (when initfunction
                                                 (setf (slot-value instance slot-name)
                                                       (funcall initfunction)))))))
                            (or (from-initargs)
                                (from-initforms))))))
       instance)


;;; if initargs are valid return nil, otherwise signal an error 


(defun check-initargs-1 (class initargs methods)
       (let ((legal (apply #'append (mapcar #'slotd-initargs (class-slots class)))))
            (unless (getf initargs :allow-other-keys)
                
                ;; Add to the set of slot-filling initargs the set of initargs that are accepted by
                ;; the methods.  If at any point we come across &allow-other-keys, we can just quit.
                (dolist (method methods)
                    (multiple-value-bind (keys allow-other-keys)
                        (function-keywords method)
                      (when allow-other-keys (return-from check-initargs-1 nil))
                      (setq legal (append keys legal))))
                
                ;; Now check the supplied-initarg-names and the default initargs against the total
                ;; set that we know are legal. 
                (doplist (key val)
                       initargs
                       (unless (memq key legal)
                           (error "Invalid initialization argument ~S for class ~S" key (class-name
                                                                                         class)))))))
