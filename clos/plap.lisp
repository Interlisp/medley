;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;;. Copyright (c) 1991 by Venue

(in-package "CLOS")


;;; The portable implementation of the LAP assembler. The portable implementation of the LAP
;;; assembler works by translating LAP code back into Lisp code and then compiling that Lisp code. 
;;; Note that this implementation is actually going to get a lot of use.  Some implementations (KCL)
;;; won't implement a native LAP assembler at all. Other implementations may not implement native
;;; LAP assemblers for all of their ports.  All of this implies that this portable LAP assembler
;;; needs to generate the best code it possibly can. 


(defmacro
 lap-case
 (operand &body cases)
 (once-only
  (operand)
  `(ecase (car ,operand)
       ,@(mapcar #'(lambda (case)
                          `(,(car case)
                            (apply #'(lambda ,(cadr case)
                                            ,@(cddr case))
                                   (cdr ,operand))))
                cases))))

(defvar *lap-args*)

(defvar *lap-rest-p*)

(defvar *lap-i-regs*)

(defvar *lap-v-regs*)

(defvar *lap-t-regs*)

(defvar *lap-optimize-declaration* '((speed 3)
                                     (safety 0)
                                     (compilation-speed 0)))

(eval-when (load eval)
       (setq *make-lap-closure-generator* #'(lambda (closure-var-names arg-names index-regs 
                                                           vector-regs t-regs lap-code)
                                                   (compile-lambda (make-lap-closure-generator-lambda
                                                                    closure-var-names arg-names 
                                                                    index-regs vector-regs t-regs 
                                                                    lap-code)))
             *precompile-lap-closure-generator*
             #'(lambda (cvars args i-regs v-regs t-regs lap)
                      `#',(make-lap-closure-generator-lambda cvars args i-regs v-regs t-regs lap))
             *lap-in-lisp*
             #'(lambda (cvars args iregs vregs tregs lap)
                      (declare (ignore cvars args))
                      (make-lap-prog iregs vregs tregs (flatten-lap lap 
                                                             ; (opcode :label 'exit-lap-in-lisp)
                                                              )))))

(defun make-lap-closure-generator-lambda (cvars args i-regs v-regs t-regs lap)
       (let* ((rest (memq '&rest args))
              (ldiff (and rest (ldiff args rest))))
             (when rest
                 (setq args (append ldiff '(&rest .lap-rest-arg.))))
             (let* ((*lap-args* (if rest
                                    ldiff
                                    args))
                    (*lap-rest-p* (not (null rest))))
                   `(lambda ,cvars #'(lambda ,args (declare (optimize . ,*lap-optimize-declaration*))
                                            ,(make-lap-prog-internal i-regs v-regs t-regs lap))))))

(defun make-lap-prog (i-regs v-regs t-regs lap)
       (let* ((*lap-args* 'lap-in-lisp)
              (*lap-rest-p* 'lap-in-lisp))
             (make-lap-prog-internal i-regs v-regs t-regs lap)))

(defun make-lap-prog-internal (i-regs v-regs t-regs lap)
       (let* ((*lap-i-regs* i-regs)
              (*lap-v-regs* v-regs)
              (*lap-t-regs* t-regs)
              (code (mapcar #'lap-opcode lap)))
             `(prog ,(mapcar #'(lambda (reg)
                                      `(,(lap-reg reg)
                                        ,(lap-reg-initial-value-form reg)))
                            (append i-regs v-regs t-regs))
                    (declare (type fixnum ,@(mapcar #'lap-reg *lap-i-regs*))
                           (type simple-vector ,@(mapcar #'lap-reg *lap-v-regs*))
                           (optimize . ,*lap-optimize-declaration*))
                    ,.code)))

(defconstant *empty-vector* '#())

(defun lap-reg-initial-value-form (reg)
       (cond ((member reg *lap-i-regs*)
              0)
             ((member reg *lap-v-regs*)
              '*empty-vector*)
             ((member reg *lap-t-regs*)
              nil)
             (t (error "What kind of register is ~S?" reg))))

(defun lap-opcode (opcode)
       (lap-case opcode (:move (from to)
                               `(setf ,(lap-operand to)
                                      ,(lap-operand from)))
              ((:eq :neq :fix=)
               (arg1 arg2 label)
               `(when ,(lap-operands (ecase (car opcode)
                                         (:eq 'eq)
                                         (:neq 'neq)
                                         (:fix= 'runtime\ fix=))
                              arg1 arg2)
                    (go ,label)))
              ((:izerop)
               (arg label)
               `(when ,(lap-operands 'runtime\ izerop arg)
                    (go ,label)))
              (:std-instance-p (from label)
                     `(when ,(lap-operands 'runtime\ std-instance-p from)
                          (go ,label)))
              (:fsc-instance-p (from label)
                     `(when ,(lap-operands 'runtime\ fsc-instance-p from)
                          (go ,label)))
              (:built-in-instance-p (from label)
                     (declare (ignore from))
                     `(when ,t
                          (go ,label)))
                                                             ; ***
              (:structure-instance-p (from label)
                     `(when ,(lap-operands 'runtime\ ??? from)
                          (go ,label)))
                                                             ; ***
              (:jmp (fn)
                    (if (eq *lap-args* 'lap-in-lisp)
                        (error "Can't do a :JMP in LAP-IN-LISP.")
                        `(return ,(if *lap-rest-p*
                                      `(runtime\ apply ,(lap-operand fn)
                                              ,@*lap-args* .lap-rest-arg.)
                                      `(runtime\ funcall ,(lap-operand fn)
                                              ,@*lap-args*)))))
              (:return (value)
                     `(return ,(lap-operand value)))
              (:label (label)
                     label)
              (:go (label)
                   `(go ,label))
              (:exit-lap-in-lisp nil `(go exit-lap-in-lisp))
              (:break nil `(break))
              (:beep nil)
              (:print (val)
                     (lap-operands 'print val))))

(defun lap-operand (operand)
       (lap-case operand (:reg (n)
                               (lap-reg n))
              (:cdr (reg)
                    (lap-operands 'cdr reg))
              ((:cvar :arg)
               (name)
               name)
              (:constant (c)
                     `',c)
              ((:std-wrapper :fsc-wrapper :built-in-wrapper :structure-wrapper :std-slots :fsc-slots)
               (x)
               (lap-operands (ecase (car operand)
                                 (:std-wrapper 'runtime\ std-wrapper)
                                 (:fsc-wrapper 'runtime\ fsc-wrapper)
                                 (:built-in-wrapper 'runtime\ built-in-wrapper)
                                 (:structure-wrapper 'runtime\ structure-wrapper)
                                 (:std-slots 'runtime\ std-slots)
                                 (:fsc-slots 'runtime\ fsc-slots))
                      x))
              (:i1+ (index)
                    (lap-operands 'runtime\ i1+ index))
              (:i+ (index1 index2)
                   (lap-operands 'runtime\ i+ index1 index2))
              (:i- (index1 index2)
                   (lap-operands 'runtime\ i- index1 index2))
              (:ilogand (index1 index2)
                     (lap-operands 'runtime\ ilogand index1 index2))
              (:ilogxor (index1 index2)
                     (lap-operands 'runtime\ ilogxor index1 index2))
              (:iref (vector index)
                     (lap-operands 'runtime\ iref vector index))
              (:iset (vector index value)
                     (lap-operands 'runtime\ iset vector index value))
              (:cref (vector i)
                     `(runtime\ svref ,(lap-operand vector)
                             ,i))
              (:lisp-variable (symbol)
                     symbol)
              (:lisp (form)
                     form)))

(defun lap-operands (fn &rest regs)
       (cons fn (mapcar #'lap-operand regs)))

(defun lap-reg (n)
       (intern (format nil "REG~D" n)
              *the-clos-package*))


;;; Runtime Implementations of the operands and opcodes. In those ports of CLOS which choose not to
;;; completely re-implement the LAP code generator, it may still be provident to consider
;;; reimplementing one or more of these to get the compiler to produce better code.  That is why
;;; they are split out. 


(proclaim '(declaration clos-fast-call))

(defmacro runtime\ funcall (fn &rest args)
       `(funcall ,fn ,.args))

(defmacro runtime\ apply (fn &rest args)
       `(apply ,fn ,.args))

(defmacro runtime\ std-wrapper (x)
       `(std-instance-wrapper ,x))

(defmacro runtime\ fsc-wrapper (x)
       `(fsc-instance-wrapper ,x))

(defmacro runtime\ built-in-wrapper (x)
       `(built-in-wrapper-of ,x))

(defmacro runtime\ structure-wrapper (x)
       `(??? ,x))

(defmacro runtime\ std-slots (x)
       `(std-instance-slots (the std-instance ,x)))

(defmacro runtime\ fsc-slots (x)
       `(fsc-instance-slots ,x))

(defmacro runtime\ std-instance-p (x)
       `(std-instance-p ,x))

(defmacro runtime\ fsc-instance-p (x)
       `(fsc-instance-p ,x))

(defmacro runtime\ izerop (x)
       `(zerop (the fixnum ,x)))

(defmacro runtime\ fix= (x y)
       `(= (the fixnum ,x)
           (the fixnum ,y)))


;;; These are the implementations of the index operands.  The portable assembler generates Lisp code
;;; that uses these macros.  Even though the variables holding the arguments and results have type
;;; declarations on them, we put type declarations in here. Some compilers are so stupid... 


(defmacro runtime\ iref (vector index)
       `(svref (the simple-vector ,vector)
               (the fixnum ,index)))

(defmacro runtime\ iset (vector index value)
       `(setf (svref (the simple-vector ,vector)
                     (the fixnum ,index))
              ,value))

(defmacro runtime\ svref (vector fixnum)
       `(svref (the simple-vector ,vector)
               (the fixnum ,fixnum)))

(defmacro runtime\ i+ (index1 index2)
       `(the fixnum (+ (the fixnum ,index1)
                       (the fixnum ,index2))))

(defmacro runtime\ i- (index1 index2)
       `(the fixnum (- (the fixnum ,index1)
                       (the fixnum ,index2))))

(defmacro runtime\ i1+ (index)
       `(the fixnum (1+ (the fixnum ,index))))

(defmacro runtime\ ilogand (index1 index2)
       `(the fixnum (logand (the fixnum ,index1)
                           (the fixnum ,index2))))

(defmacro runtime\ ilogxor (index1 index2)
       `(the fixnum (logxor (the fixnum ,index1)
                           (the fixnum ,index2))))


;;; In the portable implementation, indexes are just fixnums. 


(defconstant index-value-limit most-positive-fixnum)

(defun index-value->index (index-value)
       index-value)

(defun index->index-value (index)
       index)

(defun make-index-mask (cache-size line-size)
       (let ((cache-size-in-bits (floor (log cache-size 2)))
             (line-size-in-bits (floor (log line-size 2)))
             (mask 0))
            (dotimes (i cache-size-in-bits)
                (setq mask (dpb 1 (byte 1 i)
                                mask)))
            (dotimes (i line-size-in-bits)
                (setq mask (dpb 0 (byte 1 i)
                                mask)))
            mask))
