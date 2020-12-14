;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-

;;;. Copyright (c) 1991 by Venue

(in-package "CLOS")



;;; GET-FUNCTION is the main user interface to this code.  If it is called with a lambda expression
;;; only, it will return a corresponding function. The optional constant-converter argument, can be
;;; a function which will be called to convert each constant appearing in the lambda to whatever
;;; value should appear in the function. Whether the returned function is actually compiled depends
;;; on whether the compiler is present (see COMPILE-LAMBDA) and whether this shape of code was
;;; precompiled. 


(defun get-function (lambda &optional (test-converter #'default-test-converter)
                           (code-converter #'default-code-converter)
                           (constant-converter #'default-constant-converter))
       (apply (get-function-generator lambda test-converter code-converter)
              (compute-constants lambda constant-converter)))

(defun default-test-converter (form)
       (if (not (constantp form))
           form
           '.constant.))

(defun default-code-converter (form)
       (if (not (constantp form))
           form
           (let ((gensym (gensym)))
                (values gensym (list gensym)))))

(defun default-constant-converter (form)
       (and (constantp form)
            (list (if (and (consp form)
                           (eq (car form)
                               'quote))
                                                             ; This had better
                      (cadr form)
                                                             ; do the same as
                      form))))

                                                             ; EVAL would have.



;;; *fgens* is a list of all the function generators we have so far.  Each element is a FGEN
;;; structure as implemented below.  Don't ever touch this list by hand, use STORE-FGEN. 


(defvar *fgens* nil)

(defun store-fgen (fgen)
       (setq *fgens* (nconc *fgens* (list fgen))))

(defun lookup-fgen (test)
       (find test (the list *fgens*)
             :key
             #'fgen-test :test #'equal))

(defun make-fgen (test gensyms generator generator-lambda system)
       (let ((new (make-array 6)))
            (setf (svref new 0)
                  test
                  (svref new 1)
                  gensyms
                  (svref new 2)
                  generator
                  (svref new 3)
                  generator-lambda
                  (svref new 4)
                  system)
            new))

(defun fgen-test (fgen)
       (svref fgen 0))

(defun fgen-gensyms (fgen)
       (svref fgen 1))

(defun fgen-generator (fgen)
       (svref fgen 2))

(defun fgen-generator-lambda (fgen)
       (svref fgen 3))

(defun fgen-system (fgen)
       (svref fgen 4))

(defun get-function-generator (lambda test-converter code-converter)
       (let* ((test (compute-test lambda test-converter))
              (fgen (lookup-fgen test)))
             (if fgen
                 (fgen-generator fgen)
                 (get-new-function-generator lambda test code-converter))))

(defun get-new-function-generator (lambda test code-converter)
       (multiple-value-bind (gensyms generator-lambda)
              (get-new-function-generator-internal lambda code-converter)
              (let* ((generator (compile-lambda generator-lambda))
                     (fgen (make-fgen test gensyms generator generator-lambda nil)))
                    (store-fgen fgen)
                    generator)))

(defun get-new-function-generator-internal (lambda code-converter)
       (multiple-value-bind (code gensyms)
              (compute-code lambda code-converter)
              (values gensyms `(lambda ,gensyms #',code))))

(defun compute-test (lambda test-converter)
       (walk-form lambda nil #'(lambda (f c e)
                                      (declare (ignore e))
                                      (if (neq c :eval)
                                          f
                                          (let ((converted (funcall test-converter f)))
                                               (values converted (neq converted f)))))))

(defun compute-code (lambda code-converter)
       (let ((gensyms nil))
            (values (walk-form lambda nil #'(lambda (f c e)
                                                   (declare (ignore e))
                                                   (if (neq c :eval)
                                                       f
                                                       (multiple-value-bind
                                                        (converted gens)
                                                        (funcall code-converter f)
                                                        (when gens
                                                            (setq gensyms (append gensyms gens)))
                                                        (values converted (neq converted f))))))
                   gensyms)))

(defun compute-constants (lambda constant-converter)
       (macrolet ((appending nil `(let ((result nil))
                                       (values #'(lambda (value)
                                                        (setq result (append result value)))
                                              #'(lambda nil result)))))
              (gathering1 (appending)
                     (walk-form lambda nil #'(lambda (f c e)
                                                    (declare (ignore e))
                                                    (if (neq c :eval)
                                                        f
                                                        (let ((consts (funcall constant-converter f))
                                                              )
                                                             (if consts
                                                                 (progn (gather1 consts)
                                                                        (values f t))
                                                                 f))))))))


;;; 


(defmacro
 precompile-function-generators
 (&optional system)
 (make-top-level-form
  `(precompile-function-generators ,system)
  '(load)
  `(progn ,@(gathering1 (collecting)
                   (dolist (fgen *fgens*)
                       (when (or (null (fgen-system fgen))
                                 (eq (fgen-system fgen)
                                     system))
                           (gather1 `(load-function-generator ',(fgen-test fgen)
                                            ',(fgen-gensyms fgen)
                                            #',(fgen-generator-lambda fgen)
                                            ',(fgen-generator-lambda fgen)
                                            ',system))))))))

(defun load-function-generator (test gensyms generator generator-lambda system)
       (store-fgen (make-fgen test gensyms generator generator-lambda system)))
