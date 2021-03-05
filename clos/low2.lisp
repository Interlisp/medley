;;;-*- Package: CLOS; Syntax: Common-Lisp; Base: 10 -*-


;;; File converted on 26-Mar-91 10:30:44 from source xerox-low
;;;. Original source {dsk}<usr>local>users>welch>lisp>clos>rev4>il-format>xerox-low.;3 created 27-Feb-91 16:37:43

;;;. Copyright (c) 1991 by Venue



(in-package "CLOS")

;;; Shadow, Export, Require, Use-package, and Import forms should follow here



;;; ************************************************************************* This is the 1100
;;; (Xerox version) of the file portable-low. 


(defmacro load-time-eval (form)
       `(il:loadtimeconstant ,form))


;;; make the pointer from an instance to its class wrapper be an xpointer. this prevents instance
;;; creation from spending a lot of time incrementing the large refcount of the class-wrapper.  This
;;; is safe because there will always be some other pointer to the wrapper to keep it around. 


(defstruct (std-instance (:predicate std-instance-p)
                  (:conc-name %std-instance-)
                  (:constructor %%allocate-instance--class nil)
                  (:fast-accessors t)
                  (:print-function %print-std-instance))
       (wrapper nil :type il:fullxpointer)
       (slots nil))

(defun %print-std-instance (instance &optional stream depth)
       
       ;; See the IRM, section 25.3.3.  Unfortunatly, that documentation is not correct.  In
       ;; particular, it makes no mention of the third argument. 
       (cond ((streamp stream)
              
              ;; Use the standard CLOS printing method, then return T to tell the printer that we
              ;; have done the printing ourselves. 
              (print-std-instance instance stream depth)
              t)
             (t 
                ;; Internal printing (again, see the IRM section 25.3.3). Return a list containing
                ;; the string of characters that would be printed, if the object were being printed
                ;; for real. 
                (list (with-output-to-string (stream)
                             (print-std-instance instance stream depth))))))


;; 



;;; FUNCTION-ARGLIST



;; 


(defun function-arglist (x)
       
       ;; Xerox lisp has the bad habit of returning a symbol to mean &rest, and strings instead of
       ;; symbols.  How silly. 
       (let ((arglist (il:arglist x)))
            (when (symbolp arglist)
                
                ;; This could be due to trying to extract the arglist of an interpreted function
                ;; (though why that should be hard is beyond me).  On the other hand, if the
                ;; function is compiled, it helps to ask for the "smart" arglist. 
                (setq arglist (if (consp (symbol-function x))
                                  (second (symbol-function x))
                                  (il:arglist x t))))
            (if (symbolp arglist)
                
                ;; Probably never get here, but just in case
                (list '&rest 'rest)
                
                ;; Make sure there are no strings where there should be symbols
                (if (some #'stringp arglist)
                    (mapcar #'(lambda (a)
                                     (if (symbolp a)
                                         a
                                         (intern a)))
                           arglist)
                    arglist))))

(defun printing-random-thing-internal (thing stream)
       (let ((*print-base* 8))
            (princ (il:\\hiloc thing)
                   stream)
            (princ "," stream)
            (princ (il:\\loloc thing)
                   stream)))

(defun record-definition (name type &optional parent-name parent-type)
       (declare (ignore type parent-name))
       nil)


;;; FIN uses this too! 


(eval-when (compile load eval)
       (il:datatype il:compiled-closure (il:fnheader il:environment))
       (il:blockrecord closure-overlay ((funcallable-instance-p il:flag))))

(defun compiled-closure-fnheader (compiled-closure)
       (il:fetch (il:compiled-closure il:fnheader)
              il:of compiled-closure))

(defun set-compiled-closure-fnheader (compiled-closure nv)
       (il:replace (il:compiled-closure il:fnheader)
              il:of compiled-closure nv))

(defsetf compiled-closure-fnheader set-compiled-closure-fnheader)


;;; In Lyric, and until the format of FNHEADER changes, getting the name from a compiled closure
;;; looks like this: (fetchfield '(nil 4 pointer) (fetch (compiled-closure fnheader) closure)) Of
;;; course this is completely non-robust, but it will work for now.  This is not the place to go
;;; into a long tyrade about what is wrong with having record package definitions go away when you
;;; ship the sysout; there isn't enough diskspace. 


(defun set-function-name-1 (fn new-name uninterned-name)
       (cond ((typep fn 'il:compiled-closure)
              (il:\\rplptr (compiled-closure-fnheader fn)
                     4 new-name)
              (when (and (consp uninterned-name)
                         (eq (car uninterned-name)
                             'method))
                  (let ((debug (si::compiled-function-debugging-info fn)))
                       (when debug
                           (setf (cdr debug)
                                 uninterned-name)))))
             (t nil))
       fn)
