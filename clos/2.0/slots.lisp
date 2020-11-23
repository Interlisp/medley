;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;;. Copyright (c) 1991 by Venue

(in-package "CLOS")

;;; These four functions work on std-instances and fsc-instances.  These are instances for which it
;;; is possible to change the wrapper and the slots. For these kinds of instances, most specified
;;; methods from the instance structure protocol are promoted to the implementation-specific class
;;; std-class.  Many of these methods call these four functions. 


(defun get-wrapper (inst)
       (cond ((std-instance-p inst)
              (std-instance-wrapper inst))
             ((fsc-instance-p inst)
              (fsc-instance-wrapper inst))
             (t (error "What kind of instance is this?"))))

(defun get-slots (inst)
       (cond ((std-instance-p inst)
              (std-instance-slots inst))
             ((fsc-instance-p inst)
              (fsc-instance-slots inst))
             (t (error "What kind of instance is this?"))))

(defun set-wrapper (inst new)
       (cond ((std-instance-p inst)
              (setf (std-instance-wrapper inst)
                    new))
             ((fsc-instance-p inst)
              (setf (fsc-instance-wrapper inst)
                    new))
             (t (error "What kind of instance is this?"))))

(defun set-slots (inst new)
       (cond ((std-instance-p inst)
              (setf (std-instance-slots inst)
                    new))
             ((fsc-instance-p inst)
              (setf (fsc-instance-slots inst)
                    new))
             (t (error "What kind of instance is this?"))))

(defmacro get-slot-value-2 (instance wrapper slot-name slots index)
       `(let ((val (%svref ,slots ,index)))
             (if (eq val ',*slot-unbound*)
                 (slot-unbound (wrapper-class ,wrapper)
                        ,instance
                        ,slot-name)
                 val)))

(defmacro set-slot-value-2 (nv instance wrapper slot-name slots index)
       (declare (ignore instance wrapper slot-name))
       `(setf (%svref ,slots ,index)
              ,nv))

(defun get-class-slot-value-1 (object wrapper slot-name)
       (let ((entry (assq slot-name (wrapper-class-slots wrapper))))
            (if (null entry)
                (slot-missing (wrapper-class wrapper)
                       object slot-name 'slot-value)
                (if (eq (cdr entry)
                        *slot-unbound*)
                    (slot-unbound (wrapper-class wrapper)
                           object slot-name)
                    (cdr entry)))))

(defun set-class-slot-value-1 (new-value object wrapper slot-name)
       (let ((entry (assq slot-name (wrapper-class-slots wrapper))))
            (if (null entry)
                (slot-missing (wrapper-class wrapper)
                       object slot-name 'setf new-value)
                (setf (cdr entry)
                      new-value))))

(defmethod class-slot-value ((class std-class)
                             slot-name)
       (let ((wrapper (class-wrapper class))
             (prototype (class-prototype class)))
            (get-class-slot-value-1 prototype wrapper slot-name)))

(defmethod (setf class-slot-value)
       (nv (class std-class)
           slot-name)
       (let ((wrapper (class-wrapper class))
             (prototype (class-prototype class)))
            (set-class-slot-value-1 nv prototype wrapper slot-name)))

(defmethod find-slot-definition ((class std-class)
                                 slot-name)
       (if (and (eq class *the-class-standard-class*)
                (eq slot-name 'slots))
           *the-eslotd-standard-class-slots*
           (progn (unless (class-finalized-p class)
                         (finalize-inheritance class))
                  (dolist (eslotd (class-slots class))
                      (when (eq (slotd-name eslotd)
                                slot-name)
                            (return eslotd))))))

(defun slot-value (object slot-name)
       (let ((class (class-of object)))
            (if (eq class *the-class-standard-effective-slot-definition*)
                (let* ((wrapper (check-wrapper-validity object))
                       (slots (get-slots object))
                       (index (instance-slot-index wrapper slot-name)))
                      (if index
                          (get-slot-value-2 object wrapper slot-name slots index)
                          (get-class-slot-value-1 object wrapper slot-name)))
                (let ((slot-definition (find-slot-definition class slot-name)))
                     (if (null slot-definition)
                         (slot-missing class object slot-name 'slot-value)
                         (slot-value-using-class class object slot-definition))))))

(defun set-slot-value (object slot-name new-value)
       (let ((class (class-of object)))
            (if (eq class *the-class-standard-effective-slot-definition*)
                (let* ((wrapper (check-wrapper-validity object))
                       (slots (get-slots object))
                       (index (instance-slot-index wrapper slot-name)))
                      (if index
                          (set-slot-value-2 new-value object wrapper slot-name slots index)
                          (set-class-slot-value-1 new-value object wrapper slot-name)))
                (let ((slot-definition (find-slot-definition class slot-name)))
                     (if (null slot-definition)
                         (slot-missing class object slot-name 'setf)
                         (setf (slot-value-using-class class object slot-definition)
                               new-value))))))

(defun slot-boundp (object slot-name)
       (let* ((class (class-of object))
              (slot-definition (find-slot-definition class slot-name)))
             (if (null slot-definition)
                 (slot-missing class object slot-name 'slot-boundp)
                 (slot-boundp-using-class class object slot-definition))))

(defun slot-makunbound (object slot-name)
       (let* ((class (class-of object))
              (slot-definition (find-slot-definition class slot-name)))
             (if (null slot-definition)
                 (slot-missing class object slot-name 'slot-makunbound)
                 (slot-makunbound-using-class class object slot-definition))))

(defun slot-exists-p (object slot-name)
       (let* ((class (class-of object))
              (slot-definition (find-slot-definition class slot-name)))
             (and slot-definition (slot-exists-p-using-class class object slot-definition))))


;;; This isn't documented, but is used within CLOS in a number of print object methods (see
;;; named-object-print-function). 


(defun slot-value-or-default (object slot-name &optional (default "unbound"))
       (if (slot-boundp object slot-name)
           (slot-value object slot-name)
           default))


;;; 


(defmethod slot-value-using-class ((class std-class)
                                   (object standard-object)
                                   (slotd standard-effective-slot-definition))
       (let* ((wrapper (check-wrapper-validity object))
                                                             ; trap if need be
              (slots (get-slots object))
              (slot-name (slotd-name slotd))
              (index (or (slotd-instance-index slotd)
                         (setf (slotd-instance-index slotd)
                               (instance-slot-index wrapper slot-name)))))
             (if index
                 (get-slot-value-2 object wrapper slot-name slots index)
                 (get-class-slot-value-1 object wrapper slot-name))))

(defmethod (setf slot-value-using-class)
       (new-value (class std-class)
              (object standard-object)
              (slotd standard-effective-slot-definition))
       (let* ((wrapper (check-wrapper-validity object))
                                                             ; trap if need be
              (slots (get-slots object))
              (slot-name (slotd-name slotd))
              (index (or (slotd-instance-index slotd)
                         (setf (slotd-instance-index slotd)
                               (instance-slot-index wrapper slot-name)))))
             (if index
                 (set-slot-value-2 new-value object wrapper slot-name slots index)
                 (set-class-slot-value-1 new-value object wrapper slot-name))))

(defmethod slot-boundp-using-class ((class std-class)
                                    (object standard-object)
                                    (slotd standard-effective-slot-definition))
       (let* ((wrapper (check-wrapper-validity object))
                                                             ; trap if need be
              (slots (get-slots object))
              (slot-name (slotd-name slotd))
              (index (or (slotd-instance-index slotd)
                         (setf (slotd-instance-index slotd)
                               (instance-slot-index wrapper slot-name)))))
             (if index
                 (neq (svref slots index)
                      *slot-unbound*)
                 (let ((entry (assq slot-name (wrapper-class-slots wrapper))))
                      (if (null entry)
                          (slot-missing class object slot-name 'slot-boundp)
                          (neq (cdr entry)
                               *slot-unbound*))))))

(defmethod slot-makunbound-using-class ((class std-class)
                                        (object standard-object)
                                        (slotd standard-effective-slot-definition))
       (let* ((wrapper (check-wrapper-validity object))
                                                             ; trap if need be
              (slots (get-slots object))
              (slot-name (slotd-name slotd))
              (index (or (slotd-instance-index slotd)
                         (setf (slotd-instance-index slotd)
                               (instance-slot-index wrapper slot-name)))))
             (cond (index (setf (%svref slots index)
                                *slot-unbound*)
                          object)
                   (t (let ((entry (assq slot-name (wrapper-class-slots wrapper))))
                           (if* (null entry)
                                (slot-missing class object slot-name 'slot-makunbound)
                                (setf (cdr entry)
                                      *slot-unbound*)
                                object))))))

(defmethod slot-exists-p-using-class ((class std-class)
                                      (object standard-object)
                                      (slotd standard-effective-slot-definition))
       t)

(defmethod slot-missing ((class t)
                         instance slot-name operation &optional new-value)
       (error "When attempting to ~A,~%the slot ~S is missing from the object ~S."
              (ecase operation
                  (slot-value "read the slot's value (slot-value)")
                  (setf (format nil "set the slot's value to ~S (setf of slot-value)" new-value))
                  (slot-boundp "test to see if slot is bound (slot-boundp)")
                  (slot-makunbound "make the slot unbound (slot-makunbound)"))
              slot-name instance))

(defmethod slot-unbound ((class t)
                         instance slot-name)
       (error "The slot ~S is unbound in the object ~S." slot-name instance))

(defmethod allocate-instance ((class standard-class)
                              &rest initargs)
       (declare (ignore initargs))
       (unless (class-finalized-p class)
              (finalize-inheritance class))
       (let* ((class-wrapper (class-wrapper class))
              (instance (%allocate-instance--class (class-no-of-instance-slots class))))
             (setf (std-instance-wrapper instance)
                   class-wrapper)
             instance))
