;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;; File converted on 26-Mar-91 10:23:29 from source pkg
;;;. Original source {dsk}<usr>local>users>welch>lisp>clos>rev4>il-format>pkg.;4 created  1-Mar-91 10:10:26

;;;. Copyright (c) 1991 by Venue


(in-package "CLOS")



;;; Some CommonLisps have more symbols in the Lisp package than the ones that are explicitly
;;; specified in CLtL.  This causes trouble. Any Lisp that has extra symbols in the Lisp package
;;; should shadow those symbols in the CLOS package. 


(shadow 'cl:documentation)


;;; These come from the index pages of 88-002R. 

(eval-when (compile load eval)
(defvar *exports*
       '(add-method built-in-class call-method call-next-method change-class class-name class-of 
               compute-applicable-methods defclass defgeneric define-method-combination defmethod 
               ensure-generic-function find-class find-method function-keywords generic-flet 
               generic-labels initialize-instance invalid-method-error make-instance 
               make-instances-obsolete method-combination-error method-qualifiers next-method-p 
               no-applicable-method no-next-method print-object reinitialize-instance remove-method 
               shared-initialize slot-boundp slot-exists-p slot-makunbound slot-missing slot-unbound
               slot-value standard standard-class standard-generic-function standard-method 
               standard-object structure-class symbol-macrolet update-instance-for-different-class 
               update-instance-for-redefined-class with-accessors with-added-methods with-slots))

(import '(xcl:false xcl:destructuring-bind xcl:true) *the-clos-package*)

(export *exports* *the-clos-package*)

(import *exports* (find-package :lisp))

(export *exports* (find-package :lisp)))

                                                             ; (defvar *chapter-3-exports* '(
                                                             ; get-setf-function
                                                             ; get-setf-function-name
                                                             ; class-prototype class object 



;; essential-class


                                                             ; class-name class-precedence-list
                                                             ; class-local-supers class-local-slots
                                                             ; class-direct-subclasses
                                                             ; class-direct-methods class-slots
                                                             ; method-arglist
                                                             ; method-argument-specifiers
                                                             ; method-function method-equal
                                                             ; slotd-name slot-missing 



;; define-meta-class %allocate-instance %instance-ref %instancep %instance-meta-class 


                                                             ; allocate-instance optimize-slot-value
                                                             ; optimize-setf-of-slot-value
                                                             ; add-named-class
                                                             ; class-for-redefinition add-class
                                                             ; supers-changed slots-changed
                                                             ; check-super-metaclass-compatibility
                                                             ; make-slotd
                                                             ; compute-class-precedence-list
                                                             ; walk-method-body
                                                             ; walk-method-body-form
                                                             ; add-named-method remove-named-method
                                                             ; )) 

