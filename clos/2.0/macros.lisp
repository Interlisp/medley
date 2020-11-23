;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;; File converted on 26-Mar-91 10:27:21 from source macros
;;;. Original source {dsk}<usr>local>users>welch>lisp>clos>rev4>il-format>macros.;3 created 19-Feb-91 13:51:21

;;;. Copyright (c) 1991 Venue



(in-package "CLOS")


;;;Macros global variable
;;; definitions, and other random support stuff used by the rest of the system. For simplicity (not
;;; having to use eval-when a lot), this file must be loaded before it can be compiled. 


(in-package 'clos)

(proclaim '(declaration values arglist indentation class variable-rebinding clos-fast-call))


;;; Age old functions which CommonLisp cleaned-up away.  They probably exist in other packages in
;;; all CommonLisp implementations, but I will leave it to the compiler to optimize into calls to
;;; them. Common Lisp BUG: Some Common Lisps define these in the Lisp package which causes all sorts
;;; of lossage.  Common Lisp should explictly specify which symbols appear in the Lisp package. 


(eval-when (compile load eval)
       (defmacro memq (item list)
              `(member ,item ,list :test #'eq))
       (defmacro assq (item list)
              `(assoc ,item ,list :test #'eq))
       (defmacro rassq (item list)
              `(rassoc ,item ,list :test #'eq))
       (defmacro delq (item list)
              `(delete ,item ,list :test #'eq))
       (defmacro posq (item list)
              `(position ,item ,list :test #'eq))
       (defmacro neq (x y)
              `(not (eq ,x ,y)))
       (defun make-caxr (n form)
              (if (< n 4)
                  `(,(nth n '(car cadr caddr cadddr))
                    ,form)
                  (make-caxr (- n 4)
                         `(cddddr ,form))))
       (defun make-cdxr (n form)
              (cond ((zerop n)
                     form)
                    ((< n 5)
                     `(,(nth n '(identity cdr cddr cdddr cddddr))
                       ,form))
                    (t (make-cdxr (- n 4)
                              `(cddddr ,form))))))

(defun zero (&rest ignore)
       (declare (ignore ignore))
       0)

(defun make-plist (keys vals)
       (if (null vals)
           nil
           (list* (car keys)
                  (car vals)
                  (make-plist (cdr keys)
                         (cdr vals)))))

(defun remtail (list tail)
       (if (eq list tail)
           nil
           (cons (car list)
                 (remtail (cdr list)
                        tail))))


;;; ONCE-ONLY does the same thing as it does in zetalisp.  I should have just lifted it from there
;;; but I am honest.  Not only that but this one is written in Common Lisp.  I feel a lot like
;;; bootstrapping, or maybe more like rebuilding Rome. 


(defmacro once-only (vars &body body)
       (let ((gensym-var (gensym))
             (run-time-vars (gensym))
             (run-time-vals (gensym))
             (expand-time-val-forms nil))
            (dolist (var vars)
                (push `(if (or (symbolp ,var)
                               (numberp ,var)
                               (and (listp ,var)
                                    (member (car ,var)
                                           ''function)))
                           ,var
                           (let ((,gensym-var (gensym)))
                                (push ,gensym-var ,run-time-vars)
                                (push ,var ,run-time-vals)
                                ,gensym-var))
                      expand-time-val-forms))
            `(let* (,run-time-vars ,run-time-vals (wrapped-body (let ,(mapcar #'list vars
                                                                             (reverse 
                                                                                expand-time-val-forms
                                                                                    ))
                                                                     ,@body)))
                   `(let ,(mapcar #'list (reverse ,run-time-vars)
                                 (reverse ,run-time-vals))
                         ,wrapped-body))))

(eval-when
 (compile load eval)
 (defun extract-declarations (body &optional environment)
        (declare (values documentation declarations body))
        (let (documentation declarations form)
             (when (and (stringp (car body))
                        (cdr body))
                 (setq documentation (pop body)))
             (block outer
                 (loop (when (null body)
                             (return-from outer nil))
                       (setq form (car body))
                       (when (block inner
                                 (loop (cond ((not (listp form))
                                              (return-from outer nil))
                                             ((eq (car form)
                                                  'declare)
                                              (return-from inner 't))
                                             (t (multiple-value-bind
                                                 (newform macrop)
                                                 (macroexpand-1 form environment)
                                                 (if (or (not (eq newform form))
                                                         macrop)
                                                     (setq form newform)
                                                     (return-from outer nil)))))))
                           (pop body)
                           (dolist (declaration (cdr form))
                               (push declaration declarations)))))
             (values documentation (and declarations `((declare ,.(nreverse declarations))))
                    body))))

(defvar *keyword-package* (find-package 'keyword))

(defun make-keyword (symbol)
       (intern (symbol-name symbol)
              *keyword-package*))

(eval-when (compile load eval)
       (defun string-append (&rest strings)
              (setq strings (copy-list strings))
                                                             ; The explorer can't even rplaca an
                                                             ; &rest arg? 
              (do ((string-loc strings (cdr string-loc)))
                  ((null string-loc)
                   (apply #'concatenate 'string strings))
                (rplaca string-loc (string (car string-loc))))))

(defun symbol-append (sym1 sym2 &optional (package *package*))
       (intern (string-append sym1 sym2)
              package))

(defmacro check-member (place list &key (test #'eql)
                              (pretty-name place))
       (once-only (place list)
              `(or (member ,place ,list :test ,test)
                   (error "The value of ~A, ~S is not one of ~S." ',pretty-name ,place ,list))))

(defmacro alist-entry (alist key make-entry-fn)
       (once-only (alist key)
              `(or (assq ,key ,alist)
                   (progn (setf ,alist (cons (,make-entry-fn ,key)
                                             ,alist))
                          (car ,alist)))))

(defmacro collecting-once (&key initial-value)
       `(let* ((head ,initial-value)
               (tail ,(and initial-value `(last head))))
              (values #'(lambda (value)
                               (if (null head)
                                   (setq head (setq tail (list value)))
                                   (unless (memq value head)
                                       (setq tail (cdr (rplacd tail (list value)))))))
                     #'(lambda nil head))))

(defmacro doplist ((key val)
                   plist &body body &environment env)
       (multiple-value-bind (doc decls bod)
              (extract-declarations body env)
              (declare (ignore doc))
              `(let ((.plist-tail. ,plist)
                     ,key
                     ,val)
                    ,@decls
                    (loop (when (null .plist-tail.)
                                (return nil))
                          (setq ,key (pop .plist-tail.))
                          (when (null .plist-tail.)
                                (error "Malformed plist in doplist, odd number of elements."))
                          (setq ,val (pop .plist-tail.))
                          (progn ,@bod)))))

(defmacro if* (condition true &rest false)
       `(if ,condition
            ,true
            (progn ,@false)))


;; 



;;; printing-random-thing



;; 



;;; Similar to printing-random-object in the lisp machine but much simpler and machine independent. 


(defmacro printing-random-thing ((thing stream)
                                 &body body)
       (once-only (stream)
              `(progn (format ,stream "#<")
                      ,@body
                      (format ,stream " ")
                      (printing-random-thing-internal ,thing ,stream)
                      (format ,stream ">"))))

(defun printing-random-thing-internal (thing stream)
       (let ((*print-base* 8))
            (princ (il:\\hiloc thing)
                   stream)
            (princ "," stream)
            (princ (il:\\loloc thing)
                   stream)))


;; 



;;; 



;; 


(defun capitalize-words (string &optional (dashes-p t))
       (let ((string (copy-seq (string string))))
            (declare (string string))
            (do* ((flag t flag)
                  (length (length string)
                         length)
                  (char nil char)
                  (i 0 (+ i 1)))
                 ((= i length)
                  string)
               (setq char (elt string i))
               (cond ((both-case-p char)
                      (if flag
                          (and (setq flag (lower-case-p char))
                               (setf (elt string i)
                                     (char-upcase char)))
                          (and (not flag)
                               (setf (elt string i)
                                     (char-downcase char))))
                      (setq flag nil))
                     ((char-equal char #\-)
                      (setq flag t)
                      (unless dashes-p
                          (setf (elt string i)
                                #\Space)))
                     (t (setq flag nil))))))


;;; FIND-CLASS This is documented in the CLOS specification. 


(defvar *find-class* (make-hash-table :test #'eq))

(defun legal-class-name-p (x)
       (and (symbolp x)
            (not (keywordp x))))

(defun find-class (symbol &optional (errorp t)
                         environment)
       (declare (ignore environment))
       (or (gethash symbol *find-class*)
           (cond ((null errorp)
                  nil)
                 ((legal-class-name-p symbol)
                  (error "No class named: ~S." symbol))
                 (t (error "~S is not a legal class name." symbol)))))

(defsetf find-class (symbol &optional (errorp t)
                           environment)
       (new-value)
       (declare (ignore errorp environment))
       `(|SETF CLOS FIND-CLASS| ,new-value ,symbol))

(defun |SETF CLOS FIND-CLASS| (new-value symbol)
       (if (legal-class-name-p symbol)
           (setf (gethash symbol *find-class*)
                 new-value)
           (error "~S is not a legal class name." symbol)))

(defun find-wrapper (symbol)
       (class-wrapper (find-class symbol)))

(defmacro gathering1 (gatherer &body body)
  `(gathering ((.gathering1. ,gatherer))
               (macrolet ((gather1 (x)
                                 `(gather ,x .gathering1.)))
                      ,@body)))


;;; 


(defmacro vectorizing (&key (size 0))
       `(let* ((limit ,size)
               (result (make-array limit))
               (index 0))
              (values #'(lambda (value)
                               (if (= index limit)
                                   (error "vectorizing more elements than promised.")
                                   (progn (setf (svref result index)
                                                value)
                                          (incf index)
                                          value)))
                     #'(lambda nil result))))


;;; These are augmented definitions of list-elements and list-tails from iterate.lisp.  These
;;; versions provide the extra :by keyword which can be used to specify the step function through
;;; the list. 


(defmacro *list-elements (list &key (by #'cdr))
       `(let ((tail ,list))
             #'(lambda (finish)
                      (if (endp tail)
                          (funcall finish)
                          (prog1 (car tail)
                              (setq tail (funcall ,by tail)))))))

(defmacro *list-tails (list &key (by #'cdr))
       `(let ((tail ,list))
             #'(lambda (finish)
                      (prog1 (if (endp tail)
                                 (funcall finish)
                                 tail)
                          (setq tail (funcall ,by tail))))))
