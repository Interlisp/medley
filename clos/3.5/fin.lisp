;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;; File converted on 26-Mar-91 10:33:34 from source fin
;;;. Original source {dsk}<usr>local>users>welch>lisp>clos>rev4>il-format>fin.;3 created 19-Feb-91 16:21:49

;;;. Copyright (c) 1991 by Venue




(in-package "CLOS")

;;; Shadow, Export, Require, Use-package, and Import forms should follow here






;; 



;;; FUNCALLABLE INSTANCES



;; 



;;; The first part of the file contains the implementation dependent code to implement funcallable
;;; instances.  Each implementation must provide the following functions and macros:
;;; ALLOCATE-FUNCALLABLE-INSTANCE-1 () should create and return a new funcallable instance.  The
;;; funcallable-instance-data slots must be initialized to NIL. This is called by
;;; allocate-funcallable-instance and by the bootstrapping code. FUNCALLABLE-INSTANCE-P (x) the
;;; obvious predicate.  This should be an INLINE function. it must be funcallable, but it would be
;;; nice if it compiled open. SET-FUNCALLABLE-INSTANCE-FUNCTION (fin new-value) change the fin so
;;; that when it is funcalled, the new-value function is called.  Note that it is legal for
;;; new-value to be copied before it is installed in the fin, specifically there is no accessor for
;;; a FIN's function so this function does not have to preserve the actual new value.  The new-value
;;; argument can be any funcallable thing, a closure, lambda compiled code etc.  This function must
;;; coerce those values if necessary. NOTE: new-value is almost always a compiled closure.  This is
;;; the important case to optimize. FUNCALLABLE-INSTANCE-DATA-1 (fin data-name) should return the
;;; value of the data named data-name in the fin. data-name is one of the symbols in the list which
;;; is the value of funcallable-instance-data.  Since data-name is almost always a quoted symbol and
;;; funcallable-instance-data is a constant, it is possible (and worthwhile) to optimize the
;;; computation of data-name's offset in the data part of the fin. This must be SETF'able. 


(defconstant funcallable-instance-data '(wrapper slots)
       "These are the 'data-slots' which funcallable instances have so that
   the meta-class funcallable-standard-class can store class, and static
   slots in them.")

(defmacro funcallable-instance-data-position (data)
       (if (and (consp data)
                (eq (car data)
                    'quote)
                (boundp 'funcallable-instance-data))
           (or (position (cadr data)
                      funcallable-instance-data :test #'eq)
               (progn (warn "Unknown funcallable-instance data: ~S." (cadr data))
                      `(error "Unknown funcallable-instance data: ~S." ',(cadr data))))
           `(position ,data funcallable-instance-data :test #'eq)))

(defun called-fin-without-function nil (error "Attempt to funcall a funcallable-instance without first~%~
          setting its funcallable-instance-function."))


;;; In Xerox Common Lisp, a lexical closure is a pair of an environment and CCODEP.  The environment
;;; is represented as a block.  There is space in the top 8 bits of the pointers to the CCODE and
;;; the environment to use to mark the closure as being a FIN. To help the debugger figure out when
;;; it has found a FIN on the stack, we reserve the last element of the closure environment to use
;;; to point back to the actual fin. Note that there is code in xerox-low which lets us access the
;;; fields of compiled-closures and which defines the closure-overlay record.  That code is there
;;; because there are some clients of it in that file. 



;; Don't be fooled.  We actually allocate one bigger than this to have a place to store the
;; backpointer to the fin.  -smL 


(defconstant funcallable-instance-closure-size 15)

(defvar *fin-env-type* (type-of (il:\\allocblock (1+ funcallable-instance-closure-size)
                                       t)))


;; Well, Gregor may be too proud to hack xpointers, but bvm and I aren't. -smL


(defstruct fin-env-pointer (pointer nil :type il:fullxpointer))

(defun fin-env-fin (fin-env)
       (fin-env-pointer-pointer (il:\\getbaseptr fin-env (* funcallable-instance-closure-size 2))))

(defun |set fin-env-fin| (fin-env new-value)
       (il:\\rplptr fin-env (* funcallable-instance-closure-size 2)
              (make-fin-env-pointer :pointer new-value))
       new-value)

(defsetf fin-env-fin |set fin-env-fin|)


;; The finalization function that will clean up the backpointer from the fin-env to the fin.  This
;; needs to be careful to not cons at all.  This depends on there being no other finalization
;; function on compiled-closures, since there is only one finalization function per datatype.  Too
;; bad.  -smL 


(defun finalize-fin (fin)
       
       ;; This could use the fn funcallable-instance-p, but if we get here we know that this is a
       ;; closure, so we can skip that test. 
       (when (il:fetch (closure-overlay funcallable-instance-p)
                    il:of fin)
           (let ((env (il:fetch (il:compiled-closure il:environment)
                             il:of fin)))
                (when env
                    (setq env (il:\\getbaseptr env (* funcallable-instance-closure-size 2)))
                    (when (typep env 'fin-env-pointer)
                        (setf (fin-env-pointer-pointer env)
                              nil)))))
       nil)

(eval-when (load)
       
       ;; Install the above finalization function.
       (when (fboundp 'finalize-fin)
           (il:\\set.finalization.function 'il:compiled-closure 'finalize-fin)))

(defun allocate-funcallable-instance-1 nil (let* ((env (il:\\allocblock (1+ 
                                                                    funcallable-instance-closure-size
                                                                            )
                                                              t))
                                                  (fin (il:make-compiled-closure nil env)))
                                                 (setf (fin-env-fin env)
                                                       fin)
                                                 (il:replace (closure-overlay funcallable-instance-p)
                                                        il:of fin il:with 't)
                                                 (set-funcallable-instance-function
                                                  fin
                                                  #'(lambda (&rest ignore)
                                                           (declare (ignore ignore))
                                                           (called-fin-without-function)))
                                                 fin))

(xcl:definline funcallable-instance-p (x)
       (and (typep x 'il:compiled-closure)
            (il:fetch (closure-overlay funcallable-instance-p)
                   il:of x)))

(defun set-funcallable-instance-function (fin new)
       (cond ((not (funcallable-instance-p fin))
              (error "~S is not a funcallable-instance" fin))
             ((not (functionp new))
              (error "~S is not a function." new))
             ((typep new 'il:compiled-closure)
              (let* ((fin-env (il:fetch (il:compiled-closure il:environment)
                                     il:of fin))
                     (new-env (il:fetch (il:compiled-closure il:environment)
                                     il:of new))
                     (new-env-size (if new-env
                                       (il:\\#blockdatacells new-env)
                                       0))
                     (fin-env-size (- funcallable-instance-closure-size (length 
                                                                            funcallable-instance-data
                                                                               ))))
                    (cond ((and new-env (<= new-env-size fin-env-size))
                           (dotimes (i fin-env-size)
                               (il:\\rplptr fin-env (* i 2)
                                      (if (< i new-env-size)
                                          (il:\\getbaseptr new-env (* i 2))
                                          nil)))
                           (setf (compiled-closure-fnheader fin)
                                 (compiled-closure-fnheader new)))
                          (t (set-funcallable-instance-function fin (make-trampoline new))))))
             (t (set-funcallable-instance-function fin (make-trampoline new)))))

(defun make-trampoline (function)
       #'(lambda (&rest args)
                (apply function args)))

(defmacro funcallable-instance-data-1 (fin data)
       `(il:\\getbaseptr (il:fetch (il:compiled-closure il:environment)
                                il:of
                                ,fin)
               (* (- funcallable-instance-closure-size (funcallable-instance-data-position
                                                        ,data)
                     1)
                                                             ; Reserve last element to point back to
                                                             ; actual FIN! 
                  2)))

(defsetf funcallable-instance-data-1 (fin data)
       (new-value)
       `(il:\\rplptr (il:fetch (il:compiled-closure il:environment)
                            il:of
                            ,fin)
               (* (- funcallable-instance-closure-size (funcallable-instance-data-position
                                                        ,data)
                     1)
                  2)
               ,new-value))

                                                             ; end of #+Xerox



;;; 


(defmacro fsc-instance-p (fin)
       `(funcallable-instance-p ,fin))

(defmacro fsc-instance-class (fin)
       `(wrapper-class (funcallable-instance-data-1 ,fin 'wrapper)))

(defmacro fsc-instance-wrapper (fin)
       `(funcallable-instance-data-1 ,fin 'wrapper))

(defmacro fsc-instance-slots (fin)
       `(funcallable-instance-data-1 ,fin 'slots))

(defun allocate-funcallable-instance (wrapper number-of-static-slots)
       (let ((fin (allocate-funcallable-instance-1))
             (slots (%allocate-static-slot-storage--class number-of-static-slots)))
            (setf (fsc-instance-wrapper fin)
                  wrapper
                  (fsc-instance-slots fin)
                  slots)
            fin))
