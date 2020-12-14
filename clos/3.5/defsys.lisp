;;;-*-Mode:LISP; Package:(CLOS LISP 1000); Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;;
;;; Some support stuff for compiling and loading CLOS.  It would be nice if
;;; there was some portable make-system we could all agree to share for a
;;; while.  At least until people really get databases and stuff.
;;;
;;; ***                                                               ***
;;; ***        DIRECTIONS FOR INSTALLING CLOS AT YOUR SITE             ***
;;; ***                                                               ***
;;;
;;; To get CLOS working at your site you should:
;;; 
;;;  - Get all the CLOS source files from Xerox.  The complete list of source
;;;    file names can be found in the defsystem for CLOS which appears towards
;;;    the end of this file.
;;; 
;;;  - Edit the variable *clos-directory* below to specify the directory at
;;;    your site where the clos sources and binaries will be.  This variable
;;;    can be found by searching from this point for the string "***" in
;;;    this file.
;;; 
;;;  - Use the function (clos::compile-clos) to compile CLOS for your site.
;;; 
;;;  - Once CLOS has been compiled it can be loaded with (clos::load-clos).
;;;    Note that CLOS cannot be loaded on top of itself, nor can it be
;;;    loaded into the same world it was compiled in.
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

;;;
;;; Sure, its weird for this to be here, but in order to follow the rules
;;; about order of export and all that stuff, we can't put it in PKG before
;;; we want to use it.
;;; 
(defvar *the-clos-package* (find-package :clos))

(defvar *clos-system-date* "5/10/91 Interim CLOS release")


;;;
;;; Various hacks to get people's *features* into better shape.
;;; 
(eval-when (compile load eval)
  #+(and Symbolics Lispm)
  (multiple-value-bind (major minor) (sct:get-release-version)
    (etypecase minor
      (integer)
      (string (setf minor (parse-integer minor :junk-allowed t))))
    (pushnew :genera *features*)
    (ecase major
      ((6)
       (pushnew :genera-release-6 *features*))
      ((7)
       (pushnew :genera-release-7 *features*)
       (ecase minor
	 ((0 1) (pushnew :genera-release-7-1 *features*))
	 ((2)   (pushnew :genera-release-7-2  *features*))
	 ((3)   (pushnew :genera-release-7-3  *features*))
	 ((4)   (pushnew :genera-release-7-4  *features*))))
      ((8)
       (pushnew :genera-release-8 *features*)
       (ecase minor
	 ((0) (pushnew :genera-release-8-0 *features*))
	 ((1) (pushnew :genera-release-8-1 *features*))))))
  
  #+CLOE-Runtime
  (let ((version (lisp-implementation-version)))
    (when (string-equal version "2.0" :end1 (min 3 (length version)))
      (pushnew :cloe-release-2 *features*)))

  (dolist (feature *features*)
    (when (and (symbolp feature)                ;3600!!
               (equal (symbol-name feature) "CMU"))
      (pushnew :CMU *features*)))
  
  #+TI
  (if (eq (si:local-binary-file-type) :xld)
      (pushnew ':ti-release-3 *features*)
      (pushnew ':ti-release-2 *features*))

  #+Lucid
  (when (search "IBM RT PC" (machine-type))
    (pushnew :ibm-rt-pc *features*))

  #+ExCL
  (cond ((search "sun3" (lisp-implementation-version))
	 (push :sun3 *features*))
	((search "sun4" (lisp-implementation-version))
	 (push :sun4 *features*)))

  #+(and HP Lucid)
  (push :HP-Lucid *features*)
  #+(and HP (not Lucid))
  (push :HP-HPLabs *features*)

  #+Xerox
  (case il:makesysname
    (:lyric (push :Xerox-Lyric *features*))
    (otherwise (pushnew :Xerox-Medley *features*)))
;;;
;;; For KCL and IBCL, push the symbol :turbo-closure on the list *features*
;;; if you have installed turbo-closure patch.  See the file kcl-mods.text
;;; for details.
;;;
;;; The xkcl version of KCL has this fixed already.
;;; 

  #+xkcl(pushnew :turbo-closure *features*)

  )



;;; Yet Another Sort Of General System Facility and friends.
;;;
;;; The entry points are defsystem and operate-on-system.  defsystem is used
;;; to define a new system and the files with their load/compile constraints.
;;; Operate-on-system is used to operate on a system defined that has been
;;; defined by defsystem.  For example:
#||

(defsystem my-very-own-system
	   "/usr/myname/lisp/"
  ((classes   (precom)           ()                ())
   (methods   (precom classes)   (classes)         ())
   (precom    ()                 (classes methods) (classes methods))))

This defsystem should be read as follows:

* Define a system named MY-VERY-OWN-SYSTEM, the sources and binaries
  should be in the directory "/usr/me/lisp/".  There are three files
  in the system, there are named classes, methods and precom.  (The
  extension the filenames have depends on the lisp you are running in.)
  
* For the first file, classes, the (precom) in the line means that
  the file precom should be loaded before this file is loaded.  The
  first () means that no other files need to be loaded before this
  file is compiled.  The second () means that changes in other files
  don't force this file to be recompiled.

* For the second file, methods, the (precom classes) means that both
  of the files precom and classes must be loaded before this file
  can be loaded.  The (classes) means that the file classes must be
  loaded before this file can be compiled.  The () means that changes
  in other files don't force this file to be recompiled.

* For the third file, precom, the first () means that no other files
  need to be loaded before this file is loaded.  The first use of
  (classes methods)  means that both classes and methods must be
  loaded before this file can be compiled.  The second use of (classes
  methods) mean that whenever either classes or methods changes precom
  must be recompiled.

Then you can compile your system with:

 (operate-on-system 'my-very-own-system :compile)

and load your system with:

 (operate-on-system 'my-very-own-system :load)

||#

;;; 
(defvar *system-directory*)

;;;
;;; *port* is a list of symbols (in the CLOS package) which represent the
;;; Common Lisp in which we are now running.  Many of the facilities in
;;; defsys use the value of *port* rather than #+ and #- to conditionalize
;;; the way they work.
;;; 
(defvar *port*
        '(#+Genera               Genera
;         #+Genera-Release-6     Rel-6
;         #+Genera-Release-7-1   Rel-7
          #+Genera-Release-7-2   Rel-7
	  #+Genera-Release-7-3   Rel-7
          #+Genera-Release-7-1   Rel-7-1
          #+Genera-Release-7-2   Rel-7-2
	  #+Genera-Release-7-3   Rel-7-2	;OK for now
	  #+Genera-Release-7-4   Rel-7-2	;OK for now
	  #+Genera-Release-8	 Rel-8
	  #+imach                Ivory
	  #+Cloe-Runtime	 Cloe
          #+Lucid                Lucid
          #+Xerox                Xerox
	  #+Xerox-Lyric          Xerox-Lyric
	  #+Xerox-Medley         Xerox-Medley
          #+TI                   TI
          #+(and dec vax common) Vaxlisp
          #+KCL                  KCL
          #+IBCL                 IBCL
          #+excl                 excl
	  #+(and excl sun4)      excl-sun4
          #+:CMU                 CMU
          #+HP-HPLabs            HP-HPLabs
          #+:gclisp              gclisp
          #+pyramid              pyramid
          #+:coral               coral))

;;;
;;; When you get a copy of CLOS (by tape or by FTP), the sources files will
;;; have extensions of ".lisp" in particular, this file will be defsys.lisp.
;;; The preferred way to install clos is to rename these files to have the
;;; extension which your lisp likes to use for its files.  Alternately, it
;;; is possible not to rename the files.  If the files are not renamed to
;;; the proper convention, the second line of the following defvar should
;;; be changed to:
;;;     (let ((files-renamed-p nil)
;;;
;;; Note: Something people installing CLOS on a machine running Unix
;;;       might find useful.  If you want to change the extensions
;;;       of the source files from ".lisp" to ".lsp", *all* you have
;;;       to do is the following:
;;;
;;;       % foreach i (*.lisp)
;;;       ? mv $i $i:r.lsp
;;;       ? end
;;;       %
;;;
;;;       I am sure that a lot of people already know that, and some
;;;       Unix hackers may say, "jeez who doesn't know that".  Those
;;;       same Unix hackers are invited to fix mv so that I can type
;;;       "mv *.lisp *.lsp".
;;;
(defvar *pathname-extensions*
  (let ((files-renamed-p t)
        (proper-extensions
          (car
           '(#+(and Genera (not imach))          ("lisp"  . "bin")
	     #+(and Genera imach)                ("lisp"  . "ibin")
	     #+Cloe-Runtime			 ("l"	  . "fasl")
             #+(and dec common vax (not ultrix)) ("LSP"   . "FAS")
             #+(and dec common vax ultrix)       ("lsp"   . "fas")
             #+KCL                               ("lsp"   . "o")
             #+IBCL                              ("lsp"   . "o")
             #+Xerox                             ("lisp"  . "dfasl")
             #+(and Lucid MC68000)               ("lisp"  . "lbin")
             #+(and Lucid VAX)                   ("lisp"  . "vbin")
             #+(and Lucid Prime)                 ("lisp"  . "pbin")
	     #+(and Lucid SUNRise)               ("lisp"  . "sbin")
	     #+(and Lucid SPARC)                 ("lisp"  . "sbin")
             #+(and Lucid IBM-RT-PC)             ("lisp"  . "bbin")
             #+(and Lucid MIPS)                  ("lisp"  . "mbin")
             #+(and Lucid PRISM)                 ("lisp"  . "abin")
             #+(and Lucid PA)                    ("lisp"  . "hbin")
	     #+excl                              ("cl"    . "fasl")
             #+:CMU                              ("slisp" . "sfasl")
             #+HP                                ("l"     . "b")
             #+TI ("lisp" . #.(string (si::local-binary-file-type)))
             #+:gclisp                           ("LSP"   . "F2S")
             #+pyramid                           ("clisp" . "o")
             #+:coral                            ("lisp"  . "fasl")
             ))))
    (cond ((null proper-extensions) '("l" . "lbin"))
          ((null files-renamed-p) (cons "lisp" (cdr proper-extensions)))
          (t proper-extensions))))

(eval-when (compile load eval)

(defun get-system (name)
  (get name 'system-definition))

(defun set-system (name new-value)
  (setf (get name 'system-definition) new-value))

(defmacro defsystem (name directory files)
  `(set-system ',name (list #'(lambda () ,directory)
			    (make-modules ',files)
			    ',(mapcar #'car files))))

)


;;;
;;; The internal datastructure used when operating on a system.
;;; 
(defstruct (module (:constructor make-module (name))
                   (:print-function
                     (lambda (m s d)
                       (declare (ignore d))
                       (format s "#<Module ~A>" (module-name m)))))
  name
  load-env
  comp-env
  recomp-reasons)

(defun make-modules (system-description)
  (let ((modules ()))
    (labels ((get-module (name)
               (or (find name modules :key #'module-name)
                   (progn (setq modules (cons (make-module name) modules))
                          (car modules))))
             (parse-spec (spec)
               (if (eq spec 't)
                   (reverse (cdr modules))
		   (case (car spec)
		     (+ (append (reverse (cdr modules)) (mapcar #'get-module (cdr spec))))
		     (- (let ((rem (mapcar #'get-module (cdr spec))))
			  (remove-if #'(lambda (m) (member m rem)) (reverse (cdr modules)))))
		     (otherwise (mapcar #'get-module spec))))))
      (dolist (file system-description)
        (let* ((name (car file))
               (port (car (cddddr file)))
               (module nil))
          (when (or (null port)
                    (member port *port*))
            (setq module (get-module name))
            (setf (module-load-env module) (parse-spec (cadr file))
                  (module-comp-env module) (parse-spec (caddr file))
                  (module-recomp-reasons module) (parse-spec
                                                   (cadddr file))))))
      (let ((filenames (mapcar #'car system-description)))
	(sort modules #'(lambda (name1 name2)
			  (member name2 (member name1 filenames)))
	      :key #'module-name)))))


(defun make-transformations (modules filter make-transform)
  (let ((transforms (list nil)))
    (dolist (m modules)
      (when (funcall filter m transforms) (funcall make-transform m transforms)))
    (reverse (cdr transforms))))

(defun make-compile-transformation (module transforms)
  (unless (dolist (trans transforms)
	    (and (eq (car trans) ':compile)
		 (eq (cadr trans) module)
		 (return t)))
    (dolist (c (module-comp-env module)) (make-load-transformation c transforms))
    (setf (cdr transforms)
	  (remove-if #'(lambda (trans) (and (eq (car trans) :load) (eq (cadr trans) module)))
		     (cdr transforms)))
    (push `(:compile ,module) (cdr transforms))))

(defvar *being-loaded* ())

(defun make-load-transformation (module transforms)
  (if (assoc module *being-loaded*)
      (throw module (setf (cdr transforms) (cdr (assoc module *being-loaded*))))
      (let ((*being-loaded* (cons (cons module (cdr transforms)) *being-loaded*)))
	(catch module
	  (unless (dolist (trans transforms)
		    (when (and (eq (car trans) ':load)
			       (eq (cadr trans) module))
		      (return t)))
	    (dolist (l (module-load-env module)) (make-load-transformation l transforms))
	    (push `(:load ,module) (cdr transforms)))))))

(defun make-load-without-dependencies-transformation (module transforms)
  (unless (dolist (trans transforms)
            (and (eq (car trans) ':load)
                 (eq (cadr trans) module)
                 (return trans)))
    (push `(:load ,module) (cdr transforms))))

(defun compile-filter (module transforms)
  (or (dolist (r (module-recomp-reasons module))
        (when (dolist (transform transforms)
                (when (and (eq (car transform) ':compile)
                           (eq (cadr transform) r))
                  (return t)))
          (return t)))
      (null (probe-file (make-binary-pathname (module-name module))))
      (> (file-write-date (make-source-pathname (module-name module)))
         (file-write-date (make-binary-pathname (module-name module))))))

(defun operate-on-system (name mode &optional arg print-only)
  (let ((system (get-system name)))
    (unless system (error "Can't find system with name ~S." name))
    (let ((*system-directory* (funcall (car system)))
	  (modules (cadr system))
	  (transformations ()))
      (labels ((load-source (name pathname)
		 (format t "~&Loading source of ~A..." name)
		 (or print-only (load pathname)))
	       (load-binary (name pathname)
		 (format t "~&Loading binary of ~A..." name)
		 (or print-only (load pathname)))	       
	       (load-module (m)
		 (let* ((name (module-name m))
			(*load-verbose* nil)
			(binary (make-binary-pathname name)))
		   (load-binary name binary)))
	       (compile-module (m)
		 (format t "~&Compiling ~A..." (module-name m))
		 (unless print-only
		   (let  ((name (module-name m)))
		     (compile-file (make-source-pathname name)
				   :output-file
				   (make-pathname :defaults
						  (make-binary-pathname name)
						  :version :newest)))))
	       (xcl:true (&rest ignore) (declare (ignore ignore)) 't))
	
	(setq transformations
	      (ecase mode
		(:compile
		  ;; Compile any files that have changed and any other files
		  ;; that require recompilation when another file has been
		  ;; recompiled.
		  (make-transformations
		    modules
		    #'compile-filter
		    #'make-compile-transformation))
		(:recompile
		  ;; Force recompilation of all files.
		  (make-transformations
		    modules
		    #'xcl:true
		    #'make-compile-transformation))
		(:recompile-some
		  ;; Force recompilation of some files.  Also compile the
		  ;; files that require recompilation when another file has
		  ;; been recompiled.
		  (make-transformations
		    modules
		    #'(lambda (m transforms)
			(or (member (module-name m) arg)
			    (compile-filter m transforms)))
		    #'make-compile-transformation))
		(:query-compile
		  ;; Ask the user which files to compile.  Compile those
		  ;; and any other files which must be recompiled when
		  ;; another file has been recompiled.
		  (make-transformations
		    modules
		    #'(lambda (m transforms)
			(or (compile-filter m transforms)
			    (y-or-n-p "Compile ~A?"
				      (module-name m))))
		    #'make-compile-transformation))
		(:confirm-compile
		  ;; Offer the user a chance to prevent a file from being
		  ;; recompiled.
		  (make-transformations
		    modules
		    #'(lambda (m transforms)
			(and (compile-filter m transforms)
			     (y-or-n-p "Go ahead and compile ~A?"
				       (module-name m))))
		    #'make-compile-transformation))
		(:load
		  ;; Load the whole system.
		  (make-transformations
		    modules
		    #'xcl:true
		    #'make-load-transformation))
		(:query-load
		  ;; Load only those files the user says to load.
		  (make-transformations
		    modules
		    #'(lambda (m transforms)
			(declare (ignore transforms))
			(y-or-n-p "Load ~A?" (module-name m)))
		    #'make-load-without-dependencies-transformation))))
	
	(#+Genera
	 compiler:compiler-warnings-context-bind
	 #+TI
	 COMPILER:COMPILER-WARNINGS-CONTEXT-BIND
	 #+:LCL3.0
	 lucid-common-lisp:with-deferred-warnings
	 #-(or Genera TI :LCL3.0)
	 progn
	 (loop (when (null transformations) (return t))
	       (let ((transform (pop transformations)))
		 (ecase (car transform)
		   (:compile (compile-module (cadr transform)))
		   (:load (load-module (cadr transform)))))))))))


(defun make-source-pathname (name) (make-pathname-internal name :source))
(defun make-binary-pathname (name) (make-pathname-internal name :binary))

(defun make-pathname-internal (name type)
  (let* ((extension (ecase type
                      (:source (car *pathname-extensions*))
                      (:binary (cdr *pathname-extensions*))))
         (directory (pathname
		      (etypecase *system-directory*
			(string *system-directory*)
			(pathname *system-directory*)
			(cons (ecase type
				(:source (car *system-directory*))
				(:binary (cdr *system-directory*)))))))
         (pathname
           (make-pathname
             :name (string-downcase (string name))
             :type extension
             :defaults directory :version :newest)))

    #+Genera
    (setq pathname (zl:send pathname :new-raw-name (pathname-name pathname))
          pathname (zl:send pathname :new-raw-type (pathname-type pathname)))

    pathname))



;;; ***                SITE SPECIFIC CLOS DIRECTORY                        ***
;;;
;;; *clos-directory* is a variable which specifies the directory clos is stored
;;; in at your site.  If the value of the variable is a single pathname, the
;;; sources and binaries should be stored in that directory.  If the value of
;;; that directory is a cons, the CAR should be the source directory and the
;;; CDR should be the binary directory.
;;;
;;; By default, the value of *clos-directory* is set to the directory that
;;; this file is loaded from.  This makes it simple to keep multiple copies
;;; of CLOS in different places, just load defsys from the same directory as
;;; the copy of CLOS you want to use.
;;;
;;; Note that the value of *CLOS-DIRECTORY* is set using a DEFVAR.  This is
;;; done to make it possible for users to set it in their init file and then
;;; load this file.  The value set in the init file will override the value
;;; here.
;;;
;;; ***                                                                   ***

(defun load-truename (&optional (errorp nil))
  (flet ((bad-time ()
	   (when errorp
	     (error "LOAD-TRUENAME called but a file isn't being loaded."))))
    #+Lispm  (or sys:fdefine-file-pathname (bad-time))
    #+excl   excl::*source-pathname*
    #+Xerox  (pathname (or (il:fullname *standard-input*) (bad-time)))
    #+(and dec vax common) (truename (sys::source-file #'load-truename))
    ;;
    ;; The following use of  `lucid::' is a kludge for 2.1 and 3.0
    ;; compatibility.  In 2.1 it was in the SYSTEM package, and i
    ;; 3.0 it's in the LUCID-COMMON-LISP package.
    ;;
    #+LUCID (or lucid::*source-pathname* (bad-time))
    #-(or Lispm excl Xerox (and dec vax common) LUCID) nil))

#-Symbolics
(defvar *clos-directory*
	(or (load-truename t)
	    (error "Because load-truename is not implemented in this port~%~
                    of CLOS, you must manually edit the definition of the~%~
                    variable *clos-directory* in the file defsys.lisp.")))

#+Genera
(defvar *clos-directory*
	(let ((source (load-truename t)))
	  (flet ((subdir (name)
		   (scl:send source :new-pathname :raw-directory
			     (append (scl:send source :raw-directory)
				     (list name)))))
	    (cons source
		  #+genera-release-7-2       (subdir "rel-7-2")
		  #+genera-release-7-3       (subdir "rel-7-3") 
		  #+genera-release-7-4       (subdir "rel-7-4")
		  #+genera-release-8-0       (subdir "rel-8-0")
		  #+genera-release-8-1       (subdir "rel-8-1")
		  ))))

#+Cloe-Runtime
(defvar *clos-directory* (pathname "/usr3/hornig/clos/"))

(defsystem clos	   
           *clos-directory*
  ;;
  ;; file         load           compile      files which       port
  ;;              environment    environment  force the of
  ;;                                          recompilation
  ;;                                          of this file
  ;;                                          
  (
   (patch           t            t            ()                xerox)
   (pkg             t            t            ())
   (walk            (pkg)        (pkg)        ())
   (iterate         t            t            ())
   (macros          t            t            ())
   (low             (pkg macros) t            (macros))
   (low2          (low)         (low)        (low)            Xerox)
   (fin         t                                   t (low))
   (defclass    t                                   t (low))
   (defs        t                                   t (defclass macros iterate))
   (fngen       t                                   t (low))
   (lap         t                                   t (low))
   (plap        t                                   t (low))
   (cache       t                                   t (low defs))
   (dlap        t                                   t (defs low fin cache lap))
   (boot        t                                   t (defs fin))
   (vector      t                                   t (boot defs cache fin))
   (slots       t                                   t (vector boot defs low cache fin))
   (init        t                                   t (vector boot defs low cache fin))
   (std-class   t                                   t (vector boot defs low cache fin slots))
   (cpl         t                                   t (vector boot defs low cache fin slots))
   (braid       t                                   t (boot defs low fin cache))
   (fsc         t                                   t (defclass boot defs low fin cache))
   (methods     t                                   t (defclass boot defs low fin cache))
   (combin      t                                   t (defclass boot defs low fin cache))
   (dfun        t                                   t (dlap))
   (fixup       (+ precom1 precom2 precom4)         t (boot defs low fin))
   (defcombin   t                                   t (defclass boot defs low fin))
   (ctypes      t                                   t (defclass defcombin))
   (construct   t                                   t (defclass boot defs low))
   (env         t                                   t (defclass boot defs low fin))
   (compat      t                                   t ())
   (precom1     (dlap)                              t (defs low cache fin dfun))
   (precom2     (dlap)                              t (defs low cache fin dfun))
   (precom4     (dlap)                              t (defs low cache fin dfun))

   (clos-env    t                                   t ()   Xerox)
   (web-editor  t                                   t ()   Xerox)
   (new-clos-browser t                              t ()   Xerox)
   ))

(defun compile-clos (&optional m)
  (let (#+:coral(ccl::*warn-if-redefine-kernel* nil)
	#+Lucid (lcl:*redefinition-action* nil)
	#+excl  (excl::*redefinition-warnings* nil)
	#+Genera (sys:inhibit-fdefine-warnings t)
	)
    (cond ((null m)        (operate-on-system 'clos :compile))
	  ((eq m :print)   (operate-on-system 'clos :compile () t))
	  ((eq m :query)   (operate-on-system 'clos :query-compile))
	  ((eq m :confirm) (operate-on-system 'clos :confirm-compile))
	  ((eq m 't)       (operate-on-system 'clos :recompile))        
	  ((listp m)       (operate-on-system 'clos :compile-from m))
	  ((symbolp m)     (operate-on-system 'clos :recompile-some `(,m))))))

(defun load-clos (&optional m)
  (let (#+:coral(ccl::*warn-if-redefine-kernel* nil)
	#+Lucid (lcl:*redefinition-action* nil)
	#+excl  (excl::*redefinition-warnings* nil)
	#+Genera (sys:inhibit-fdefine-warnings t)
	)
    (cond ((null m)      (operate-on-system 'clos :load))
	  ((eq m :query) (operate-on-system 'clos :query-load)))
    (pushnew :clos *features*)))

#+Genera
;;; Make sure Genera bug mail contains the CLOS bug data.  A little
;;; kludgy, but what the heck.  If they didn't mean for people to do
;;; this, they wouldn't have made private patch notes be flavored
;;; objects, right?  Right.
(progn
  (scl:defflavor clos-private-patch-info ((description)) ())
  (scl:defmethod (sct::private-patch-info-description clos-private-patch-info) ()
    (or description
	(setf description (string-append "CLOS version: " *clos-system-date*))))
  (scl:defmethod (sct::private-patch-info-pathname clos-private-patch-info) ()
    *clos-directory*)
  (unless (find-if #'(lambda (x) (typep x 'clos-private-patch-info))
		   sct::*private-patch-info*)
    (push (scl:make-instance 'clos-private-patch-info)
	  sct::*private-patch-info*)))

(defun bug-report-info (&optional (stream *standard-output*))
  (format stream "~&CLOS system date: ~A~
                  ~&Lisp Implementation type: ~A~
                  ~&Lisp Implementation version: ~A~
                  ~&*features*: ~S"
	  *clos-system-date*
	  (lisp-implementation-type)
	  (lisp-implementation-version)
	  *features*))



;;;;
;;;
;;; This stuff is not intended for external use.
;;; 
(defun rename-clos ()
  (dolist (f (cadr (get-system 'clos)))
    (let ((old nil)
          (new nil))
      (let ((*system-directory* *default-pathname-defaults*))
        (setq old (make-source-pathname (car f))))
      (setq new  (make-source-pathname (car f)))
      (rename-file old new))))

#+Genera
(defun edit-clos ()
  (dolist (f (cadr (get-system 'clos)))
    (let ((*system-directory* *clos-directory*))
      (zwei:find-file (make-source-pathname (car f))))))

#+Genera
(defun hardcopy-clos (&optional query-p)
  (let ((files (mapcar #'(lambda (f)
                           (setq f (car f))
                           (and (or (not query-p)
                                    (y-or-n-p "~A? " f))
                                f))
		       (cadr (get-system 'clos))))
        (b zwei:*interval*))
    (unwind-protect
        (dolist (f files)
          (when f
            (multiple-value-bind (ignore b)
                (zwei:find-file (make-source-pathname f))
              (zwei:hardcopy-buffer b))))
      (zwei:make-buffer-current b))))


;;;
;;; unido!ztivax!dae@seismo.css.gov
;;; z30083%tansei.cc.u-tokyo.junet@utokyo-relay.csnet
;;; Victor@carmen.uu.se
;;; mcvax!harlqn.co.uk!chris@uunet.UU.NET
;;; 
#+Genera
(defun mail-clos (to)
  (let* ((original-buffer zwei:*interval*)
	 (*system-directory* (pathname "vaxc:/user/ftp/pub/clos/")
			    ;(funcall (car (get-system 'clos)))
			     )
         (files (list* 'defsys
			'test
			(caddr (get-system 'clos))))
         (total-number (length files))
         (file nil)
	 (number-of-lines 0)
         (i 0)
         (mail-buffer nil))
    (unwind-protect
        (loop
           (when (null files) (return nil))
           (setq file (pop files))
           (incf i)
           (multiple-value-bind (ignore b)
               (zwei:find-file (make-source-pathname file))
	     (setq number-of-lines (zwei:count-lines b))
             (zwei:com-mail-internal t
                                     :initial-to to
                                     :initial-body b
				     :initial-subject
                                     (format nil
				       "CLOS file   ~A   (~A of ~A) ~D lines"
				       file i total-number number-of-lines))
             (setq mail-buffer zwei:*interval*)
             (zwei:com-exit-com-mail)
             (format t "~&Just sent ~A  (~A of ~A)." b i total-number)
             (zwei:kill-buffer mail-buffer)))
      (zwei:make-buffer-current original-buffer))))


