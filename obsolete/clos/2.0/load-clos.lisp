;;; -*- Mode: Lisp; Package: xcl-User ; Base: 10.; Syntax: Common-Lisp -*-
;;;

(in-package "CLOS" :use (list (or (find-package :walker)
				    (make-package :walker :use '(:lisp)))
				(or (find-package :iterate)
				    (make-package :iterate
						  :use '(:lisp :walker)))
				(find-package :lisp)))
(export (intern (symbol-name :iterate)		;Have to do this here,
		(find-package :iterate))	;because in the defsystem
	(find-package :iterate))		;(later in this file)
						;we use the symbol iterate
						;to name the file

(defun load-truename (&optional (errorp nil))
  (flet ((bad-time ()
	   (when errorp
	     (error "LOAD-TRUENAME called but a file isn't being loaded."))))
    (let ((filename (pathname (il:fullname *standard-input*))))
      (if filename
	  (make-pathname :host (pathname-host filename) :device
			 (pathname-device filename) :directory
			 (pathname-directory filename) :name "") 
	  (bad-time)))))

(defvar *clos-directory* (load-truename))

(defun load-clos (&optional pathname)
  (defvar *clos-system-date* "7/14/91 Medley 2.0 (interim)")
  (defvar *the-clos-package* (find-package :clos))
  (dolist (filename '(patch pkg walk iterate macros low low2 fin
		    defclass defs fngen lap plap cache dlap boot
		    vector slots init std-class cpl braid fsc methods
		    combin dfun precom1 precom2 precom4 fixup
		    defcombin ctypes construct env))

    (load (merge-pathnames 
			 (make-pathname  :name (string-downcase filename) :type
					 "dfasl") (or pathname *clos-directory*))))
  (pushnew :clos cl:*features*))

