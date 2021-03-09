;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-

;;;. Copyright (c) 1991 by Venue


(in-package "CLOS")


;;; This file contains the
;;; definition of the FUNCALLABLE-STANDARD-CLASS metaclass.  Much of the implementation of this
;;; metaclass is actually defined on the class STD-CLASS.  What appears in this file is a modest
;;; number of simple methods related to the low-level differences in the implementation of standard
;;; and funcallable-standard instances. As it happens, none of these differences are the ones
;;; reflected in the MOP specification; STANDARD-CLASS and FUNCALLABLE-STANDARD-CLASS share all
;;; their specified methods at STD-CLASS. workings of this metaclass and the standard-class
;;; metaclass. 


(defmethod wrapper-fetcher ((class funcallable-standard-class))
       'fsc-instance-wrapper)

(defmethod slots-fetcher ((class funcallable-standard-class))
       'fsc-instance-slots)

(defmethod raw-instance-allocator ((class funcallable-standard-class))
       'allocate-funcallable-instance-1)


;;; 


(defmethod check-super-metaclass-compatibility ((fsc funcallable-standard-class)
                                                (class standard-class))
       (null (wrapper-instance-slots-layout (class-wrapper class))))

(defmethod allocate-instance ((class funcallable-standard-class)
                              &rest initargs)
       (declare (ignore initargs))
       (unless (class-finalized-p class)
              (finalize-inheritance class))
       (let ((class-wrapper (class-wrapper class)))
            (allocate-funcallable-instance class-wrapper (class-no-of-instance-slots class))))

(defmethod make-reader-method-function ((class funcallable-standard-class)
                                        slot-name)
       (make-std-reader-method-function slot-name))

(defmethod make-writer-method-function ((class funcallable-standard-class)
                                        slot-name)
       (make-std-writer-method-function slot-name))

                                                             ; See the comment about
                                                             ; reader-function--std and
                                                             ; writer-function--sdt.
                                                             ; (define-function-template
                                                             ; reader-function--fsc () '(slot-name)
                                                             ; `(function (lambda (instance)
                                                             ; (slot-value-using-class
                                                             ; (wrapper-class (get-wrapper
                                                             ; instance)) instance slot-name))))
                                                             ; (define-function-template
                                                             ; writer-function--fsc () '(slot-name)
                                                             ; `(function (lambda (nv instance)
                                                             ; (setf (slot-value-using-class
                                                             ; (wrapper-class (get-wrapper
                                                             ; instance)) instance slot-name) nv))))
                                                             ; (eval-when (load)
                                                             ; (pre-make-templated-function-constructor
                                                             ; reader-function--fsc)
                                                             ; (pre-make-templated-function-constructor
                                                             ; writer-function--fsc)) 

