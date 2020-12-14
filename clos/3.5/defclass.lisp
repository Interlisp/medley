;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-

;;;. Copyright (c) 1991 by Venue
(in-package "CLOS")

;;; ************************************************************************* 



;;; MAKE-TOP-LEVEL-FORM is used by all PCL macros that appear `at top-level'. The original
;;; motiviation for this function was to deal with the bug in the Genera compiler that prevents
;;; lambda expressions in top-level forms other than DEFUN from being compiled. Now this function is
;;; used to grab other functionality as well.  This includes: - Preventing the grouping of top-level
;;; forms.  For example, a DEFCLASS followed by a DEFMETHOD may not want to be grouped into the same
;;; top-level form. - Telling the programming environment what the pretty version of the name of
;;; this form is.  This is used by WARN. 


(defun make-top-level-form (name times form)
       (flet ((definition-name nil (if (and (listp name)
                                            (memq (car name)
                                                  '(defmethod defclass class method 
                                                          method-combination)))
                                       (format nil "~A~{ ~S~}" (capitalize-words (car name)
                                                                      nil)
                                              (cdr name))
                                       (format nil "~S" name))))
             (definition-name)
             (make-progn `',name `(eval-when ,times ,form))))

(defun make-progn (&rest forms)
       (let ((progn-form nil))
            (labels ((collect-forms (forms)
                            (unless (null forms)
                                (collect-forms (cdr forms))
                                (if (and (listp (car forms))
                                         (eq (caar forms)
                                             'progn))
                                    (collect-forms (cdar forms))
                                    (push (car forms)
                                          progn-form)))))
                   (collect-forms forms)
                   (cons 'progn progn-form))))


;;; Like the DEFMETHOD macro, the expansion of the DEFCLASS macro is fixed. DEFCLASS always expands
;;; into a call to LOAD-DEFCLASS.  Until the meta- braid is set up, LOAD-DEFCLASS has a special
;;; definition which simply collects all class definitions up, when the metabraid is initialized it
;;; is done from those class definitions. After the metabraid has been setup, and the protocol for
;;; defining classes has been defined, the real definition of LOAD-DEFCLASS is installed by the file
;;; defclass.lisp 


(defmacro defclass (name direct-superclasses direct-slots &rest options)
       (declare (indentation 2 4 3 1))
       (expand-defclass name direct-superclasses direct-slots options))

(defun expand-defclass (name supers slots options)
       (setq supers (copy-tree supers)
             slots
             (copy-tree slots)
             options
             (copy-tree options))
       (let ((metaclass 'standard-class))
            (dolist (option options)
                (if (not (listp option))
                    (error "~S is not a legal defclass option." option)
                    (when (eq (car option)
                              ':metaclass)
                        (unless (legal-class-name-p (cadr option))
                            (error 
        "The value of the :metaclass option (~S) is not a~%~
                      legal class name." (cadr option)))
                        (setq metaclass (cadr option))
                        (setf options (remove option options))
                        (return t))))
            (let ((*initfunctions* nil)
                  (*accessors* nil))
                                                             ; Truly a crock, but we got to have it
                                                             ; to live nicely. 
                 (declare (special *initfunctions* *accessors*))
                 (let ((canonical-slots (mapcar #'(lambda (spec)
                                                         (canonicalize-slot-specification name spec))
                                               slots))
                       (other-initargs (mapcar #'(lambda (option)
                                                        (canonicalize-defclass-option name option))
                                              options)))
                      (do-standard-defsetfs-for-defclass *accessors*)
;		      (load-defclass name metaclass supers
;				     canonical-slots (apply #'append
;							    other-initargs) *accessors*)))))
                      (make-top-level-form `(defclass ,name nil nil)
                             *defclass-times*
                             `(let ,(mapcar #'cdr *initfunctions*)
                                   (load-defclass ',name ',metaclass ',supers (list 
                                                                                    ,@canonical-slots
                                                                                    )
                                          (list ,@(apply #'append other-initargs))
                                          ',*accessors*)))))))

(defun make-initfunction (initform)
       (declare (special *initfunctions*))
       (cond ((or (eq initform 't)
                  (equal initform ''t))
              '#'true)
             ((or (eq initform 'nil)
                  (equal initform ''nil))
              '#'false)
             ((or (eql initform '0)
                  (equal initform ''0))
              '#'zero)
             (t (let ((entry (assoc initform *initfunctions* :test #'equal)))
                     (unless entry
                         (setq entry (list initform (gensym)
                                           `#'(lambda nil ,initform)))
                         (push entry *initfunctions*))
                     (cadr entry)))))

(defun canonicalize-slot-specification (class-name spec)
       (declare (special *accessors*))
       (cond ((and (symbolp spec)
                   (not (keywordp spec))
                   (not (memq spec '(t nil))))
              `'(:name ,spec))
             ((not (consp spec))
              (error "~S is not a legal slot specification." spec))
             ((null (cdr spec))
              `'(:name ,(car spec)))
             ((null (cddr spec))
              (error 
        "In DEFCLASS ~S, the slot specification ~S is obsolete.~%~
                 Convert it to ~S" class-name spec (list (car spec)
                                                         :initform
                                                         (cadr spec))))
             (t (let* ((name (pop spec))
                       (readers nil)
                       (writers nil)
                       (initargs nil)
                       (unsupplied (list nil))
                       (initform (getf spec :initform unsupplied)))
                      (doplist (key val)
                             spec
                             (case key
                                 (:accessor 
                                    (push val *accessors*)
                                    (push val readers)
                                    (push `(setf ,val)
                                          writers))
                                 (:reader (push val readers))
                                 (:writer (push val writers))
                                 (:initarg (push val initargs))))
                      (loop (unless (remf spec :accessor)
                                   (return)))
                      (loop (unless (remf spec :reader)
                                   (return)))
                      (loop (unless (remf spec :writer)
                                   (return)))
                      (loop (unless (remf spec :initarg)
                                   (return)))
                      (setq spec `(:name ',name :readers ',readers
				   :writers ',writers :initargs
                                         ',initargs
                                         ',spec))
                      (if (eq initform unsupplied)
                          `(list* ,@spec)
                          `(list* :initfunction ,(make-initfunction initform)
                                  ,@spec))))))

(defun canonicalize-defclass-option (class-name option)
       (declare (ignore class-name))
       (case (car option)
           (:default-initargs (let ((canonical nil))
                                   (let (key val (tail (cdr option)))
                                        (loop (when (null tail)
                                                    (return nil))
                                              (setq key (pop tail)
                                                    val
                                                    (pop tail))
                                              (push ``(,',key ,,(make-initfunction val)
                                                             ,',val)
                                                    canonical))
                                        `(':direct-default-initargs (list ,@(nreverse canonical))))))
           (otherwise `(',(car option)
                        ',(cdr option)))))


;;; This is the early definition of load-defclass.  It just collects up all the class definitions in
;;; a list.  Later, in the file braid1.lisp, these are actually defined. Each entry in
;;; *early-class-definitions* is an early-class-definition. 


(defparameter *early-class-definitions* nil)

(defun make-early-class-definition (name source metaclass superclass-names canonical-slots 
                                         other-initargs)
       (list 'early-class-definition name source metaclass superclass-names canonical-slots 
             other-initargs))

(defun ecd-class-name (ecd)
       (nth 1 ecd))

(defun ecd-source (ecd)
       (nth 2 ecd))

(defun ecd-metaclass (ecd)
       (nth 3 ecd))

(defun ecd-superclass-names (ecd)
       (nth 4 ecd))

(defun ecd-canonical-slots (ecd)
       (nth 5 ecd))

(defun ecd-other-initargs (ecd)
       (nth 6 ecd))

(proclaim '(notinline load-defclass))

(defun load-defclass (name metaclass supers canonical-slots canonical-options accessor-names)
       (setq supers (copy-tree supers)
             canonical-slots
             (copy-tree canonical-slots)
             canonical-options
             (copy-tree canonical-options))
       (do-standard-defsetfs-for-defclass accessor-names)
       (let ((ecd (make-early-class-definition name (load-truename)
                         metaclass supers canonical-slots (apply #'append canonical-options)))
             (existing (find name *early-class-definitions* :key #'ecd-class-name)))
            (setq *early-class-definitions* (cons ecd (remove existing *early-class-definitions*)))
            ecd))
