;;;-*- Mode:LISP; Package: CLOS; Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;; 
;;; Testing code.
;;;

(in-package :clos)

;;; Because CommonLoops runs in itself so much, the notion of a test file for
;;; it is kind of weird.
;;;
;;; If all of CLOS loads then many of the tests in this file (particularly
;;; those at the beginning) are sure to work.  Those tests exists primarily
;;; to help debug things when low-level changes are made to CLOS, or when a
;;; particular port customizes low-level code.
;;;
;;; Some of the other tests are "real" in the sense that they test things
;;; that CLOS itself does not use, so might be broken.
;;; 
;;; NOTE:
;;;   The tests in this file do not appear in random order!  They
;;;   depend on state  which has already been set up in order to run.
;;;

(defmacro do-test (name cleanups &body body)
  `(let ((do-test-failed nil))
     (catch 'do-test
       (format t "~&Testing ~A..." ,name)
;       (cleanup-do-test ',cleanups)
       (block do-test ,@body)
       (if do-test-failed
           (format t "~&FAILED!")
           (format t "OK")))))
  
(defmacro do-test-error (fatal string &rest args)
  `(progn (terpri)
          (setq do-test-failed t)
          (format t ,string ,@args)
          (when ,fatal (return-from do-test nil))))

(defun cleanup-do-test (cleanups)
  (dolist (cleanup cleanups)
    (ecase (car cleanup)
      (:classes
        (dolist (c (cdr cleanup))
          (let ((class (find-class c 'nil)))
            (when class
              (dolist (super (slot-value class 'direct-superclasses))
                (setf (slot-value class 'direct-subclasses)
                      (remove class (slot-value class 'direct-subclasses))))
              (setf (find-class c) nil)))))
      (:functions
        (dolist (f (cdr cleanup))
          (fmakunbound f)))
      (:setf-generic-functions
        (dolist (f (cdr cleanup))
          (fmakunbound (get-setf-function-name f))))
      (:variables
        (dolist (v (cdr cleanup))
          (makunbound v))))))

#-(or KCL IBCL :Coral GCLisp)
(eval-when (eval)
  (compile 'do-test)
  (compile 'do-test-error)
  (compile 'cleanup-do-test))

  ;;   
;;;;;; 
  ;;   

(do-test "types for early classes"
         ()
  (dolist (x '(standard-object standard-class standard-slot-definition))
    (or (typep (make-instance x) x)
        (do-test-error () "instance of ~S not of type ~S??" x x))))


(do-test "types for late classes"
         ()
  (dolist (x '(standard-method standard-generic-function))
    (or (typep (make-instance x) x)
        (do-test-error () "~&instance of ~S not of type ~S??" x x))))

(defvar *built-in-class-tests*
        '((ARRAY (MAKE-ARRAY '(10 10)))
          (BIT-VECTOR (MAKE-ARRAY 10 :ELEMENT-TYPE 'BIT))
          (CHARACTER #\a)
          (COMPLEX #C(1 2))
          (CONS (LIST 1 2 3))
          (FLOAT 1.3)
          (INTEGER 1)
         ;LIST                   abstract super of cons, null
          (NULL NIL)
         ;NUMBER                 abstract super of complex, float, rational
          (RATIO 1/2)
         ;RATIONAL               abstract super of ratio, integer
         ;SEQUENCE               abstract super of list, vector
          (STRING "foo")
          (SYMBOL 'FOO)
          (VECTOR (VECTOR 1 2 3))))

(do-test "built-in-class-of"
         ()
  (let ((lostp nil))
    (dolist (tst *built-in-class-tests*)
      (unless (eq (find-class (car tst) 't)
                  (class-of (eval (cadr tst))))
        (do-test-error ()
                       "~&class-of ~S was ~A not ~A~%"
                       (cadr tst)
                       (class-name (class-of (eval (cadr tst))))
                       (car tst))
        (setq lostp t)))
    (not lostp)))

(do-test "existence of generic-functions for accessors of early classes"
         ()
  ;; Because accessors are done with add-method, and this has to be done
  ;; specially for early classes it is worth testing to make sure that
  ;; the generic-functions got created for the accessor of early classes.
  ;;
  ;; Of course CLOS wouldn't have loaded if most of these didn't exist,
  ;; but what the hell.
  (dolist (class '(standard-class
                   standard-slot-definition
                   standard-generic-function
                   standard-method))
    (dolist (slotd (class-slots (find-class class)))
      (dolist (rea (slotd-readers slotd))
        (unless (and (gboundp rea)
                     (generic-function-p (gdefinition rea)))
          (do-test-error () "~S isn't a generic function" rea)))
      (dolist (wri (slotd-writers slotd))
        (unless (and (gboundp wri)
                     (generic-function-p (gdefinition wri)))
          (do-test-error () "~S isn't a generic function" wri))))))

(do-test "early reader/writer methods are appropriate class"
         ()
  ;; Because accessors are done with add-method, and this has to be done
  ;; specially for early classes it is worth testing to make sure that
  ;; the generic-functions got created for the accessor of early classes.
  ;;
  ;; Of course CLOS wouldn't have loaded if most of these didn't exist,
  ;; but what the hell.
  (dolist (class '(standard-class
                   standard-slot-definition
                   standard-generic-function
                   standard-method))
    (let ((class (find-class 'standard-class)))
      (flet ((check-reader (gf)
               (let ((reader (get-method (gdefinition gf)
                                         ()
                                         (list class))))
                 (unless (typep reader 'standard-reader-method)
                   (do-test-error () "~S isn't a READER method" reader))))
             (check-writer (gf)
               (let ((writer (get-method (gdefinition gf)
                                         ()
                                         (list (find-class 't) class))))
                 (unless (typep writer 'standard-writer-method)
                   (do-test-error () "~S isn't a WRITER method" writer)))))
        (dolist (slotd (class-direct-slots class))
          (dolist (rea (slotd-readers slotd))
            (check-reader rea))   
          (dolist (wri (slotd-writers slotd))
            (check-writer wri)))))))

(do-test "typep works for standard-classes"
         ((:classes foo1 foo2 bar))

  (defclass foo1 () ())
  (defclass foo2 (foo1) ())
  (defclass bar () ())

  (let ((f1 (make-instance 'foo1))
        (f2 (make-instance 'foo2)))
    (or (typep f1 'foo1)
        (do-test-error
          () "an instance of foo1 isn't subtypep of foo1"))
    (or (not (typep f1 'foo2))
        (do-test-error
          () "an instance of foo1 is suptypep of a subclass of foo1"))
    (or (not (typep f1 'bar))
        (do-test-error
          () "an instance of foo1 is subtypep of an unrelated class"))
    (or (typep f2 'foo1)
        (do-test-error
          () "an instance of foo2 is not subtypep of a super-class of foo2"))
    ))

(do-test "accessors and readers should NOT be inherited"
         ((:classes foo bar)
          (:functions foo-x foo-y))

  (defclass foo ()
       ((x :accessor foo-x)
        (y :reader foo-y)))

  (fmakunbound 'foo-x)
  (fmakunbound 'foo-y)

  (defclass bar (foo)
       (x y))

  (and (fboundp 'foo-x) (do-test-error () "foo-x got inherited?"))
  (and (fboundp 'foo-y) (do-test-error () "foo-x got inherited?")))

(do-test ":accessor and :reader methods go away"
         ((:classes foo)
          (:functions foo-x foo-y)
          (:setf-generic-functions foo-x foo-y))  

  (defclass foo () ((x :accessor foo-x) (y :reader foo-y)))

  (unless (and (fboundp 'foo-x)
               (fboundp 'foo-y))
    (do-test-error t "accessors didn't even get generated?"))

  (defclass foo () (x y))

  (flet ((methods (x)
           (generic-function-methods (symbol-function 'foo-y))))
    
    (and (methods 'foo-x)
         (do-test-error () "~&reader method for foo-x not removed"))
    (and (methods 'foo-y)
         (do-test-error () "~&reader method for foo-y not removed"))
    (and (methods (get-setf-function-name 'foo-y))
         (do-test-error () "~&writer method for foo-y not removed"))
    t))


(defclass test-class-1 ()
     ((x :initform nil :accessor test-class-1-x :initarg :x)
      (y :initform nil :accessor test-class-1-y :initarg :y)))

(do-test "Simple with-accessors test -- does not really exercise the walker."
         ((:functions foo bar))

  (defmethod foo ((obj test-class-1))
    (with-accessors ((x test-class-1-x)
                     (y test-class-1-y))
                    obj
      (list x y)))

  (defmethod bar ((obj test-class-1))
    (with-accessors ((x test-class-1-x)
                     (y test-class-1-y))
                obj
      (setq x 1
            y 2)))

  (or (and (equal '(nil nil) (foo (make-instance 'test-class-1)))
           (equal '(1 2) (foo (make-instance 'test-class-1 :x 1 :y 2))))
      (do-test-error () "FOO (the one that reads) failed"))

  (or (let ((foo (make-instance 'test-class-1)))
        (bar foo)
        (or (and (equal (slot-value foo 'x) 1)
                 (equal (slot-value foo 'y) 2))
            (do-test-error () "BAR (the one that writes) failed")))))

(do-test "Simple with-slots test -- does not really exercise the walker."
         ((:functions foo bar))
  
  (defmethod foo ((obj test-class-1))
    (with-slots (x y)
                obj
      (list x y)))

  (defmethod bar ((obj test-class-1))
    (with-slots ((obj-x x)
                 (obj-y y))
                obj
      (setq obj-x 1
            obj-y 2)))

  (or (and (equal '(nil nil) (foo (make-instance 'test-class-1)))
           (equal '(1 2) (foo (make-instance 'test-class-1 :x 1 :y 2))))
      (do-test-error () "FOO (the one that reads) failed"))

  (or (let ((foo (make-instance 'test-class-1)))
        (bar foo)
        (or (and (equal (slot-value foo 'x) 1)
                 (equal (slot-value foo 'y) 2))
            (do-test-error () "BAR (the one that writes) failed")))))

  ;;   
;;;;;; things that bug fixes prompted.
  ;;   


(do-test "with-slots inside of lexical closures"
         ((:functions frog barg))
  ;; 6/20/86
  ;; The walker was confused about what (FUNCTION (LAMBDA ..)) meant.  It
  ;; didn't walk inside there.  Its sort of surprising this didn't get
  ;; caught sooner.

  (defun frog (fn foos)
    (and foos (cons (funcall fn (car foos)) (frog fn (cdr foos)))))

  (defun barg ()
    (let ((the-test-class (make-instance 'test-class-1 :x 0 :y 3)))
      (with-slots (x y)
                  the-test-class
        (frog #'(lambda (foo) (incf x) (decf y))
             (make-list 3)))))

  (or (equal (barg) '(2 1 0))
      (do-test-error t "lost")))

(do-test "redefinition of default method has proper effect"
         ((:functions foo))
  ;; 5/26/86
  ;; This was caused because the hair for trying to avoid making a
  ;; new discriminating function didn't know that changing the default
  ;; method was a reason to make a new discriminating function.  Fixed
  ;; by always making a new discriminating function when a method is
  ;; added or removed.  The template stuff should keep this from being
  ;; expensive.

  (defmethod foo ((x standard-class)) 'standard-class)
  (defmethod foo (x) 'default)
  (defmethod foo (x) 'new-default)

  (or (eq (foo nil) 'new-default)
      (do-test-error t "lost")))



(defvar *call-next-method-test-object* (make-instance 'standard-object))

(do-test "call-next-method passes original arguments"
         ((:functions foo))
  ;; 2/4/88
  ;; The spec says that call-next-method must pass the original arguments
  ;; to call-next-method when none are supplied.  This tests that.

  (defmethod foo ((x t))
    (unless (eq x *call-next-method-test-object*)
      (do-test-error t "got wrong value")))

  (defmethod foo ((x standard-object))
    (setq x nil)
    (call-next-method))

  (foo *call-next-method-test-object*)

  )

(do-test "call-next-method closures pass original arguments - 1"
         ((:functions foo))
  ;; 2/4/88
  ;; call-next-method must pass the original arguments even when it is
  ;; returned as a lexical closure with indefinite extent

  (defmethod foo ((x t))
    (unless (eq x *call-next-method-test-object*)
      (do-test-error t "got wrong value")))

  (defmethod foo ((x standard-object))
    (setq x nil)
    #'call-next-method)

  (funcall (foo *call-next-method-test-object*))

  )

(do-test "call-next-method closures pass original arguments - 2"
         ((:functions foo))
  ;; 2/4/88
  ;; call-next-method must pass the original arguments even when it is
  ;; returned as a lexical closure with indefinite extent

  (defmethod foo ((x t))
    (unless (eq x *call-next-method-test-object*)
      (do-test-error t "got wrong value")))

  (defmethod foo ((x standard-object))
    #'(lambda ()
        (setq x nil)
        (call-next-method)))

  (funcall (foo *call-next-method-test-object*))

  )

(do-test "call-next-method passes supplied arguments"
         ((:functions foo))
  ;; 2/4/88
  ;; The spec says that call-next-method must pass the original arguments
  ;; to call-next-method when none are supplied.  This tests that.

  (defmethod foo ((x t))
    (unless (eq x *call-next-method-test-object*)
      (do-test-error t "got wrong value")))

  (defmethod foo ((x standard-object))
    (call-next-method *call-next-method-test-object*))

  (foo (make-instance 'standard-object))

  )

(do-test "call-next-method closures pass supplied arguments - 1"
         ((:functions foo))
  ;; 2/4/88
  ;; call-next-method must pass the original arguments even when it is
  ;; returned as a lexical closure with indefinite extent

  (defmethod foo ((x t))
    (unless (eq x *call-next-method-test-object*)
      (do-test-error t "got wrong value")))

  (defmethod foo ((x standard-object))
    #'call-next-method)

  (funcall (foo (make-instance 'standard-object)) *call-next-method-test-object*)

  )

(do-test "call-next-method closures pass supplied arguments - 2"
         ((:functions foo))
  ;; 2/4/88
  ;; call-next-method must pass the original arguments even when it is
  ;; returned as a lexical closure with indefinite extent

  (defmethod foo ((x t))
    (unless (eq x *call-next-method-test-object*)
      (do-test-error t "got wrong value")))

  (defmethod foo ((x standard-object))
    #'(lambda (x)
        (call-next-method x)))

  (funcall (foo (make-instance 'standard-object)) 
	   *call-next-method-test-object*))


(do-test "call-next-method inside of default value form of &optional"
         ((:functions foo))
  ;; 5/3/88
  ;; call-next-method must work inside the default value forms of the
  ;; method's &mumble arguments.

  (defmethod foo1 ((x t) &optional y)
    (declare (ignore y))
    *call-next-method-test-object*)

  (defmethod foo1 ((x standard-object) &optional (y (call-next-method)))
    (list x y))

  (let ((object (make-instance 'standard-object)))
    (unless (equal (foo1 object) (list object *call-next-method-test-object*))
      (do-test-error t "Got wrong value"))))

(do-test "specifying :type when superclass doesn't"
         ((:classes foo bar))
  ;; 3/23/88
  ;; if a suclass specifies the :type slot option for a slot for which no
  ;; superclass specifies a type then the inheritance rule is just to take
  ;; the type specified by the subclass
  
  (defclass foo ()
       ((x)))

  (defclass bar (foo)
       ((x :type number))))


(do-test "Leaky next methods"
         ((:functions foo bar))
  ;; 6/23/88
  ;; Since I use special variables to communicate the next methods info,
  ;; there can be bugs which cause them to leak to the wrong method.

  (defmethod foo ((x standard-class))
    (bar x))

  (defmethod foo ((x class))
    (call-next-method))

  (defmethod foo ((x t))
    t)

  (defmethod bar ((x standard-class))
    (next-method-p))

  (unless (foo (find-class 't))
    (do-test-error nil "Method leaked.")))


;;;
;;; some simple tests for initialization protocols
;;; 8/5/88
;;; 
(proclaim '(special x-initform-fired y-initform-fired z-initform-fired))

(defclass initialization-test-1 ()
     ((x :initform (setq x-initform-fired 'x-initform))
      (y :initform (setq y-initform-fired 'y-initform))
      (z :initform (setq z-initform-fired 'z-initform))))

(defclass initialization-test-2 ()
     ((x :initform (setq x-initform-fired 'x-initform) :initarg :x)
      (y :initform (setq y-initform-fired 'y-initform) :initarg :y)
      (z :initform (setq z-initform-fired 'z-initform) :initarg :z)))

(defclass initialization-test-3 ()
     ((x :initform (setq x-initform-fired 'x-initform) :initarg :x)
      (y :initform (setq y-initform-fired 'y-initform) :initarg :y)
      (z :initform (setq z-initform-fired 'z-initform) :initarg :z))
  (:default-initargs :x 'x-default))

(defclass initalization-test-4 (initialization-test-3)
     ()
  (:default-initargs :z 'z-default))

(defclass initialization-test-5 (initialization-test-4)
     ()
  (:default-initargs :x 'x-default-from-5))
      
(do-test "shared-initialize with T argument and no initargs"
         ()

  (let (x-initform-fired y-initform-fired z-initform-fired)
    (let* ((class (find-class 'initialization-test-1))
           (instance (allocate-instance class)))

      (shared-initialize instance 't)

      (unless x-initform-fired (do-test-error nil "x initform not evaluated"))
      (unless y-initform-fired (do-test-error nil "y initform not evaluated"))
      (unless z-initform-fired (do-test-error nil "z initform not evaluated"))
      
      (unless (eq (slot-value instance 'x) 'x-initform)
        (do-test-error nil "Value of X doesn't match initform"))
      (unless (eq (slot-value instance 'y) 'y-initform)
        (do-test-error nil "Value of X doesn't match initform"))
      (unless (eq (slot-value instance 'z) 'z-initform)
        (do-test-error nil "Value of X doesn't match initform"))

      )))

(do-test "shared-initialize with T argument and initargs"
         ()

  (let (x-initform-fired y-initform-fired z-initform-fired)
    (let* ((class (find-class 'initialization-test-2))
           (instance (allocate-instance class)))

      (shared-initialize instance 't :y 'y-initarg)

      (unless x-initform-fired
        (do-test-error nil "x initform not evaluated"))
      (unless (not y-initform-fired)
        (do-test-error nil "y initform was evaluated"))
      (unless z-initform-fired
        (do-test-error nil "z initform not evaluated"))
      
      (unless (eq (slot-value instance 'x) 'x-initform)
        (do-test-error nil "Value of X doesn't match initform"))
      (unless (eq (slot-value instance 'y) 'y-initarg)
        (do-test-error nil "Value of X doesn't match initform"))
      (unless (eq (slot-value instance 'z) 'z-initform)
        (do-test-error nil "Value of X doesn't match initform"))

      )))

(do-test "initialization arguments rules test"
         ((:classes foo bar))

  (defclass foo ()
       ((x :initarg a)))

  (defclass bar (foo)
       ((x :initarg b))
    (:default-initargs a 1 b 2))

  (unless (and (equal (default-initargs (find-class 'bar) '())
                      '(b 2 a 1))
               (equal (default-initargs (find-class 'bar) '(a 3))
                      '(a 3 b 2))
               (equal (default-initargs (find-class 'bar) '(b 4))
                      '(b 4 a 1))
               (equal (default-initargs (find-class 'bar) '(a 1 a 2))
                      '(a 1 a 2 b 2)))
    (do-test-error nil "default-initargs got wrong value"))

  (unless (and (eq (slot-value (make-instance 'bar) 'x) 1)
               (eq (slot-value (make-instance 'bar 'a 3) 'x) 3)
               (eq (slot-value (make-instance 'bar 'b 4) 'x) 4)
               (eq (slot-value (make-instance 'bar 'a 1 'a 2) 'x) 1))
    (do-test-error nil "initialization in make-instance failed"))

  )


#| testing a pair of lists for equality bogus, '(a b c) <> '(b c a)

(do-test "more tests for initialization arguments rules"
         ((:classes foo fie bar baz))

  (defclass foo ()
       ((a :initform 'initform-foo-a)
        (b :initarg :foo-b)
        (c :initform 'initform-foo-c)
        (d :initarg :foo-d))
    (:default-initargs :foo-b 'initarg-foo-b
                       :foo-d 'initarg-foo-d))
  (defclass fie (foo)
       ((a :initform 'initform-fie-a)
        (b :initarg :fie-b)
        (c :initform 'initform-fie-c :allocation :class)
        (d :initarg :fie-d :allocation :class))
    (:default-initargs :fie-b 'initarg-fie-b
                       :fie-d 'initarg-fie-d))
  (defclass bar (foo)
       ((a :initform 'initform-bar-a)
        (b :initarg :bar-b)
        (c :initform 'initform-bar-c)
        (d :initarg :bar-d))
    (:default-initargs :bar-b 'initarg-bar-b
                       :bar-d 'initarg-bar-d))
  (defclass baz (fie bar)
       ((a :initform 'initform-baz-a)
        (b :initarg :baz-b)
        (c :initform 'initform-baz-c)
        (d :initarg :baz-d))
    (:default-initargs :baz-b 'initarg-baz-b
                       :baz-d 'initarg-baz-d))

  (unless (and (equal (default-initargs (find-class 'foo) ())
                      '(:foo-d initarg-foo-d 
			:foo-b initarg-foo-b))
               (equal (default-initargs (find-class 'fie) ())
                      '(:fie-b initarg-fie-b
                        :fie-d initarg-fie-d
                        :foo-b initarg-foo-b
                        :foo-d initarg-foo-d))
               (equal (default-initargs (find-class 'bar) ())
                      '(:bar-b initarg-bar-b
                        :bar-d initarg-bar-d
                        :foo-b initarg-foo-b
                        :foo-d initarg-foo-d))
               (equal (default-initargs (find-class 'baz) ())
                      '(:baz-b initarg-baz-b
                        :baz-d initarg-baz-d
                        :fie-b initarg-fie-b
                        :fie-d initarg-fie-d
                        :bar-b initarg-bar-b
                        :bar-d initarg-bar-d
                        :foo-b initarg-foo-b
                        :foo-d initarg-foo-d)))
    (do-test-error nil "default-initargs got wrong value"))
  )
|#
(do-test "initialization protocols"
         ((:classes foo))

  (let ((initform-for-x 'initform-x)
        (initform-for-y 'initform-y)
        (initform-for-z 'initform-z)
        (default-initarg-for-x 'default-initarg-x)
        (initarg-supplied-for-z 'initarg-z)
        instance-of-foo)
    
    (defclass foo ()
         ((x :initform initform-for-x :initarg :x)
          (y :initform initform-for-y :initarg :y)
          (z :initform initform-for-z :initarg :z))
      (:default-initargs :x default-initarg-for-x))

    (setq instance-of-foo (make-instance 'foo :z initarg-supplied-for-z))

    (unless (and (eq (slot-value instance-of-foo 'x)
                     default-initarg-for-x)
                 (eq (slot-value instance-of-foo 'y)
                     initform-for-y)
                 (eq (slot-value instance-of-foo 'z)
                     initarg-supplied-for-z))
      (do-test-error nil "initialization failed"))

    (setq instance-of-foo
          (reinitialize-instance (allocate-instance (find-class 'foo))
                                 :z initarg-supplied-for-z))

    (unless (and (not (slot-boundp instance-of-foo 'x))
                 (not (slot-boundp instance-of-foo 'y))
                 (eq (slot-value instance-of-foo 'z)
                     initarg-supplied-for-z))
      (do-test-error nil "initialization failed")))

  )

(do-test "update-instance-for-different-class"
         ((:classes foo bar))

  (let ((initform-for-x 'initform-x)
        (initform-for-y 'initform-y)
        (default-initarg-for-x 'default-initarg-x)
        (initform-for-z 'initform-z)
        (initform-for-u 'initform-u)
        (initform-for-v 'initform-v)
        (default-initarg-for-z 'default-intiarg-z)
        (initarg-supplied-for-v 'initarg-v)
        instance-of-foo
        instance-of-bar)

    (defclass foo ()
         ((x :initform initform-for-x :initarg :x)
          (y :initform initform-for-y :initarg :y))
      (:default-initargs :x default-initarg-for-x))

    (defclass bar ()
         ((x :initform initform-for-x :initarg :x)
          (y :initform initform-for-y :initarg :y)
          (z :initform initform-for-z :initarg :z)
          (u :initform initform-for-u :initarg :u)
          (v :initform initform-for-v :initarg :v))
      (:default-initargs :z default-initarg-for-z))

    (setq instance-of-foo (make-instance 'foo))
    (setq instance-of-bar (allocate-instance (find-class 'bar)))
    (update-instance-for-different-class instance-of-foo instance-of-bar
                                         :v initarg-supplied-for-v)
    (unless (and (not (slot-boundp instance-of-bar 'x))
                 (not (slot-boundp instance-of-bar 'y))
                 (eq (slot-value instance-of-bar 'z) initform-for-z)
                 (eq (slot-value instance-of-bar 'u) initform-for-u)
                 (eq (slot-value instance-of-bar 'v) initarg-supplied-for-v))
      (do-test-error nil "initialization failed"))))

(do-test "only needed forms should be evaluated in initializing instances"
         ((:classes foo))

  (defclass foo ()
    ((x :initform (do-test-error nil "x initform was evaluated")
        :initarg :x)
     (y :initform (do-test-error nil "y initform was evaluated")
        :initarg :y)
     (z :initform (do-test-error nil "z initform was evaluated")
        :initarg :z))
    (:default-initargs :y 1
                       :z (do-test-error nil "z default initarg was evaluated")))

  (make-instance 'foo :x 1 :z 1))


;;;
;;; We need to put these class defenitions in top level.
;;;

(defclass class-for-testing-change-class-1 ()
  ((x :initform 'x :accessor class-1-x)
   (y :initform 'y :accessor class-1-y)))

(defclass class-for-testing-change-class-2 ()
  ((a :initform 'a :accessor class-2-a)
   (b :initform 'b :accessor class-2-b)))

(do-test "update-instance-for-different-class/change-class"
         ()

  (defmethod update-instance-for-different-class
             ((previous class-for-testing-change-class-1)
              (current class-for-testing-change-class-2)
              &rest initargs)
    (declare (ignore initargs))
    (setf (class-2-a current) (class-1-x previous))
    (setf (class-2-b current) (class-1-y previous)))

  (let ((f1 (make-instance 'class-for-testing-change-class-1))
        (f2 (make-instance 'class-for-testing-change-class-1)))
    (change-class f1 (find-class 'class-for-testing-change-class-2))
    (unless (and (eq (class-2-a f1) (class-1-x f2))
                 (eq (class-2-b f1) (class-1-y f2)))
      (do-test-error nil "change class failed")))
  )

(cleanup-do-test '((:classes class-for-testing-redefined-class)
                   (:functions test-x test-y test-a)
                   (:setf-generic-functions class-x class-y)))
                    
(let (foo)
  (defclass class-for-testing-redefined-class ()
    ((x :initform 'x :accessor test-x)
     (y :initform 'y :accessor test-y)))

  (setq foo (make-instance 'class-for-testing-redefined-class))

  (defclass class-for-testing-redefined-class ()
    ((a :initform 0 :accessor test-a)
     (y :initform 1 :accessor test-y)))

  (do-test "update-instance-for-redefined-class/make-instances-obsolete(1)"
        ()
    (unless (and (eq (test-a foo) 0)
                 (eq (test-y foo) 'y))
      (do-test-error nil "default behavior failed"))))

(cleanup-do-test '((:classes x-y-pos)
                   (:functions pos-x pos-y pos-rho pos-theta)
                   (:setf-generic-functions pos-x pos-y pos-rho pos-theta)))

(let (old-pos new-pos)

  (defclass x-y-pos ()
    ((x :initform 3 :accessor pos-x)
     (y :initform 4 :accessor pos-y)))
  
  (setq old-pos (make-instance 'x-y-pos))
  
  (defclass x-y-pos ()
    ((rho :initform 0 :accessor pos-rho)
     (theta :initform 0 :accessor pos-theta)))
  
  (do-test "update-instance-for-redefined-class/make-instances-obsolete(2)"
        ()

    (defmethod update-instance-for-redefined-class :before
               ((pos x-y-pos) added deleted plist &key)
      ;; Transform the x-y coordinates to polar coordinates
      ;; and store into the new slots
      (let ((x (getf plist 'x))
            (y (getf plist 'y)))
        (setf (pos-rho pos) (sqrt (+ (* x x) (* y y)))
              (pos-theta pos) (atan y x))))

    (defmethod pos-x ((pos x-y-pos))
      (with-slots (rho theta) pos (* rho (cos theta))))

    (defmethod (setf pos-x) (new-x (pos x-y-pos))
      (with-slots (rho theta) pos
        (let ((y (pos-y pos)))
          (setq rho (sqrt (+ (* new-x new-x) (* y y)))
                theta (atan y new-x))
          new-x)))
    
    (defmethod pos-y ((pos x-y-pos))
      (with-slots (rho theta) pos (* rho (sin theta))))
  
    (defmethod (setf pos-y) (new-y (pos x-y-pos))
      (with-slots (rho theta)
        (let ((x (pos-x pos)))
          (setq rho (sqrt (+ (* x x) (* new-y new-y)))
                theta (atan new-y x))
          new-y)))

    (unless (and (equalp 5 (pos-rho old-pos))
                 (equalp (* 5 (cos (atan 4 3))) (pos-x old-pos))
                 (equalp (* 5 (sin (atan 4 3))) (pos-y old-pos)))
      (do-test-error nil "specialized behaivior failed"))
    ))

(cleanup-do-test '((:classes class-for-testing-redefined-class
                             test-obsolete-class)
                   (:functions test-x test-y test-a)
                   (:setf-generic-functions class-x class-y)))

(defclass test-obsolete-class (standard-class) ())

(defmethod check-super-metaclass-compatibility ((x test-obsolete-class)
                                                (y standard-class))
  't)
                    
(let ((foo 'nil)
      bar)
  (defmethod make-instances-obsolete ((x test-obsolete-class))
    (setq foo 'called)
    (call-next-method))

  (defclass class-for-testing-redefined-class ()
    ((x :initform 'x :accessor test-x)
     (y :initform 'y :accessor test-y))
    (:metaclass test-obsolete-class))

  (setq bar (make-instance 'class-for-testing-redefined-class))

  (defclass class-for-testing-redefined-class ()
    ((a :initform 0 :accessor test-a)
     (y :initform 1 :accessor test-y)))

  (do-test "update-instance-for-redefined-class/make-instances-obsolete(3)"
        ()
    (unless (and (eq (test-a bar) 0)
                 (eq (test-y bar) '1)
                 (eq foo 'called))
      (do-test-error nil "imcompatible class change failed"))))

(cleanup-do-test '((:classes class-for-testing-redefined-class)
                   (:functions test-x test-y test-a)
                   (:setf-generic-functions class-x class-y)))
                    
(let (foo)
  (defclass class-for-testing-redefined-class ()
    ((x :initform 'x :accessor test-x)
     (y :initform 'y :accessor test-y)))

  (setq foo (make-instance 'class-for-testing-redefined-class))

  (make-instances-obsolete 'class-for-testing-redefined-class)
  
  (do-test "update-instance-for-redefined-class/make-instances-obsolete(4)"
        ()
    (unless (and (eq (test-x foo) 'x)
                 (eq (test-y foo) 'y))
      (do-test-error nil "call make-instances-obsolete by hand failed"))))

(do-test "slot-mumble functions"
         ((:variables foo1 bar1)
          (:classes foo bar))

  (defclass foo-sm ()
    ((x :initform 'x :allocation :class)
     (y :initform 'y)
     (z :allocation :class)
     (u)))

  (defclass bar-sm ()
    ((x :initform 'x :allocation :class)
     (y :initform 'y)
     (z :allocation :class)
     (u))
    (:metaclass funcallable-standard-class))

  (defmethod slot-missing ((class standard-class)
                           (instance foo-sm)
                           slot-name operation &optional new-value)
    (list* class instance slot-name operation new-value))
  
  (defmethod slot-missing ((class standard-class)
                           (instance bar-sm)
                           slot-name operation &optional new-value)
    (list* class instance slot-name operation new-value))

  (defmethod slot-unbound ((class standard-class)
                           (instance foo-sm)
                           slot-name)
    (list class instance slot-name))
  
  (defmethod slot-unbound ((class funcallable-standard-class)
                           (instance bar-sm)
                           slot-name)
    (list class instance slot-name))
  
  (setq foo1 (make-instance 'foo-sm))
  (setq bar1 (make-instance 'bar-sm))

  (flet ((test1 (instance)
           (and (eq (slot-value instance 'x) 'x)
                (eq (slot-value instance 'y) 'y)
                (equal (slot-value instance 'z)
                       (list (class-of instance) instance 'z))
                (equal (slot-value instance 'u)
                       (list (class-of instance) instance 'u))
                (slot-boundp instance 'x)
                (slot-boundp instance 'y)
                (not (slot-boundp instance 'z))
                (not (slot-boundp instance 'u))))
         (test2 (instance)
           (and (not (slot-boundp instance 'x))
                (not (slot-boundp instance 'y))
                (slot-boundp instance 'z)
                (slot-boundp instance 'u)
                (equal (slot-value instance 'x)
                       (list (class-of instance) instance 'x))
                (equal (slot-value instance 'y)
                       (list (class-of instance) instance 'y))
                (eq (slot-value instance 'z) 'z)
                (eq (slot-value instance 'u) 'u)))
         (test3 (instance)
           (and (slot-exists-p instance 'x)
                (slot-exists-p instance 'y)))
         (test4 (instance)
           (and (equal (slot-value instance 'a)
                       (list (class-of instance)
                             instance
                             'a
                             'slot-value))
                (equal (setf (slot-value instance 'a) 'b)
                       (list* (class-of instance)
                              instance
                              'a
                              'setf
                              'b))
                (equal (slot-boundp instance 'a)
                       (list (class-of instance)
                             instance
                             'a
                             'slot-boundp))

                (equal (slot-makunbound instance 'a)
                       (list (class-of instance)
                             instance
                             'a
                             'slot-makunbound)))))

        (unless (and (test1 foo1)
                     (test1 bar1))
          (do-test-error nil "slot functions test1 failed"))

        (slot-makunbound foo1 'x)
        (slot-makunbound foo1 'y)
        (setf (slot-value foo1 'z) 'z)
        (setf (slot-value foo1 'u) 'u)
        (slot-makunbound bar1 'x)
        (slot-makunbound bar1 'y)
        (setf (slot-value bar1 'z) 'z)
        (setf (slot-value bar1 'u) 'u)

        (unless (and (test2 foo1)
                     (test2 bar1))
          (do-test-error nil "slot functions test2 failed"))

        (unless (and (test3 foo1)
                     (test3 bar1))
          (do-test-error nil "slot functions test3 failed"))
        
        (unless (and (test4 foo1)
                     (test4 bar1))
          (do-test-error nil "slot function test4 failed"))
        ))


(cleanup-do-test '((:classes foo-sm bar-sm)
                   (:functions foo-x foo-y bar-x bar-y)))

(defclass foo ()
  ((x :initform 'x :allocation :class :reader foo-x)
   (y :initform 'y :reader foo-y)))

(defclass bar ()
  ((x :allocation :class :reader bar-x)
   (y :reader bar-y)))

(do-test "slot-value/slot-unbound for pv optimization case and :reader method"
         ((:functions get-foo-x get-foo-y get-x-1 get-y-1
                      get-bar-x get-bar-y get-x-2 get-y-2)
          (:variables foo1 bar1))

  (defmethod get-foo-x ((foo1 foo))
    (slot-value foo1 'x))
  (defmethod get-foo-y ((foo1 foo))
    (slot-value foo1 'y))

  (defun get-x-1 (foo1)
    (slot-value foo1 'x))
  (defun get-y-1 (foo1)
    (slot-value foo1 'y))

  (defmethod slot-unbound ((class standard-class) (instance foo) slot-name)
    (list class instance slot-name))
  
  (setq foo1 (make-instance 'foo))
  
  (unless (and (eq (get-foo-x foo1) 'x)
               (eq (get-foo-y foo1) 'y)
               (eq (get-x-1 foo1) 'x)
               (eq (get-y-1 foo1) 'y)
               (eq (foo-x foo1) 'x)
               (eq (foo-y foo1) 'y))
    (do-test-error nil "slot-value failed"))

  (unless (and (eq (slot-makunbound foo1 'x) foo1)
               (eq (slot-makunbound foo1 'y) foo1))
    (do-test-error nil "slot-makunbound returns wrong value"))

  (unless (and (equal (get-foo-x foo1)
                      (list (find-class 'foo) foo1 'x))
               (equal (get-foo-y foo1)
                      (list (find-class 'foo) foo1 'y))
               (equal (get-x-1 foo1)
                      (list (find-class 'foo) foo1 'x))
               (equal (get-y-1 foo1)
                      (list (find-class 'foo) foo1 'y))
               (equal (foo-x foo1)
                      (list (find-class 'foo) foo1 'x))
               (equal (foo-y foo1)
                      (list (find-class 'foo) foo1 'y)))
    (do-test-error nil "slot-value/slot-unbound failed"))

  (defmethod get-bar-x ((bar1 bar))
    (slot-value bar1 'x))
  (defmethod get-bar-y ((bar1 bar))
    (slot-value bar1 'y))

  (defun get-x-2 (bar1)
    (slot-value bar1 'x))
  (defun get-y-2 (bar1)
    (slot-value bar1 'y))

  (defmethod slot-unbound ((class standard-class) (instance bar) slot-name)
    (list class instance slot-name))

  (setq bar1 (make-instance 'bar))

  (unless (and (equal (get-bar-x bar1)
                      (list (find-class 'bar) bar1 'x))
               (equal (get-bar-y bar1)
                      (list (find-class 'bar) bar1 'y))
               (equal (get-x-2 bar1)
                      (list (find-class 'bar) bar1 'x))
               (equal (get-y-2 bar1)
                      (list (find-class 'bar) bar1 'y))
               (equal (bar-x bar1)
                      (list (find-class 'bar) bar1 'x))
               (equal (bar-y bar1)
                      (list (find-class 'bar) bar1 'y)))
    (do-test-error nil "slot-value/slot-unbound failed")))

  
(do-test "defmethod/call-next-method/&aux variable"
         ((:variables foo1 bar1)
          (:classes foo bar)
          (:functions test1 test2 test3))

  (defclass foo ()
    ((x :initform 0)
     (y :initform 1)))

  (defclass bar (foo) ())

  (defmethod test1 ((foo1 foo) &aux aux-arg)
    (setq aux-arg (list foo1)))

  (defmethod test1 ((bar1 bar) &aux aux-arg)
    (setq aux-arg (list (list bar1)))
    (call-next-method)
    aux-arg)

  (setq foo1 (make-instance 'foo))
  (setq bar1 (make-instance 'bar))
  (unless (and (equal (test1 foo1) (list foo1))
               (equal (test1 bar1) (list (list bar1))))
    (do-test-error nil "defmethod with call-next-method and &aux failed")))

;;;
;;; defconstructor tests
;;;
(format t
        "~%Testing defconstructor [methods, default/initform, slot-filling]")

(defun check-slots (object &rest names-and-values)
  (doplist (name value) names-and-values
    (unless (if (eq value :unbound)
                (not (slot-boundp object name))
                (and (slot-boundp object name)
                     (eq (slot-value object name) value)))
      (return-from check-slots nil)))
  't)

;;;
;;; [methods, default/initform, slot-filling]
;;; methods:           [nil, :after, t]
;;; default/initform:  [nil, :constant, t]
;;; slot-filling:      [:instance, :class]
;;;
;;; supplied:          [nil, :constant, t]


(cleanup-do-test '((:classes foo1 foo2 foo3 foo4
                             foo5 foo6 foo7 foo8
                             foo9 foo10 foo11 foo12)
                   (:variables *a-initform* *b-initform* *c-initform*
                               *a-default* *b-default* *c-default*
                               *a-supplied* *b-supplied* *c-supplied*)
                   (:functions foo1-test1 foo1-test2 foo1-test3
                               foo2-test1 foo2-test2 foo2-test3
                               foo3-test1 foo3-test2 foo3-test3
                               foo4-test1 foo4-test2 foo4-test3
                               foo5-test1 foo5-test2 foo5-test3
                               foo6-test1 foo6-test2 foo6-test3
                               foo7-test1 foo7-test2 foo7-test3
                               foo8-test1 foo8-test2 foo8-test3
                               foo9-test1 foo9-test2 foo9-test3
                               foo10-test1 foo10-test2 foo10-test3
                               foo11-test1 foo11-test2 foo11-test3
                               foo12-test1 foo12-test2 foo12-test3)))

(defvar *a-initform* 'a-initform)
(defvar *b-initform* 'b-initform)
(defvar *c-initform* 'c-initform)
(defvar *a-default* 'a-default)
(defvar *b-default* 'b-default)
(defvar *c-default* 'c-default)
(defvar *a-supplied* 'a-supplied)
(defvar *b-supplied* 'b-supplied)
(defvar *c-supplied* 'c-supplied)

;;;
;;; foo1
;;; [methods, default/initform, slot-filing]
;;; (t,       t,                :class)

(defclass foo1 ()
    ((a :initarg :a :initform *a-initform*)
     (b :initarg :b :initform *b-initform*)
     (c :initarg :c :allocation :class :initform *c-initform*))
  (:default-initargs :b *b-default* :c *c-default*))

(defmethod *initialize-instance :before ((instance foo1) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       t,                :class) (1)"
         ((:functions foo1-test1 foo1-test2 foo1-test3))

  (defconstructor foo1-test1 foo1 ())
  (defconstructor foo1-test2 foo1 () :a 1 :b 2 :c 3)
  (defconstructor foo1-test3 foo1 (a b c) :a a :b b :c c)

  (dotimes (i 2)                                ;Do it twice to be sure that
                                                ;the constructor works more
                                                ;than just the first time.
    (unless (check-slots (foo1-test1)
                         'a *a-initform*
                         'b *b-default*
                         'c *c-default*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo1-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo1-test3 *a-supplied* *b-supplied* *c-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-supplied*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))
;;;
;;; foo2
;;; [methods, default/initform, slot-filling]
;;; (t,       t,                :class)

(defclass foo2 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class :initform *c-initform* :initarg :c))
  (:default-initargs :b *b-default*))

(defmethod *initialize-instance :before ((instance foo2) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       t,                :class) (2)"
         ((:functions foo2-test1 foo2-test2 foo2-test3))

  (defconstructor foo2-test1 foo2 ())
  (defconstructor foo2-test2 foo2 () :a 1 :b 2 :c 3)
  (defconstructor foo2-test3 foo2 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (foo2-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c *c-initform*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo2-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo2-test3 *a-supplied* *b-supplied* *c-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-supplied*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo3
;;; [methods, default/initform, slot-filling]
;;; (t,       t,                :instance)

(defclass foo3 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class :initform *c-initform*))
  (:default-initargs :b *b-default*))

(defmethod *initialize-instance :before ((instance foo3) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       t,                :instance) (1)"
         ((:functions foo3-test1 foo3-test2 foo3-test3))

  (defconstructor foo3-test1 foo3 ())
  (defconstructor foo3-test2 foo3 () :a 1 :b 2)
  (defconstructor foo3-test3 foo3 (a b) :a a :b b)
  
  
  (dotimes (i 2)
    (unless (check-slots (foo3-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c *c-initform*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo3-test2) 'a '1 'b '2 'c *c-initform*)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo3-test3 *a-supplied* *b-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-initform*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo4
;;; [methods, default/initform, slot-filling]
;;; (t,       t,                :instance)

(defclass foo4 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class))
  (:default-initargs :b *b-default*))

(defmethod *initialize-instance :before ((instance foo4) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       t,                :instance) (2)"
         ((:functions foo4-test1 foo4-test2 foo4-test3))

  (defconstructor foo4-test1 foo4 ())
  (defconstructor foo4-test2 foo4 () :a 1 :b 2)
  (defconstructor foo4-test3 foo4 (a b) :a a :b b)

  (dotimes (i 2)
    (unless (check-slots (foo4-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo4-test2) 'a '1 'b '2 'c :unbound)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo4-test3 *a-supplied* *b-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c :unbound)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo5
;;; [methods, default/initform, slot-filling]
;;; (:after,  t,                :class)

(defclass foo5 ()
    ((a :initarg :a :initform *a-initform*)
     (b :initarg :b :initform *b-initform*)
     (c :initarg :c :allocation :class :initform *c-initform*))
  (:default-initargs :b *b-default* :c *c-default*))

(defmethod *initialize-instance :after ((instance foo5) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  t,                :class) (1)"
         ((:functions foo5-test1 foo5-test2 foo5-test3))

  (defconstructor foo5-test1 foo5 ())
  (defconstructor foo5-test2 foo5 () :a 1 :b 2 :c 3)
  (defconstructor foo5-test3 foo5 (a b c) :a a
                                          :b b
                                          :c c)

  (dotimes (i 2)
    (unless (check-slots (foo5-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c *c-default*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo5-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo5-test3 *a-supplied* *b-supplied* *c-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-supplied*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo6
;;; [methods, default/initform, slot-filling]
;;; (:after,  t,                :class)

(defclass foo6 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class :initform *c-initform* :initarg :c))
  (:default-initargs :b *b-default*))

(defmethod *initialize-instance :after ((instance foo6) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  t,                :class) (2)"
         ((:functions foo6-test1 foo6-test2 foo6-test3))

  (defconstructor foo6-test1 foo6 ())
  (defconstructor foo6-test2 foo6 () :a 1 :b 2 :c 3)
  (defconstructor foo6-test3 foo6 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (foo6-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c *c-initform*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo6-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo6-test3 *a-supplied* *b-supplied* *c-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-supplied*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo7
;;; [methods, default/initform, slot-filling]
;;; (:after,  t,                :instance)

(defclass foo7 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class :initform *c-initform*))
  (:default-initargs :b *b-default*))

(defmethod *initialize-instance :after ((instance foo7) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  t,                :instance) (1)"
         ((:functions foo7-test1 foo7-test2 foo7-test3))

  (defconstructor foo7-test1 foo7 ())
  (defconstructor foo7-test2 foo7 () :a 1 :b 2)
  (defconstructor foo7-test3 foo7 (a b) :a a :b b)
  
  (dotimes (i 2)
    (unless (check-slots (foo7-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c *c-initform*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo7-test2) 'a '1 'b '2 'c *c-initform*)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo7-test3 *a-supplied* *b-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-initform*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo8
;;; [methods, default/initform, slot-filling]
;;; (:after,  t,                :instance)

(defclass foo8 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class))
  (:default-initargs :b *b-default*))

(defmethod *initialize-instance :after ((instance foo8) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  t,                :instance) (2)"
         ((:functions foo8-test1 foo8-test2 foo8-test3))

  (defconstructor foo8-test1 foo8 ())
  (defconstructor foo8-test2 foo8 () :a 1 :b 2)
  (defconstructor foo8-test3 foo8 (a b) :a a :b b)

  (dotimes (i 2)
    (unless (check-slots (foo8-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo8-test2) 'a '1 'b '2 'c :unbound)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo8-test3 *a-supplied* *b-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c :unbound)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo9
;;; [methods, default/initform, slot-filling]
;;; (nil,     t,                :class)

(defclass foo9 ()
    ((a :initarg :a :initform *a-initform*)
     (b :initarg :b :initform *b-initform*)
     (c :initarg :c :allocation :class :initform *c-initform*))
  (:default-initargs :b *b-default* :c *c-default*))

(do-test "defconstructor (nil,     t,                :class) (1)"
         ((:functions foo9-test1 foo9-test2 foo9-test3))

  (defconstructor foo9-test1 foo9 ())
  (defconstructor foo9-test2 foo9 () :a 1 :b 2 :c 3)
  (defconstructor foo9-test3 foo9 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (foo9-test1) 'a *a-initform*
                                      'b *b-default*
                                      'c *c-default*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo9-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo9-test3 *a-supplied* *b-supplied* *c-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-supplied*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))
    
;;;
;;; foo10
;;; [methods, default/initform, slot-filling]
;;; (nil,     t,                :class)

(defclass foo10 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class :initform *c-initform* :initarg :c))
  (:default-initargs :b *b-default*))

(do-test "defconstructor (nil,     t,                :class) (2)"
         ((:functions foo10-test1 foo10-test2 foo10-test3))

  (defconstructor foo10-test1 foo10 ())
  (defconstructor foo10-test2 foo10 () :a 1 :b 2 :c 3)
  (defconstructor foo10-test3 foo10 (a b c) :a a
                                            :b b
                                            :c c)
  (dotimes (i 2)
    (unless (check-slots (foo10-test1) 'a *a-initform*
                                       'b *b-default*
                                       'c *c-initform*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo10-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo10-test3 *a-supplied* *b-supplied* *c-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-supplied*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo11
;;; [methods, default/initform, slot-filling]
;;; (nil,     t,                :instance)

(defclass foo11 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class :initform *c-initform*))
  (:default-initargs :b *b-default*))

(do-test "defconstructor (nil,     t,                :instance) (1)"
         ((:functions foo11-test1 foo11-test2 foo11-test3))

  (defconstructor foo11-test1 foo11 ())
  (defconstructor foo11-test2 foo11 () :a 1 :b 2)
  (defconstructor foo11-test3 foo11 (a b) :a a :b b)
  
  (dotimes (i 2)
    (unless (check-slots (foo11-test1) 'a *a-initform*
                                       'b *b-default*
                                       'c *c-initform*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo11-test2) 'a '1 'b '2 'c *c-initform*)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo11-test3 *a-supplied* *b-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c *c-initform*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; foo12
;;; [methods, default/initform, slot-filling]
;;; (nil,     t,                :instance)

(defclass foo12 ()
    ((a :initform *a-initform* :initarg :a)
     (b :initform *b-initform* :initarg :b)
     (c :allocation :class))
  (:default-initargs :b *b-default*))

(defmethod *initialize-instance :after ((instance foo12) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (nil,     t,                :instance) (2)"
         ((:functions foo12-test1 foo12-test2 foo12-test3))

  (defconstructor foo12-test1 foo12 ())
  (defconstructor foo12-test2 foo12 () :a 1 :b 2)
  (defconstructor foo12-test3 foo12 (a b) :a a :b b)

  (dotimes (i 2)
    (unless (check-slots (foo12-test1) 'a *a-initform*
                                       'b *b-default*
                                       'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo12-test2) 'a '1 'b '2 'c :unbound)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (foo12-test3 *a-supplied* *b-supplied*)
                         'a *a-supplied*
                         'b *b-supplied*
                         'c :unbound)
      (do-test-error nil "non constant initargs failed (~D time)" i))))


(cleanup-do-test '((:classes bar1 bar2 bar3 bar4
                             bar5 bar6 bar7 bar8
                             bar9 bar10 bar11 bar12)
                   (:functions bar1-test1 bar1-test2 bar1-test3
                               bar2-test1 bar2-test2 bar2-test3
                               bar3-test1 bar3-test2 bar3-test3
                               bar4-test1 bar4-test2 bar4-test3
                               bar5-test1 bar5-test2 bar5-test3
                               bar6-test1 bar6-test2 bar6-test3
                               bar7-test1 bar7-test2 bar7-test3
                               bar8-test1 bar8-test2 bar8-test3
                               bar9-test1 bar9-test2 bar9-test3
                               bar10-test1 bar10-test2 bar10-test3
                               bar11-test1 bar11-test2 bar11-test3
                               bar12-test1 bar12-test2 bar12-test3)))

;;;
;;; bar1
;;; [methods, default/initform, slot-filling]
;;; (t,       :constant,        :class)

(defclass bar1 ()
    ((a :initarg :a :initform 1)
     (b :initarg :b :initform 2)
     (c :initarg :c :allocation :class :initform 3))
  (:default-initargs :b 5 :c 6))

(defmethod *initialize-instance :before ((instance bar1) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       :constant,        :class) (1)"
         ((:functions bar1-test1 bar1-test2 bar1-test3))

  (defconstructor bar1-test1 bar1 ())
  (defconstructor bar1-test2 bar1 () :a 1 :b 2 :c 3)
  (defconstructor bar1-test3 bar1 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (bar1-test1) 'a '1 'b '5 'c '6)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar1-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar1-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar2
;;; [methods, default/initform, slot-filling]
;;; (t,       :constant,        :class)

(defclass bar2 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class :initform 3 :initarg :c))
  (:default-initargs :b 5))

(defmethod *initialize-instance :before ((instance bar2) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       :constant,        :class) (2)"
         ((:functions bar2-test1 bar2-test2 bar2-test3))

  (defconstructor bar2-test1 bar2 ())
  (defconstructor bar2-test2 bar2 () :a 1 :b 2 :c 3)
  (defconstructor bar2-test3 bar2 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (bar2-test1) 'a '1 'b '5 'c '3)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar2-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar2-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar3
;;; [methods, default/initform, slot-filling]
;;; (t,       :constant,        :instance)

(defclass bar3 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class :initform 3))
  (:default-initargs :b 5))

(defmethod *initialize-instance :before ((instance bar3) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       :constant,        :instance) (1)"
         ((:functions bar3-test1 bar3-test2 bar3-test3))

  (defconstructor bar3-test1 bar3 ())
  (defconstructor bar3-test2 bar3 () :a 1 :b 2)
  (defconstructor bar3-test3 bar3 (a b) :a a :b b)
  
  (dotimes (i 2)
    (unless (check-slots (bar3-test1) 'a '1 'b '5 'c '3)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar3-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar3-test3 7 8) 'a '7 'b '8 'c '3)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar4
;;; [methods, default/initform, slot-filling]
;;; (t,       :constant,        :instance)

(defclass bar4 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class))
  (:default-initargs :b 5))

(defmethod *initialize-instance :before ((instance bar4) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       :constant,        :instance) (2)"
         ((:functions bar4-test1 bar4-test2 bar4-test3))

  (defconstructor bar4-test1 bar4 ())
  (defconstructor bar4-test2 bar4 () :a 1 :b 2)
  (defconstructor bar4-test3 bar4 (a b) :a a :b b)

  (dotimes (i 2)
    (unless (check-slots (bar4-test1) 'a '1 'b '5 'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar4-test2) 'a '1 'b '2 'c :unbound)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar4-test3 7 8) 'a '7 'b '8 'c :unbound)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar5
;;; [methods, default/initform, slot-filling]
;;; (:after,  :constant,        :class)

(defclass bar5 ()
    ((a :initarg :a :initform 1)
     (b :initarg :b :initform 2)
     (c :initarg :c :allocation :class :initform 3))
  (:default-initargs :b 5 :c 6))

(defmethod *initialize-instance :after ((instance bar5) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  :constant,        :class) (1)"
         ((:functions bar5-test1 bar5-test2 bar5-test3))

  (defconstructor bar5-test1 bar5 ())
  (defconstructor bar5-test2 bar5 () :a 1 :b 2 :c 3)
  (defconstructor bar5-test3 bar5 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (bar5-test1) 'a '1 'b '5 'c '6)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar5-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar5-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar6
;;; [methods, default/initform, slot-filling]
;;; (:after,  :constant,        :class)

(defclass bar6 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class :initform 3 :initarg :c))
  (:default-initargs :b 5))

(defmethod *initialize-instance :after ((instance bar6) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  :constant,        :class) (2)"
         ((:functions bar6-test1 bar6-test2 bar6-test3))

  (defconstructor bar6-test1 bar6 ())
  (defconstructor bar6-test2 bar6 () :a 1 :b 2 :c 3)
  (defconstructor bar6-test3 bar6 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (bar6-test1) 'a '1 'b '5 'c '3)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar6-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar6-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar7
;;; [methods, default/initform, slot-filling]
;;; (:after,  :constant,        :instance)

(defclass bar7 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class :initform 3))
  (:default-initargs :b 5))

(defmethod *initialize-instance :after ((instance bar7) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  :constant,        :instance) (1)"
         ((:functions bar7-test1 bar7-test2 bar7-test3))

  (defconstructor bar7-test1 bar7 ())
  (defconstructor bar7-test2 bar7 () :a 1 :b 2)
  (defconstructor bar7-test3 bar7 (a b) :a a :b b)
  
  (dotimes (i 2)
    (unless (check-slots (bar7-test1) 'a '1 'b '5 'c '3)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar7-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar7-test3 7 8) 'a '7 'b '8 'c '3)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar8
;;; [methods, default/initform, slot-filling]
;;; (:after,  :constant,        :instance)

(defclass bar8 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class))
  (:default-initargs :b 5))

(defmethod *initialize-instance :after ((instance bar8) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  :constant,        :instance) (2)"
         ((:functions bar8-test1 bar8-test2 bar8-test3))

  (defconstructor bar8-test1 bar8 ())
  (defconstructor bar8-test2 bar8 () :a 1 :b 2)
  (defconstructor bar8-test3 bar8 (a b) :a a :b b)

  (dotimes (i 2)
    (unless (check-slots (bar8-test1) 'a '1 'b '5 'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar8-test2) 'a '1 'b '2 'c :unbound)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar8-test3 7 8) 'a '7 'b '8 'c :unbound)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar9
;;; [methods, default/initform, slot-filling]
;;; (nil,     :constant,        :class)

(defclass bar9 ()
    ((a :initarg :a :initform 1)
     (b :initarg :b :initform 2)
     (c :initarg :c :allocation :class :initform 3))
  (:default-initargs :b 5 :c 6))

(do-test "defconstructor (nil,     :constant,        :class) (1)"
         ((:functions bar9-test1 bar9-test2 bar9-test3))

  (defconstructor bar9-test1 bar9 ())
  (defconstructor bar9-test2 bar9 () :a 1 :b 2 :c 3)
  (defconstructor bar9-test3 bar9 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (bar9-test1) 'a '1 'b '5 'c '6)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar9-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar9-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar10
;;; [methods, default/initform, slot-filling]
;;; (nil,     :constant,        :class)

(defclass bar10 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class :initform 3 :initarg :c))
  (:default-initargs :b 5))

(do-test "defconstructor (nil,     :constant,        :class) (2)"
         ((:functions bar10-test1 bar10-test2 bar10-test3))

  (defconstructor bar10-test1 bar10 ())
  (defconstructor bar10-test2 bar10 () :a 1 :b 2 :c 3)
  (defconstructor bar10-test3 bar10 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (bar10-test1) 'a '1 'b '5 'c '3)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar10-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar10-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar11
;;; [methods, default/initform, slot-filling]
;;; (nil,     :constant,        :instance)

(defclass bar11 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class :initform 3))
  (:default-initargs :b 5))

(do-test "defconstructor (nil,     :constant,        :instance) (1)"
         ((:functions bar11-test1 bar11-test2 bar11-test3))

  (defconstructor bar11-test1 bar11 ())
  (defconstructor bar11-test2 bar11 () :a 1 :b 2)
  (defconstructor bar11-test3 bar11 (a b) :a a :b b)
  
  (dotimes (i 2)
    (unless (check-slots (bar11-test1) 'a '1 'b '5 'c '3)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar11-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar11-test3 7 8) 'a '7 'b '8 'c '3)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; bar12
;;; [methods, default/initform, slot-filling]
;;; (nil,     :constant,        :instance)

(defclass bar12 ()
    ((a :initform 1 :initarg :a)
     (b :initform 2 :initarg :b)
     (c :allocation :class))
  (:default-initargs :b 5))

(defmethod *initialize-instance :after ((instance bar12) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (nil,     :constant,        :instance) (2)"
         ((:functions bar12-test1 bar12-test2 bar12-test3))

  (defconstructor bar12-test1 bar12 ())
  (defconstructor bar12-test2 bar12 () :a 1 :b 2)
  (defconstructor bar12-test3 bar12 (a b) :a a :b b)

  (dotimes (i 2)
    (unless (check-slots (bar12-test1) 'a '1 'b '5 'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar12-test2) 'a '1 'b '2 'c :unbound)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (bar12-test3 7 8) 'a '7 'b '8 'c :unbound)
      (do-test-error nil "non constant initargs failed (~D time)" i))))


(cleanup-do-test '((:classes baz1 baz2 baz3)
                   (:functions baz1-test1 baz1-test2 baz1-test3
                               baz2-test1 baz2-test2 baz2-test3
                               baz3-test1 baz3-test2 baz3-test3)))

;;;
;;; baz1
;;; [methods, default/initform, slot-filling]
;;; (t,       nil,              :class)

(defclass baz1 ()
    ((a :initarg :a)
     (b :initarg :b)
     (c :initarg :c :allocation :class)))

(defmethod *initialize-instance :before ((instance baz1) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (t,       nil,              :class) (1)"
         ((:functions baz1-test1 baz1-test2 baz1-test3))

  (defconstructor baz1-test1 baz1 ())
  (defconstructor baz1-test2 baz1 () :a 1 :b 2 :c 3)
  (defconstructor baz1-test3 baz1 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (baz1-test1) 'a :unbound 'b :unbound 'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (baz1-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (baz1-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; baz2
;;; [methods, default/initform, slot-filling]
;;; (:after,  nil,              :class)

(defclass baz2 ()
    ((a :initarg :a)
     (b :initarg :b)
     (c :initarg :c :allocation :class)))

(defmethod *initialize-instance :after ((instance baz2) &rest ignore)
  (declare (ignore ignore))
  ())

(do-test "defconstructor (:after,  nil,              :class) (1)"
         ((:functions baz2-test1 baz2-test2 baz2-test3))

  (defconstructor baz2-test1 baz2 ())
  (defconstructor baz2-test2 baz2 () :a 1 :b 2 :c 3)
  (defconstructor baz2-test3 baz2 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (baz2-test1) 'a :unbound 'b :unbound 'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (baz2-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (baz2-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))

;;;
;;; baz3
;;; [methods, default/initform, slot-filling]
;;; (nil,     nil,              :class)

(defclass baz3 ()
    ((a :initarg :a)
     (b :initarg :b)
     (c :initarg :c :allocation :class)))

(do-test "defconstructor (nil,     nil,              :class) (1)"
         ((:functions baz3-test1 baz3-test2 baz3-test3))

  (defconstructor baz3-test1 baz3 ())
  (defconstructor baz3-test2 baz3 () :a 1 :b 2 :c 3)
  (defconstructor baz3-test3 baz3 (a b c) :a a
                                          :b b
                                          :c c)
  
  (dotimes (i 2)
    (unless (check-slots (baz3-test1) 'a :unbound 'b :unbound 'c :unbound)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (baz3-test2) 'a '1 'b '2 'c '3)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (baz3-test3 7 8 9) 'a '7 'b '8 'c '9)
      (do-test-error nil "non constant initargs failed (~D time)" i))))


(cleanup-do-test '((:classes foo bar)
                   (:functions make-bar-1 make-bar-2 make-bar-3)))

(setq *foo-a* 'foo-a
      *foo-b* 'foo-b
      *foo-c* 'foo-c
      *bar-a* 'bar-a
      *bar-b* 'bar-b
      *bar-c* 'bar-c
      *supplied-a* 'a
      *supplied-b* 'b
      *supplied-c* 'c)

(defclass foo ()
    ((a :initarg :a)
     (b :initarg :b)
     (c :initarg :c))
  (:default-initargs :a *foo-a* :b *foo-b* :c *foo-c*))

(defclass bar (foo)
    ((c :initarg :a))
  (:default-initargs :a *bar-a* :c *bar-c*))

(defconstructor make-bar-1 bar ())
(defconstructor make-bar-2 bar () :a 1 :b 2 :c 3)
(defconstructor make-bar-3 bar (a b c) :a a :b b :c c)

(do-test "defconstructor/shadowing"
         ()

  (dotimes (i 2)
    (unless (check-slots (make-bar-1) 'a *bar-a* 'b *foo-b* 'c *bar-a*)
      (do-test-error nil "no initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (make-bar-2) 'a '1 'b '2 'c '1)
      (do-test-error nil "constant initargs failed (~D time)" i)))

  (dotimes (i 2)
    (unless (check-slots (make-bar-3 *supplied-a* *supplied-b* *supplied-c*)
                         'a  *supplied-a* 'b *supplied-b* 'c *supplied-a*)
      (do-test-error nil "non constant initargs failed (~D time)" i))))


(do-test "defconstructor/only needed forms should be evaluated"
         ((:classes foo)
          (:functions make-foo-1 make-foo-2))

  (defclass foo ()
      ((x :initform (do-test-error nil "foo x initform was evaluated")
          :initarg :x)
       (y :initform (do-test-error nil "foo y initform was evaluated")
          :initarg :y)
       (z :initform (do-test-error nil "foo z initform was evaluated")
          :initarg :z))
    (:default-initargs :y 2
                       :z (do-test-error
                            nil
                            "z default was evaluated")))

  (defconstructor make-foo-1 foo () :x 1 :z 3)
  (defconstructor make-foo-2 foo (x z) :x x :z z)

  (make-foo-1)
  (make-foo-1)
  (make-foo-2 'x 'z)
  (make-foo-2 'x 'z))

(do-test "defconstructor/shadowing/only needed forms should be evaluated"
         ((:classes foo bar)
          (:functions make-bar-4 make-bar-5))

  (defclass foo ()
      ((x :initform (do-test-error nil "foo x initform was evaluated")
          :initarg :x)
       (y :initform (do-test-error nil "foo y initform was evaluated")
          :initarg :y)
       (z :initform (do-test-error nil "foo z initform was evaluated")
          :initarg :z))
    (:default-initargs :x (do-test-error
                            nil
                            "foo z default was evaluated")
                       :y (do-test-error
                            nil
                            "foo y default was evaluated")
                       :z (do-test-error
                            nil
                            "foo z default was evaluated")))
  (defclass bar (foo)
      ((x :initform (do-test-error nil "bar x initform was evaluated"))
       (y :initform (do-test-error nil "bar y initform was evaluated"))
       (z :initform (do-test-error nil "bar z initform was evaluated")))
    (:default-initargs :y 2
                       :z (do-test-error
                            nil
                            "bar z default was evaluated")))

  (defconstructor make-bar-4 bar () :x 1 :z 3)
  (defconstructor make-bar-5 bar (x z) :x x :z z)

  (make-bar-4)
  (make-bar-4)
  (make-bar-5 'x 'z)
  (make-bar-5 'x 'z))

;;;
;;; 11/1 test to make sure reader/writer call slot-value-using-class
;;;
;;; **********************************************************************
;;; This test codes will have to change in each of the next releases
;;; **********************************************************************
;;;
(cleanup-do-test '((:classes test-deoptimized-slot-access-class
                             test-deoptimized-slot-access)
                   (:functions test-a test-b test-c)
                   (:setf-generic-functions test-a test-b)))

(defclass test-deoptimized-slot-access-class (standard-class) ())

(defmethod check-super-metaclass-compatibility
    ((x test-deoptimized-slot-access-class) (y standard-class))
  't)

(defmethod all-std-class-reader-miss-1
    ((class test-deoptimized-slot-access-class) wrapper slot-name)
  (declare (ignore wrapper slot-name))
  ())

(defmethod lookup-pv-miss-1
    ((class test-deoptimized-slot-access-class) slots pv)
  (let ((pv (call-next-method)))
    (make-list (length pv) :initial-element nil)))


(defclass test-deoptimized-slot-access ()
    ((a :initform 'a :accessor test-a)
     (b :initform 'b :accessor test-b))
  (:metaclass test-deoptimized-slot-access-class))

(defmethod test-c ((o test-deoptimized-slot-access))
  (list (slot-value o 'a) (slot-value o 'b)))

(let ((called-p 'nil)
      instance)
  (defmethod slot-value-using-class ((class test-deoptimized-slot-access-class)
                                     object
                                     slot-name)
    (setq called-p 'read)
    (call-next-method))

  (defmethod (setf slot-value-using-class)
      (nv (class test-deoptimized-slot-access-class) object slot-name)
    (setq called-p 'written)
    (call-next-method))

  (setq instance (make-instance 'test-deoptimized-slot-access))
  
  (do-test "deoptimized slot access should call slot-value-using-class"
        ()
    (unless (and (eq (test-a instance) 'a)
                 (eq called-p 'read))
      (do-test-error nil "reader doesn't call slot-value-using-class"))

    (setq called-p 'nil)
    (setf (test-b instance) 'c)
    (unless (eq called-p 'written)
      (do-test-error nil "writer doesn't call slot-value-using-class"))

    (setq called-p 'nil)
    (unless (and (equal (test-c instance) '(a c))
                 (eq called-p 'read))
      (do-test-error nil "slot-value doesn't call slot-value-using-class"))))

;;;
;;; 5/3/89 eql specializers tests
;;; 

(cleanup-do-test '((:classes foo bar)))
(defclass foo () ())
(defclass bar (foo) ())

(do-test "eql specializers(eql and other methods/symbol only)"
         ((:functions test)
          (:variables i))

  (defmethod test ((self foo) x) 'foo)
  (defmethod test ((self bar) (x (eql 'a))) 'a)
  (defmethod test ((self bar) (x (eql 'b))) 'b)
  (setq i (make-instance 'bar))

  (unless (eq (test i 'a) 'a)
    (do-test-error () "for (bar (eql a)) wrong method was called"))
  (unless (eq (test i 'b) 'b)
    (do-test-error () "for (bar (eql b)) wrong method was called"))
  (unless (eq (test i 'c) 'foo)
    (do-test-error () "for (bar (eql c)) wrong method was called"))
  )

(do-test "eql specializers(only eql methods/symbol only)"
         ((:functions test2)
          (:variables i))

  (defmethod test2 ((self bar) (x (eql 'a))) 'a)
  (defmethod test2 ((self bar) (x (eql 'b))) 'b)
  (setq i (make-instance 'bar))

  (unless (eq (test2 i 'a) 'a)
    (do-test-error () "for (bar (eql a)) wrong method was called"))
  (unless (eq (test2 i 'b) 'b)
    (do-test-error () "for (bar (eql b)) wrong method was called"))
  )

(do-test "eql specializers(only eql methods/symbol and integer)"
         ((:functions test3))

  (defmethod test3 ((x (eql 'a)) (y (eql '1))) 'a-1)
  (defmethod test3 ((x (eql 'b)) (y (eql '1))) 'b-1)
  (defmethod test3 ((x (eql 'c)) (y (eql '1))) 'c-1)
  (defmethod test3 ((x (eql 'a)) (y (eql '2))) 'a-2)
  (defmethod test3 ((x (eql 'b)) (y (eql '2))) 'b-2)
  (defmethod test3 ((x (eql 'c)) (y (eql '2))) 'c-2)
  (defmethod test3 ((x (eql 'a)) (y (eql '3))) 'a-3)
  (defmethod test3 ((x (eql 'b)) (y (eql '3))) 'b-3)
  (defmethod test3 ((x (eql 'c)) (y (eql '3))) 'c-3)
  
  (unless (eq (test3 'a '1) 'a-1)
    (do-test-error () "for (a 1) wrong method was called"))
  (unless (eq (test3 'a '2) 'a-2)
    (do-test-error () "for (a 2) wrong method was called"))
  (unless (eq (test3 'a '3) 'a-3)
    (do-test-error () "for (a 3) wrong method was called"))
  (unless (eq (test3 'b '1) 'b-1)
    (do-test-error () "for (b 1) wrong method was called"))
  (unless (eq (test3 'b '2) 'b-2)
    (do-test-error () "for (b 2) wrong method was called"))
  (unless (eq (test3 'b '3) 'b-3)
    (do-test-error () "for (b 3) wrong method was called"))
  (unless (eq (test3 'c '1) 'c-1)
    (do-test-error () "for (c 1) wrong method was called"))
  (unless (eq (test3 'c '2) 'c-2)
    (do-test-error () "for (c 2) wrong method was called"))
  (unless (eq (test3 'c '3) 'c-3)
    (do-test-error () "for (c 3) wrong method was called"))

  )

(do-test "eql specializers(eql and other methods/symbol and integer)"
         ((:functions test4))

  (defmethod test4 ((x (eql 'a)) (y (eql '1))) 'a-1)
  (defmethod test4 ((x (eql 'b)) (y (eql '1))) 'b-1)
  (defmethod test4 ((x (eql 'c)) (y (eql '2))) 'c-2)
  (defmethod test4 ((x (eql 'b)) (y (eql '3))) 'b-3)
  (defmethod test4 (x y) 'other)
  
  (unless (eq (test4 'a '1) 'a-1)
    (do-test-error () "for (a 1) wrong method was called"))
  (unless (eq (test4 'a '2) 'other)
    (do-test-error () "for (a 2) wrong method was called"))
  (unless (eq (test4 'a '3) 'other)
    (do-test-error () "for (a 3) wrong method was called"))
  (unless (eq (test4 'b '1) 'b-1)
    (do-test-error () "for (b 1) wrong method was called"))
  (unless (eq (test4 'b '2) 'other)
    (do-test-error () "for (b 2) wrong method was called"))
  (unless (eq (test4 'b '3) 'b-3)
    (do-test-error () "for (b 3) wrong method was called"))
  (unless (eq (test4 'c '1) 'other)
    (do-test-error () "for (c 1) wrong method was called"))
  (unless (eq (test4 'c '2) 'c-2)
    (do-test-error () "for (c 2) wrong method was called"))
  (unless (eq (test4 'c '3) 'other)
    (do-test-error () "for (c 3) wrong method was called"))

  )

(do-test "eql specializers(call-next-method)"
         ((:functions test5))

  (defmethod test5 (x) ())
  (defmethod test5 ((x (eql 'a))) (cons 'a (call-next-method)))
  (defmethod test5 ((x (eql 'b))) (cons 'b (call-next-method)))

  (unless (equal (test5 'a) '(a))
    (do-test-error () "for (a) wrong method was called"))
  (unless (equal (test5 'b) '(b))
    (do-test-error () "for (b) wrong method was called"))
  (unless (eq (test5 'c) '())
    (do-test-error () "for (c) wrong method was called"))
  )

(do-test "eql specializers(for random types)"
         ((:functions test6))

  (defmethod test6 (x) ())
  (defmethod test6 ((x symbol))  (cons 'the-class-symbol  (call-next-method)))
  (defmethod test6 ((x null))    (cons 'the-class-null    (call-next-method)))
  (defmethod test6 ((x number))  (cons 'the-class-number  (call-next-method)))
  (defmethod test6 ((x integer)) (cons 'the-class-integer (call-next-method)))
  (defmethod test6 ((x (eql 'foo))) (cons 'foo (call-next-method)))
  (defmethod test6 ((x (eql 'bar))) (cons 'bar (call-next-method)))
  (defmethod test6 ((x (eql 'nil))) (cons 'nil (call-next-method)))
  (defmethod test6 ((x (eql '1.7))) (cons '1.7 (call-next-method)))
  (defmethod test6 ((x (eql '321))) (cons '321 (call-next-method)))

  (unless (eq (test6 '(other)) ())
    (do-test-error () "for ((other)) wrong method was called"))
  (unless (equal (test6 'symbol) '(the-class-symbol))
    (do-test-error () "for (symbol) wrong method was called"))
  (unless (equal (test6 '5.5) '(the-class-number))
    (do-test-error () "for (number) wrong method was called"))
  (unless (equal (test6 '123) '(the-class-integer the-class-number))
    (do-test-error () "for (integer) wrong method was called"))
  (unless (equal (test6 'foo) '(foo the-class-symbol))
    (do-test-error () "for ((eql foo)) wrong method was called"))
  (unless (equal (test6 'bar) '(bar the-class-symbol))
    (do-test-error () "for ((eql bar)) wrong method was called"))
  (unless (equal (test6 'nil) '(nil the-class-null the-class-symbol))
    (do-test-error () "for ((eql nil)) wrong method was called"))
  (unless (equal (test6 '1.7) '(1.7 the-class-number))
    (do-test-error () "for ((eql 1.7)) wrong method was called"))
  (unless (equal (test6 '321) '(321 the-class-integer the-class-number))
    (do-test-error () "for ((eql 321)) wrong method was called"))
  )

;;;
;;; (5/3/89)Testing :allocation :class for funcallable-instance
;;;

(format t "~%Testing :allocation :class test(for standard-instance)~%")
         
(cleanup-do-test '((:classes foo bar)
                   (:variables foo1 bar1)))

(defclass foo ()
    ((a :initform (list 'foo-a) :allocation :class)
     (b :initform (list 'foo-b) :allocation :class)
     (c :initform (list 'foo-c) :allocation :class)
     (d :allocation :class)
     (e :allocation :class)
     (f :allocation :class)))

(defclass bar (foo)
    ((b :initform (list 'bar-b) :allocation :class)
     (c :allocation :class)
     (e :initform (list 'bar-e) :allocation :class)
     (f :allocation :class)))

(defmethod slot-missing ((class standard-class)
                         (instance foo)
                         slot-name operation &optional new-value)
  (list* class instance slot-name operation new-value))

(defmethod slot-missing ((class standard-class)
                         (instance bar)
                         slot-name operation &optional new-value)
  (list* class instance slot-name operation new-value))

(defmethod slot-unbound ((class standard-class)
                         (instance foo)
                         slot-name)
  (list class instance slot-name))

(defmethod slot-unbound ((class standard-class)
                         (instance bar)
                         slot-name)
  (list class instance slot-name))

(setq foo1 (make-instance 'foo)
      bar1 (make-instance 'bar))

(do-test ":allocation :class(:initform/slot-value)"
  ()
  (unless (and (equal (slot-value foo1 'a) '(foo-a))
               (equal (slot-value foo1 'b) '(foo-b))
               (equal (slot-value foo1 'c) '(foo-c))
               (equal (slot-value bar1 'a) '(foo-a))
               (equal (slot-value bar1 'b) '(bar-b))
               (equal (slot-value bar1 'c) '(foo-c))
               (equal (slot-value bar1 'e) '(bar-e)))
    (do-test-error () ":initform/slot-value failed")))

(do-test ":allocation :class(shared by instances of super and sub case)"
  ()
  (unless (eq (slot-value foo1 'a)
              (slot-value bar1 'a))
    (do-test-error () ":class slot should be shared by instances")))

(do-test ":allocation :class(not shared by instances of super and sub case)"
  ()
  (unless (not (eq (slot-value foo1 'c)
                   (slot-value bar1 'c)))
    (do-test-error () ":class slot should not be shared by instances")))

(do-test ":allocation :class(slot-boundp)"
  ()
  (unless (and (slot-boundp foo1 'a)
               (slot-boundp foo1 'b)
               (slot-boundp foo1 'c)
               (not (slot-boundp foo1 'd))
               (not (slot-boundp foo1 'e))
               (not (slot-boundp foo1 'f))
               (slot-boundp bar1 'a)
               (slot-boundp bar1 'b)
               (slot-boundp bar1 'c)
               (not (slot-boundp bar1 'd))
               (slot-boundp bar1 'e)
               (not (slot-boundp bar1 'f)))
    (do-test-error () "slot-boundp failed")))

(slot-makunbound foo1 'a)
(slot-makunbound foo1 'b)

(do-test ":allocation :class(slot-makunbound)"
  ()
  (unless (and (not (slot-boundp foo1 'a))
               (not (slot-boundp foo1 'b))
               (not (slot-boundp bar1 'a))
               (slot-boundp bar1 'b))
    (do-test-error () "slot-makunbound failed")))

(setf (slot-value foo1 'a) '(new-foo-a)
      (slot-value foo1 'b) '(new-foo-b)
      (slot-value foo1 'c) '(new-foo-c)
      (slot-value bar1 'b) '(new-bar-b)
      (slot-value bar1 'e) '(new-bar-e))

(do-test ":allocation :class(slot-value/(setf slot-value))"
  ()
  (unless (and (equal (slot-value foo1 'a) '(new-foo-a))
               (equal (slot-value foo1 'b) '(new-foo-b))
               (equal (slot-value foo1 'c) '(new-foo-c))
               (equal (slot-value bar1 'a) '(new-foo-a))
               (equal (slot-value bar1 'b) '(new-bar-b))
               (equal (slot-value bar1 'e) '(new-bar-e)))
    (do-test-error () "slot-value/(setf slot-value failed")))

(do-test ":allocation :class(slot-exists-p)"
  ()
  (unless (and (slot-exists-p foo1 'a)
               (slot-exists-p foo1 'b)
               (slot-exists-p foo1 'c)
               (slot-exists-p foo1 'd)
               (slot-exists-p foo1 'e)
               (slot-exists-p foo1 'f)
               (slot-exists-p bar1 'a)
               (slot-exists-p bar1 'b)
               (slot-exists-p bar1 'c)
               (slot-exists-p bar1 'd)
               (slot-exists-p bar1 'e)
               (slot-exists-p bar1 'f))
    (do-test-error () "slot-exist-p failed")))

(do-test ":allocation :class(slot-missing)"
  ()
  (unless (and (equal (slot-value foo1 'x)
                      (list (class-of foo1)
                            foo1
                            'x
                            'slot-value))
               (equal (setf (slot-value foo1 'x) 'dummy)
                      (list* (class-of foo1)
                             foo1
                             'x
                             'setf
                             'dummy))
               (equal (slot-boundp foo1 'x)
                      (list (class-of foo1)
                            foo1
                            'x
                            'slot-boundp))
               
               (equal (slot-makunbound foo1 'x)
                      (list (class-of foo1)
                            foo1
                            'x
                            'slot-makunbound))
               (equal (slot-value bar1 'x)
                      (list (class-of bar1)
                            bar1
                            'x
                            'slot-value))
               (equal (setf (slot-value bar1 'x) 'dummy)
                      (list* (class-of bar1)
                             bar1
                             'x
                             'setf
                             'dummy))
               (equal (slot-boundp bar1 'x)
                      (list (class-of bar1)
                            bar1
                            'x
                            'slot-boundp))
               
               (equal (slot-makunbound bar1 'x)
                      (list (class-of bar1)
                            bar1
                            'x
                            'slot-makunbound)))
    (do-test-error () "slot-missing failed")))

;;;
;;; (5/4/89)Testing :allocation :class for funcallable-instance
;;;

(format t "~%Testing :allocation :class test~
           (for funcallable-standard-instance)~%")
         
(cleanup-do-test '((:classes foo bar)
                   (:variables foo2 bar2)))

(defclass foo ()
    ((a :initform (list 'foo-a) :allocation :class)
     (b :initform (list 'foo-b) :allocation :class)
     (c :initform (list 'foo-c) :allocation :class)
     (d :allocation :class)
     (e :allocation :class)
     (f :allocation :class))
  (:metaclass funcallable-standard-class))

(defclass bar (foo)
    ((b :initform (list 'bar-b) :allocation :class)
     (c :allocation :class)
     (e :initform (list 'bar-e) :allocation :class)
     (f :allocation :class))
  (:metaclass funcallable-standard-class))

(defmethod slot-missing ((class standard-class)
                         (instance foo)
                         slot-name operation &optional new-value)
  (list* class instance slot-name operation new-value))

(defmethod slot-missing ((class standard-class)
                         (instance bar)
                         slot-name operation &optional new-value)
  (list* class instance slot-name operation new-value))

(defmethod slot-unbound ((class standard-class)
                         (instance foo)
                         slot-name)
  (list class instance slot-name))

(defmethod slot-unbound ((class standard-class)
                         (instance bar)
                         slot-name)
  (list class instance slot-name))

(setq foo2 (make-instance 'foo)
      bar2 (make-instance 'bar))

(do-test ":allocation :class(:initform/slot-value)"
  ()
  (unless (and (equal (slot-value foo2 'a) '(foo-a))
               (equal (slot-value foo2 'b) '(foo-b))
               (equal (slot-value foo2 'c) '(foo-c))
               (equal (slot-value bar2 'a) '(foo-a))
               (equal (slot-value bar2 'b) '(bar-b))
               (equal (slot-value bar2 'c) '(foo-c))
               (equal (slot-value bar2 'e) '(bar-e)))
    (do-test-error () ":initform/slot-value failed")))

(do-test ":allocation :class(shared by instances of super and sub case)"
  ()
  (unless (eq (slot-value foo2 'a)
              (slot-value bar2 'a))
    (do-test-error () ":class slot should be shared by instances")))

(do-test ":allocation :class(not shared by instances of super and sub case)"
  ()
  (unless (not (eq (slot-value foo2 'c)
                   (slot-value bar2 'c)))
    (do-test-error () ":class slot should not be shared by instances")))

(do-test ":allocation :class(slot-boundp)"
  ()
  (unless (and (slot-boundp foo2 'a)
               (slot-boundp foo2 'b)
               (slot-boundp foo2 'c)
               (not (slot-boundp foo2 'd))
               (not (slot-boundp foo2 'e))
               (not (slot-boundp foo2 'f))
               (slot-boundp bar2 'a)
               (slot-boundp bar2 'b)
               (slot-boundp bar2 'c)
               (not (slot-boundp bar2 'd))
               (slot-boundp bar2 'e)
               (not (slot-boundp bar2 'f)))
    (do-test-error () "slot-boundp failed")))

(slot-makunbound foo2 'a)
(slot-makunbound foo2 'b)

(do-test ":allocation :class(slot-makunbound)"
  ()
  (unless (and (not (slot-boundp foo2 'a))
               (not (slot-boundp foo2 'b))
               (not (slot-boundp bar2 'a))
               (slot-boundp bar2 'b))
    (do-test-error () "slot-makunbound failed")))

(setf (slot-value foo2 'a) '(new-foo-a)
      (slot-value foo2 'b) '(new-foo-b)
      (slot-value foo2 'c) '(new-foo-c)
      (slot-value bar2 'b) '(new-bar-b)
      (slot-value bar2 'e) '(new-bar-e))

(do-test ":allocation :class(slot-value/(setf slot-value))"
  ()
  (unless (and (equal (slot-value foo2 'a) '(new-foo-a))
               (equal (slot-value foo2 'b) '(new-foo-b))
               (equal (slot-value foo2 'c) '(new-foo-c))
               (equal (slot-value bar2 'a) '(new-foo-a))
               (equal (slot-value bar2 'b) '(new-bar-b))
               (equal (slot-value bar2 'e) '(new-bar-e)))
    (do-test-error () "slot-value/(setf slot-value failed")))

(do-test ":allocation :class(slot-exists-p)"
  ()
  (unless (and (slot-exists-p foo2 'a)
               (slot-exists-p foo2 'b)
               (slot-exists-p foo2 'c)
               (slot-exists-p foo2 'd)
               (slot-exists-p foo2 'e)
               (slot-exists-p foo2 'f)
               (slot-exists-p bar2 'a)
               (slot-exists-p bar2 'b)
               (slot-exists-p bar2 'c)
               (slot-exists-p bar2 'd)
               (slot-exists-p bar2 'e)
               (slot-exists-p bar2 'f))
    (do-test-error () "slot-exist-p failed")))

;(do-test ":allocation :class(slot-missing)"
;  ()
;  (unless (and (equal (slot-value foo2 'x)
;                      (list (class-of foo2)
;                            foo2
;                              'x
;                            'slot-value))
;               (equal (setf (slot-value foo2 'x) 'dummy)
;                      (list* (class-of foo2)
;                             foo2
;                             'x
 ;                            'setf
;                             'dummy))
;               (equal (slot-boundp foo2 'x)
;                      (list (class-of foo2)
;                            foo2
;                            'x
;                            'slot-boundp))
;               
;               (equal (slot-makunbound foo2 'x)
;                      (list (class-of foo2)
;                            foo2
;                            'x
;                            'slot-makunbound))
;               (equal (slot-value bar2 'x)
;                      (list (class-of bar2)
;                            bar2
;                            'x
;                            'slot-value))
;               (equal (setf (slot-value bar2 'x) 'dummy)
;                      (list* (class-of bar2)
;                             bar2
;                             'x
;                             'setf
;                             'dummy))
;               (equal (slot-boundp bar2 'x)
;                      (list (class-of bar2)
;                            bar2
;                            'x
;                            'slot-boundp))
;               
;               (equal (slot-makunbound bar2 'x)
;                      (list (class-of bar2)
;                            bar2
;                            'x
;                            'slot-makunbound)))
;    (do-test-error () "slot-missing failed")))



