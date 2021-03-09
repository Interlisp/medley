;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;;. Copyright (c) 1991 by Venue

(in-package "CLOS")

;;; This file defines CLOS's interface to the LAP mechanism. The file is divided into two parts.  The
;;; first part defines the interface used by CLOS to create abstract LAP code vectors.  CLOS never
;;; creates lists that represent LAP code directly, it always calls this mechanism to do so. This
;;; provides a layer of error checking on the LAP code before it gets to the implementation-specific
;;; assembler.  Note that this error checking is syntactic only, but even so is useful to have. 
;;; Because of it, no specific LAP assembler should worry itself with checking the syntax of the LAP
;;; code. The second part of the file defines the LAP assemblers for each CLOS port. These are
;;; included together in the same file to make it easier to change them all should some random
;;; change be made in the LAP mechanism. 


(defvar *make-lap-closure-generator*)

(defvar *precompile-lap-closure-generator*)

(defvar *lap-in-lisp*)

(defun make-lap-closure-generator (closure-variables arguments iregs vregs tregs lap-code)
       (funcall *make-lap-closure-generator* closure-variables arguments iregs vregs tregs lap-code))

(defmacro precompile-lap-closure-generator (cvars args i-regs v-regs t-regs lap)
       (funcall *precompile-lap-closure-generator* cvars args i-regs v-regs t-regs lap))

(defmacro lap-in-lisp (cvars args iregs vregs tregs lap)
       (declare (ignore cvars args))
       `(locally (declare (optimize (safety 0)
                                 (speed 3)))
               ,(make-lap-prog iregs vregs tregs (flatten-lap lap (opcode :label 'exit-lap-in-lisp)))
               ))


;;; The following functions and macros are used by CLOS when generating LAP code: GENERATING-LAP
;;; WITH-LAP-REGISTERS ALLOCATE-REGISTER DEALLOCATE-REGISTER LAP-FLATTEN OPCODE OPERAND 


(proclaim '(special *generating-lap*))

                                                             ; CAR   - alist of free registers CADR 
                                                             ; - alist of allocated registers CADDR
                                                             ; - max reg number allocated in each
                                                             ; alist, the entries have the form: 
                                                             ; (type . (:REG <n>)) 



;;; This goes around the generation of any lap code.  <body> should return a lap code sequence, this
;;; macro will take care of converting that to a lap closure generator. 


(defmacro generating-lap (closure-variables arguments &body body)
       `(let* ((*generating-lap* (list nil nil -1)))
              (finalize-lap-generation nil ,closure-variables ,arguments (progn ,@body))))

(defmacro generating-lap-in-lisp (closure-variables arguments &body body)
       `(let* ((*generating-lap* (list nil nil -1)))
              (finalize-lap-generation t ,closure-variables ,arguments (progn ,@body))))


;;; Each register specification looks like: (<var> <type> &key :reuse <other-reg>) 


(defmacro with-lap-registers (register-specifications &body body)
       
       ;; Given that, for now, there is only one keyword argument and that, for now, we do no error
       ;; checking, we can be pretty sleazy about how this works. 
       (flet ((make-allocations
               nil
               (gathering1 (collecting)
                      (dolist (spec register-specifications)
                          (gather1 `(,(car spec)
                                     (or ,(cadddr spec)
                                         (allocate-register ',(cadr spec))))))))
              (make-deallocations nil (gathering1
                                       (collecting)
                                       (dolist (spec register-specifications)
                                           (gather1 `(unless ,(cadddr spec)
                                                         (deallocate-register ,(car spec))))))))
             `(let ,(make-allocations)
                   (multiple-value-prog1 (progn ,@body)
                          ,@(make-deallocations)))))

(defun allocate-register (type)
       (destructuring-bind (free allocated)
              *generating-lap*
              (let ((entry (assoc type free)))
                   (cond (entry (setf (car *generating-lap*)
                                      (delete entry free)
                                      (cadr *generating-lap*)
                                      (cons entry allocated))
                                (cdr entry))
                         (t (let ((new `(,type :reg ,(incf (caddr *generating-lap*)))))
                                 (setf (cadr *generating-lap*)
                                       (cons new allocated))
                                 (cdr new)))))))

(defun deallocate-register (reg)
       (let ((entry (rassoc reg (cadr *generating-lap*))))
            (unless entry (error "Attempt to free an unallocated register."))
            (push entry (car *generating-lap*))
            (setf (cadr *generating-lap*)
                  (delete entry (cadr *generating-lap*)))))

(defvar *precompiling-lap* nil)

(defun finalize-lap-generation (in-lisp-p closure-variables arguments lap-code)
       (when (cadr *generating-lap*)
             (error "Registers still allocated when lap being finalized."))
       (let ((iregs nil)
             (vregs nil)
             (tregs nil))
            (dolist (entry (car *generating-lap*))
                (ecase (car entry)
                    (index (push (caddr entry)
                                 iregs))
                    (vector (push (caddr entry)
                                  vregs))
                    ((t) (push (caddr entry)
                               tregs))))
            (cond (in-lisp-p (macroexpand `(lap-in-lisp ,closure-variables ,arguments ,iregs
                                                  ,vregs
                                                  ,tregs
                                                  ,lap-code)))
                  (*precompiling-lap* (values closure-variables arguments iregs vregs tregs lap-code)
                         )
                  (t (make-lap-closure-generator closure-variables arguments iregs vregs tregs 
                            lap-code)))))

(defun flatten-lap (&rest opcodes-or-sequences)
       (let ((result nil))
            (dolist (opcode-or-sequence opcodes-or-sequences result)
                (cond ((null opcode-or-sequence))
                      ((not (consp (car opcode-or-sequence)))
                                                             ; its an opcode
                       (setf result (append result (list opcode-or-sequence))))
                      (t (setf result (append result opcode-or-sequence)))))))

(defmacro flattening-lap nil '(let ((result nil))
                                   (values #'(lambda (value)
                                                    (push value result))
                                          #'(lambda nil (apply #'flatten-lap (reverse result))))))


;;; This code deals with the syntax of the individual opcodes and operands. The first two of these
;;; variables are documented to all ports.  They are lists of the symbols which name the lap opcodes
;;; and operands.  They can be useful to determine whether a port has implemented all the required
;;; opcodes and operands. The third of these variables is for use of the emitter only. 


(defvar *lap-operands* nil)

(defvar *lap-opcodes* nil)

(defvar *lap-emitters* (make-hash-table :test #'eq :size 30))

(defun opcode (name &rest args)
       (let ((emitter (gethash name *lap-emitters*)))
            (if emitter
                (apply emitter args)
                (error "No opcode named ~S." name))))

(defun operand (name &rest args)
       (let ((emitter (gethash name *lap-emitters*)))
            (if emitter
                (apply emitter args)
                (error "No operand named ~S." name))))

(defmacro defopcode (name types)
       (let ((fn-name (symbol-append "LAP Opcode " name *the-clos-package*))
             (lambda-list (mapcar #'(lambda (x)
                                           (declare (ignore x))
                                           (gensym))
                                 types)))
            `(progn (eval-when (load eval)
                           (load-defopcode ',name ',fn-name))
                    (defun ,fn-name ,lambda-list (defopcode-1 ',name ',types ,@lambda-list)))))

(defmacro defoperand (name types)
       (let ((fn-name (symbol-append "LAP Operand " name *the-clos-package*))
             (lambda-list (mapcar #'(lambda (x)
                                           (declare (ignore x))
                                           (gensym))
                                 types)))
            `(progn (eval-when (load eval)
                           (load-defoperand ',name ',fn-name))
                    (defun ,fn-name ,lambda-list (defoperand-1 ',name ',types ,@lambda-list)))))

(defun load-defopcode (name fn-name)
       (if* (memq name *lap-operands*)
            (error "LAP opcodes and operands must have disjoint names.")
            (setf (gethash name *lap-emitters*)
                  fn-name)
            (pushnew name *lap-opcodes*)))

(defun load-defoperand (name fn-name)
       (if* (memq name *lap-opcodes*)
            (error "LAP opcodes and operands must have disjoint names.")
            (setf (gethash name *lap-emitters*)
                  fn-name)
            (pushnew name *lap-operands*)))

(defun defopcode-1 (name operand-types &rest args)
       (iterate ((arg (list-elements args))
                 (type (list-elements operand-types)))
              (check-opcode-arg name arg type))
       (cons name (copy-list args)))

(defun defoperand-1 (name operand-types &rest args)
       (iterate ((arg (list-elements args))
                 (type (list-elements operand-types)))
              (check-operand-arg name arg type))
       (cons name (copy-list args)))

(defun check-opcode-arg (name arg type)
       (labels ((usual (x)
                       (and (consp arg)
                            (eq (car arg)
                                x)))
                (check (x)
                       (ecase x
                           ((:reg :cdr :constant :iref :cvar :arg :lisp :lisp-variable) (usual x))
                           (:label (symbolp arg))
                           (:operand (and (consp arg)
                                          (memq (car arg)
                                                *lap-operands*))))))
              (unless (if (consp type)
                          (if (eq (car type)
                                  'or)
                              (some #'check (cdr type))
                              (error "What type is this?"))
                          (check type))
                     (error "The argument ~S to the opcode ~A is not of type ~S." arg name type))))

(defun check-operand-arg (name arg type)
       (flet ((check (x)
                     (ecase x
                         (:symbol (symbolp arg))
                         (:register-number (and (integerp arg)
                                                (>= x 0)))
                         (:t t)
                         (:reg (and (consp arg)
                                    (eq (car arg)
                                        :reg)))
                         (:fixnum (typep arg 'fixnum)))))
             (unless (if (consp type)
                         (if (eq (car type)
                                 'or)
                             (some #'check (cdr type))
                             (error "What type is this?"))
                         (check type))
                    (error "The argument ~S to the operand ~A is not of type ~S." arg name type))))


;;; The actual opcodes. 


(defopcode :break nil)

                                                             ; For debugging only.  Not


(defopcode :beep nil)

                                                             ; all ports are required to


(defopcode :print (:reg))

                                                             ; implement this.


(defopcode :move (:operand (or :reg :iref :cdr :lisp-variable)))

(defopcode :eq ((or :reg :constant)
                (or :reg :constant)
                :label))

(defopcode :neq ((or :reg :constant)
                 (or :reg :constant)
                 :label))

(defopcode :fix= ((or :reg :constant)
                  (or :reg :constant)
                  :label))

(defopcode :izerop (:reg :label))

(defopcode :std-instance-p (:reg :label))

(defopcode :fsc-instance-p (:reg :label))

(defopcode :built-in-instance-p (:reg :label))

(defopcode :structure-instance-p (:reg :label))

(defopcode :jmp ((or :reg :constant)))

(defopcode :label (:label))

(defopcode :go (:label))

(defopcode :return ((or :reg :constant)))

(defopcode :exit-lap-in-lisp nil)


;;; The actual operands. 


(defoperand :reg (:register-number))

(defoperand :cvar (:symbol))

(defoperand :arg (:symbol))

(defoperand :cdr (:reg))

(defoperand :constant (:t))

(defoperand :std-wrapper (:reg))

(defoperand :fsc-wrapper (:reg))

(defoperand :built-in-wrapper (:reg))

(defoperand :structure-wrapper (:reg))

(defoperand :other-wrapper (:reg))

(defoperand :std-slots (:reg))

(defoperand :fsc-slots (:reg))

(defoperand :cref (:reg :fixnum))

(defoperand :iref (:reg :reg))

(defoperand :iset (:reg :reg :reg))

(defoperand :i1+ (:reg))

(defoperand :i+ (:reg :reg))

(defoperand :i- (:reg :reg))

(defoperand :ilogand (:reg :reg))

(defoperand :ilogxor (:reg :reg))

(defoperand :ishift (:reg :fixnum))

(defoperand :lisp (:t))

(defoperand :lisp-variable (:symbol))


;;; LAP tests (there need to be a lot more of these) 

