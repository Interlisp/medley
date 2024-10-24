 ;-*- syntax:COMMON-LISP; Package: (OSS CL 1000) -*-

;;; DRC, March 30, 1988: Changed PROCESS-TOP to COPY-TREE
;;; the user's code so that its not bashed.  This is particularly important
;;; in a resident-code environment (like XCL).
;;; AMD March 30, 1988: Changed Rlist to take advantage or RPLCONS instead of
;;; doing pushes follwed by NREVERSE.
;;; DRC, March 24, 1988: defstruct's for SYM & FRAG hacked to work in Lyric XCL

;;; (removed 2/11/2022) patch some bugs in Lyric XCL
;;  #+Xerox
;; (eval-when (compile load eval)
;;   (il:filesload "OSS-LYRIC-PATCHES.DFASL"))

;Anyone who wishes to, is free to use this software.  However, such use
;is at the user's own risk.  In particular, the system comes "as is"
;with no responsibility whatever on the part of the author or MIT.
;In addition, the following requirements must be met.
;  First, the copyright notices must not be removed from this file.
;  Second, if the software is redistributed to other people, proper
;     credit must be given to the author.
;  Third, adapting the file to run on a particular Common Lisp may
;     require minor changes.  However, the functionality must remain
;     consistent with the documentation in MIT/AIM-958a and MIT/AIM-959a.
;     (If you want a different functionality, write a new system and call
;     it something else.)

;------------------------------------------------------------------------ ;
;                Copyright (c) Richard C. Waters, 1988                    ;
;------------------------------------------------------------------------ ;

;This file implements efficient computation with obviously synchronizable
;series expressions.  All bug reports should be sent to DICK@AI.AI.MIT.EDU. 
;At the author's sole descretion, bugs may or may not be fixed.
;Howevr, bug messages are very much appreciated.  The functions
;in this file are documented fully in MIT/AIM-958a and MIT/AIM-959a.
;(Memo MIT/AIM-958a is an upwardly compatible, slightly revised version of
;MIT/AIM-958.  The only important difference is that when an expression 
;violates the restrictions, it is automatically fixed rather than just
;flagged as an error.  Memo MIT/AIM-959a is identical to MIT/AIM-959
;except for fixing a few minor errors in the document.)

;This file attempts to be as compatible with pure Common Lisp as possible.
;It has been tested on the following Common Lisps to date (3/23/88).
;  Symbolics CL version 7 (does not work in version 6),
;  FRANZ {Allegro} CL on a Sun, LUCID CL on a Sun, DEC CL on a VAX,
;  Xerox CL, Golden CL on a PC, Coral Allegro CL on a Mac.
;The companion file OSSTST LISP contains a set of regression tests for OSS.
;You should run these tests after the first time you compile OSS on a
;new system.  Time permitting, I will be glad to help with any
;transportabilty problems.

#+lispm(use-package "CL")
(in-package "OSS")

(export
  '(letS letS* lambdaS funcallS prognS defunS valS pass-valS alterS mapS
    showS defun-primitiveS lambda-primitiveS terminateS next-inS next-outS
    prologS epilogS wrapS alterableS oss-tutorial-mode
    Eoss Eup Edown Esublists Elist Etree Efringe Evector Esequence
    Efile Ehash Ealist Eplist Esymbols EnumerateF Enumerate-inclusiveF
    Tprevious Tlatch Tuntil TuntilF Tcotruncate TmapF TscanF
    Tremove-duplicates Tchunk Twindow Tpositions Tselect TselectF Tlastp
    Texpand Tmask Tsubseries Tmerge Tconcatenate TconcatenateF Tsplit TsplitF
    Rlist Rbag Rappend Rnconc Rvector Rfile Ralist Rplist Rhash
    Rlast Rlength Rsum Rmax Rmin ReduceF
    Rfirst Rnth Rand Ror Rfirst-late Rnth-late Rand-late Ror-late
    *permit-non-terminating-oss-expressions*
    *last-oss-loop* *last-oss-error*))

(defvar *last-oss-loop* nil "loop most recently created by OSS")
(defvar *last-oss-error* nil "info about error found most recently by OSS")
(defparameter *permit-non-terminating-oss-expressions* nil
  "controls error reports for non-terminating OSS expressions")

;The key internal form is an entity called a frag (short for fragment).

(defstruct (frag (:conc-name nil) (:type list) #+Xerox(:predicate frag-p-internal) :named)
  (code :?)       ;the surface code corresponding to this (for error messages)
  (marks 0)       ;mark bits used in sweeps over a graph
  (args nil)      ;a list of sym structs for the args of the frag
  (rets nil)      ;a list of sym structs for the return vals of the frag
  (aux nil)       ;the auxiliary variables if any.
  (dcls nil)      ;declarations associated with the frag.
  (alterable nil) ;specifications for alterable outputs
  (prolog nil)    ;list of forms (without labels).
  (body nil)      ;list of forms (possibly containing labels).
  (epilog nil)    ;list of forms (without labels).
  (wrappers nil)) ;functions that wrap forms around the whole loop.

;;;; Hack to get around Lyric XCL bug where default FRAG-P of NIL gives error
#+Xerox(xcl:definline frag-p (object) (and (consp object) (frag-p-internal object)))

;there cannot be any redundancy in or between the args and aux.  Each ret
;variable must be either on the args list or the aux list.  The args
;and ret have additional data as discussed below.  The aux is just a list
;of symbols.  Every symbol used in a frag which could possible clash
;with other frags (eg args, rets, aux, and also labels) must be
;gensyms and unique in the whole world.

;the order of the args is important when the frag is first
;instantiated and funcallSed.  However, it does not matter after that.
;Similarly, the order of the rets also matters at the time it is
;instantiated, and at the time that a whole expression is turned into
;one frag, but it does not matter at other times.

;there are two basic kinds of frags, oss frags and non-oss frags.  A non-oss
;frag is a frag which just has a simple computation which has to be performed
;only once.  The rets and args must be non-oss values, and the body and epilog
;must be empty.  (The code below maintains the invariant that if all
;the ports of a frag are non-oss then the body and epilog are empty.)

;a frag has three internal parts so that a wide variety of fragmentary
;oss functions can be compressed into a single frag.  (This is what
;lambdaS does.)  (Actually, any kind of fragmentary oss function can
;be represented.  However, to compress a thing like (Elist (Rlist S))
;(and other weird things) into a single frag, the input would have to
;be made off-line.  This is not done automatically, because it is
;against the spirit of oss.)

;Inside frags there is a label which has a special meaning.
; END is used as the label after the end of the loop created.  If the
;    body of a fragment contains (go END) then the fragment is an
;    active terminator.
;If a programmer uses this symbols in his program, very bad
;things could happen.  However, it is in the oss package, so
;there should not be any conflict problems.

;the code in this file assumes in many places that no oss: symbol can
;possibly clash with a user symbol.

(defun annotate (code frag)
  (setf (code frag) code)
  frag)

;Considerable effort is expended to see that the code field always
;contains code that makes sense to the user.  Extensive testing
;indicates that it never ends up containing :?, and that the code it
;contains always is part of the code the user types except that an
;optional argument can end up having the default value which ends up
;in the annotation.

;Each arg and ret has the following parts.

(defstruct (sym (:conc-name nil) (:type list) #+Xerox(:predicate sym-p-internal) :named)
  (back-ptrs (make-array 2 :initial-element nil))
  (var nil)              ;gensymed variable.
  (oss-var-p nil)        ;T if holds a series.
  (off-line-spot nil)    ;if off-line, place to insert the computation.
  (off-line-exit nil))   ;if non-passive input, label to catch exit.

;;;; Hack to get around Lyric XCL bug where default SYM-P of NIL gives error
#+Xerox(xcl:definline sym-p (object) (and (consp object) (sym-p-internal object))) 

;if there is an on-line-spot, it must appear in the frag code exactly
;once at top level.  It cannot be nested in a form.  Several args can
;have the same off-line-spot symbol.  This indicates that they are all
;in phase with each other.

;a number of functions depend on the fact that frags and syms are list
;structures which can be traversed by functions like nsubst.  The
;following three circular pointers are hidden in an array so they
;won't be followed.  (Note that ins only have prv and rets only have
;nxts, as a result, they can both be stored in the same place.  two
;names are used in order to enhance the readability of the program.)

(eval-when (eval load compile)
(defmacro fr (s)       ;back pointer to containing frag.
  `(aref (back-ptrs ,s) 0))
(defmacro nxts (s)     ;list of destinations of dflows starting here.
  `(aref (back-ptrs ,s) 1))
(defmacro prv (s)      ;the single source of dflow to here.
  `(aref (back-ptrs ,s) 1)) )

;The sym vars are symbols which appear in the body of the frag where they
;should.  All of the symbols must be unique in all the world.  Every instance
;of the symbol anywhere must be a use of the symbol.
;  Output variables can be freely read and written. 
;Input variables can be read freely, but cannot ever be written.
;  These restrictions guarantee that when frags are combined, it is OK to
;rename the input var of one to be the output var of the other.  In
;addition, the creator of an output can depend on the output variable
;being unchanged by the user(s).  However, this is not the main point.
;More critical is the situation where two frags use the same value.
;The second frag can be sure that the first frag did not wreck the value.
;(Side-effects could still cause problems.  The user must guard
;against destroying some other fragment's internal state.)
;  In the interest of good output code, some work is done to simplify
;things when frags are merged.  If an output is of the form (setq out c)
;where c is T, nil, or a number, then c is substituted directly for the
;input.  Substitution is also applied if c is a variable which is not
;bound in the destination frag.  In addition, other kinds of constants
;are substituted if they are only used in one place.  A final pass
;gets rid of setqs to variables that are never used for anything. 

#+:GCLISP
(eval-when (eval load compile)
  (defsetf fr set-fr)
  (defmacro set-fr (s value)
    `(setf (aref (back-ptrs ,s) 0) ,value))
  (defsetf nxts set-nxts)
  (defmacro set-nxts (x value)
    `(setf (aref (back-ptrs ,s) 1) ,value))
  (defsetf prv set-nxts) )

;The third key internal form is a graph of frags.  This is
;represented in an indirect way.  The special variable *graph*
;contains a list of all of the frags in the oss expression currently
;being processed.  The order of the frags in this list is vitally
;important.  It corresponds to their lexical order in the input
;expression and controls the default way things with no data flow
;between them are ordered when combined.  In addition, many of the
;algorithms depend on the fact that the order in *graph* is compatible
;with the data flow in that there can never be data flow from a frag
;to an earlier frag in the list.

;Subexpressions and regions within the expression as a whole are
;delineated by setting marking bits in the frags in the region.

;LambdaS makes special frags for arguments which are not in the list
;*graph*.  They exist to record info about the arguments and to
;preserve an invariant that every input of every frag in *graph* must
;have data flow ending on it.  A related invariant states that if a
;frag in *graph* has a ret then this ret must be used either by having
;dflow from it, or as an output of the expression as a whole.  Unused
;rets are removed from frags when the frags are created.

;for the purposes of testing whether a subexpression is strongly
;connected to its outputs, a frag with no rets is considered to be an
;output of the subexpression.

;This has to be called to set things up right, before processing of a
;OSS expression can proceed.

(defvar *oss-tutorial-mode* nil "controls tutorial mode")
(defvar *in-oss-expr* nil "the topmost OSS expression")

(proclaim '(special *graph*      ;list of frags in expression
		    *renames*    ;alist of variable renamings
		    *user-names* ;lets var names used by user
                    *env*))      ;environment of containing series macro call

;*renames* has three kinds of entries on it.  Each is a cons of a
;variable and something else:  (type 1 cannot ever be setqed.)
; 1- a ret, var is a lets var or a lambdaS var.
;    you can tell between the two because lambdaS var frags are not in *graph*.
; 2- a new var, var is an aux var.
; 3- nil, var is rebound and protected from renaming.

;should have some general error catching thing but common lisp has none.

(eval-when (eval load compile)
(defmacro top-starting-oss-expr (call &body body)
  `(catch :oss-error
     (starting-oss-expr ,call . ,body)))

(defmacro starting-oss-expr (call &body body)
  `(let ((*renames* nil)
	 (*user-names* nil)
	 (*in-oss-expr* (iterative-copy-tree ,call))) ;avoids side-effects
     (setq *last-oss-loop* nil)
     . ,body))

;This does two key things.  First, it checks to see whether an oss
;expression is starting.  As a result, defmacroS must be used to define
;every macro which can possibly start an OSS expression.  Second, if
;and only if the body returns a frag which does not already have its
;code field filled in, the macro call is put in the code field of the
;frag.  This provides a very useful default for the annotation.
;(Never let anything expand into a defmacroSed form, or the user can
;end up seeing something in an error message that he never wrote.)

(defmacro defmacroS (name arglist &body body)
  `(defmacro ,name (&whole +call+ . ,arglist)
       ,@(if (stringp (car body)) (list (pop body)))
       ,@(if (eq (caar body) 'declare) (list (pop body)))
     (if (not *in-oss-expr*)
	 (let ((result (macroexpand-1 (list 'process-top +call+))))
	   (if (not (consp result)) (setq result (list 'progn result)))
	   (rplaca +call+ (car result))  ;avoids reexpansions
	   (rplacd +call+ (cdr result))
	   result)
	 (let* ((+call+ (iterative-copy-tree +call+)) ;avoids side-effects
		(result (progn . ,body)))
	   (when (and (frag-p result) (eq (code result) :?))
	     (setf (code result) +call+))
	   result))))

(defmacro process-top  ;this snarfs the env ptr.
          (call #-:GCLISP &environment #-:GCLISP *env*)
  ;; COPY-TREE so we don't smash user's code
  (top-starting-oss-expr (copy-tree call) (codify (mergify (graphify call))))) )

(defun ers (id msg &rest args)
  (setq *last-oss-error* (list* id msg (copy-list args)))
  (warn "Error ~A in OSS expression:~%~S~%~?" id *in-oss-expr* msg args)
  (throw :oss-error id))

(defun wrs (id msg &rest args)
  (setq *last-oss-error* (list* id msg (copy-list args)))
  (warn "~A in OSS expression:~%~S~%~?" id *in-oss-expr* msg args))

;--------------------------------------------------

(defun non-oss-p (frag)
  (and (notany #'(lambda (x) (oss-var-p x)) (rets frag))
       (notany #'(lambda (x) (oss-var-p x)) (args frag))))

(defun active-terminator-p (frag)
  (or (branches-to 'END (prolog frag))
      (branches-to 'END (body frag))))

(defun off-line-p (frag)
  (or (some #'(lambda (a) (off-line-spot a)) (args frag))
      (some #'(lambda (r) (off-line-spot r)) (rets frag))))

(defun on-line-p (frag)
  (not (off-line-p frag)))

;this assumes that every instance of one of OSSs funny labels is
;really an instance of that label made by the macros below.

(defun branches-to (label tree)
  (cond ((and (eq-car tree 'tagbody) (member label tree)) nil)
	((and (eq-car tree 'go) (eq-car (cdr tree) label)) T)
	(T (do ((tt tree (cdr tt)))
	       ((not (consp tt)) nil)
	     (if (branches-to label (car tt)) (return T))))))

;hacking marks

(defun reset-marks (&optional (value 0))
  (dolist (f *graph*)
    (setf (marks f) value)))

(defun mark (mask frag)   ;sets bits on
  (setf (marks frag) (logior mask (marks frag))))

(defun marked-p (mask frag) ;checks that all bits are on
  (zerop (logandc2 mask (marks frag))))

(eval-when (eval load compile)
(defmacro dofrags ((var . mask) &body body) ;mask should be a constant
  (when mask
    (setq body `((when (marked-p ,(car mask) ,var) . ,body))))
  `(dolist (,var *graph*) . ,body)) )

;many of the functions in this file depend on the fact that frags and
;syms are list structures.  However, only the following functions (and defS)
;depend on the exact position of parts of these structures.  Note that
;the CL manual guarantees that these positions are correct in all
;implementations.

(defun merge-frags (frag1 frag2)
  (mapc #'(lambda (s) (setf (fr s) frag2)) (rets frag1))
  (mapc #'(lambda (s) (setf (fr s) frag2)) (args frag1))
  (mapl #'(lambda (f1 f2) (rplaca f2 (nconc (car f1) (car f2))))
	(cdddr frag1) (cdddr frag2))
  frag2)

(defun copy-fragment (frag)
  (let* ((alist (mapcar #'(lambda (v) (cons v (gensym (root v))))
			(find-gensyms frag)))
	 (new-frag (list* 'frag (code frag)
			  (nsublis alist (iterative-copy-tree (cddr frag))))))
    (dolist (a (args new-frag))
      (copy-ptrs a new-frag))
    (dolist (r (rets new-frag))
      (copy-ptrs r new-frag))
    new-frag))

(defun copy-ptrs (sym frag)
  (setf (back-ptrs sym) (make-array 2))
  (setf (nxts sym) nil)
  (setf (fr sym) frag))

(defun frag->list (frag)
  (setf (rets frag) (mapcar #'cddr (rets frag)))
  (setf (args frag) (mapcar #'cddr (args frag)))
  (let ((gensyms (find-gensyms frag)))
    (nsublis (mapcar #'(lambda (v) (cons v (gentemp (root v)))) gensyms)
      (cons gensyms (cdddr frag)))))

(defun find-gensyms (tree &optional (found nil))
  (do ((tt tree (cdr tt)))
      ((not (consp tt))
       (if (and (symbolp tt) (null (symbol-package tt)))
	   (adjoin tt found)
	   found))
    (setq found (find-gensyms (car tt) found))))

(defun root (symbol)
  (let* ((string (string symbol))
	 (pos (position #\- string :start (min (length string) 1))))
    (if pos (subseq string 0 (1+ pos)) (concatenate 'string string "-"))))

(defun list->frag (list)
  (let* ((alist (mapcar #'(lambda (v) (cons v (gensym (root v)))) (pop list)))
	 (frag (list* 'frag :? 0 (nsublis alist (iterative-copy-tree list)))))
    (setf (args frag) (mapcar #'(lambda (s) (list->sym s frag)) (args frag)))
    (setf (rets frag) (mapcar #'(lambda (s) (list->sym s frag)) (rets frag)))
    (values frag alist)))

(defun list->sym (list frag)
  (let ((s (make-sym :var (car list) :oss-var-p (cadr list)
		     :off-line-spot (caddr list)
		     :off-line-exit (cadddr list))))
    (setf (fr s) frag)
    s))

;some Common Lisps implement copy-tree tail recursively.

(defun iterative-copy-tree (tree)
  (do ((tail tree (cdr tail))
       (r nil (cons (iterative-copy-tree (car tail)) r)))
      ((not (consp tail)) (nreconc r tail))))

(defun literal-frag (stuff) ;(args rets aux dcls alt prolog body epilog wraprs)
  (let ((gensyms (nconc (mapcar #'car (nth 0 stuff)) (nth 2 stuff))))
    (dolist (f (nth 6 stuff))
      (if (symbolp f) (push f gensyms)))
    (list->frag (cons gensyms stuff))))

(eval-when (eval load compile)
(defmacro delete1 (thing list)
  `(setf ,list (delete1a ,thing ,list))) )

(defun delete1a (item list)
  (if (eq item (car list)) (cdr list)
      (do ((l list (cdr l)))
	  ((null (cdr list)))
	(when (eq item (cadr l))
	  (rplacd l (cddr l))
	  (return list)))))

(defun +arg (arg frag)
  (setf (fr arg) frag)
  (setf (args frag) (nconc (args frag) (list arg)))) ;needed by Tcotruncate

(defun -arg (arg)
  (delete1 arg (args (fr arg))))

(defun +ret (ret frag)
  (setf (fr ret) frag)
  (setf (rets frag) (nconc (rets frag) (list ret)))) ;needed by force-n-rets

(defun -ret (ret)
  (delete1 ret (rets (fr ret))))

(defun +frag (frag)
  (setf *graph* (nconc *graph* (list frag))) ;needed to keep order right
  frag)

(defun -frag (frag)
  (delete1 frag *graph*)
  (setf (marks frag) 0)) ;important so dofrags will notice deletions

(defun +dflow (source dest)
  (push dest (nxts source))
  (setf (prv dest) source))

(defun -dflow (source dest)
  (delete1 dest (nxts source))
  (setf (prv dest) nil))

(defun all-nxts (frag)
  (apply #'append (mapcar #'(lambda (r) (nxts r)) (rets frag))))

(defun all-prvs (frag)
  (delete nil (mapcar #'(lambda (a) (prv a)) (args frag))))

;                  TURNING AN EXPRESSION INTO A GRAPH

;  This parses code down to fundamental chunks creating a graph of the
;expression.  Note that macroexpanding and renaming is applied while 
;this happens.

(defun graphify (code)
  (let ((*graph* nil))
    (fragify code)
    *graph*))

;note have to be careful in the next two functions not to expand things twice.
;If you did, you could get two copies of some frags on *graph*.

(defun retify (code &aux expansion ret)
  (setq expansion (my-macroexpand code))
  (cond ((sym-p expansion) expansion)
	((sym-p (setq ret (cdr (assoc expansion *renames*)))) ret)
	(T (if (not (frag-p expansion))
	       (setq expansion (isolate-non-oss code expansion)))
	   (car (rets (force-n-rets 1 expansion))))))

(defun fragify (code &aux expansion)
  (setq expansion (my-macroexpand code))
  (if (not (frag-p expansion))
      (setq expansion (isolate-non-oss code expansion)))
  expansion)

(defun force-n-rets (n frag)
  (let ((len (length (rets frag))))
    (cond ((= n len))
	  ((> n len)
	   (ers 8 "Only ~A return values present where ~A expected~%~A"
		len n (code frag)))
	  (T (mapc #'kill-ret (nthcdr n (rets frag))))))
  frag)

(defun kill-ret (ret)
  (when (off-line-spot ret)
    (setf (body (fr ret))
	  (nsubst-inline nil (off-line-spot ret) (body (fr ret)))))
  (-ret ret))

;This makes a non-oss frag to start with, mapping (if needed) happens later.
;Rationale: we always group the biggest chunk possible into one thing
;because if it doesn't get mapped it doesn't matter and if it does
;get mapped and you don't want it all to be mapped, you can easily
;fix the problem by inserting (Eoss :R ...).  If we took a small piece when
;you wanted a large one, there would be no easy way for you to fix things.
;This also sets annotation on the frag produced.  For this to work
;right, it is important that isolate-non-oss is never called on
;anything but user code.

(defun isolate-non-oss (annotation code)
  (let* ((var (gensym "OUT-"))
	 (frag (make-frag :code annotation :aux (list var)))
	 (top-renames *renames*)
	 (exp (m-&-r code
		#'(lambda (c)
		    (if (not (or (frag-p c) (sym-p c))) c
			(let ((arg (make-sym :var (gensym "ARG-"))))
			  (+arg arg frag)
			  (if (frag-p c) (check-movability code c top-renames))
			  (+dflow (retify c) arg)
			  (var arg)))))))
    (+ret (make-sym :var var) frag)
    (setf (prolog frag) `((setq ,var ,exp)))
    (+frag frag)))

;this should really check if any bound vars are referenced, and should
;look to see if any special variables are being bound.  (We have to
;look at the code field, because the subexpr may have been turned into
;several frags).

(defun check-movability (top-code frag top-renames)
  (if (contains-p (mapcar #'car (ldiff *renames* top-renames)) (code frag))
      (wrs 13 "Decomposition moves:~%~S~%out of a binding scope:~%~S"
	   (code frag) top-code)))

(defun contains-p (items thing)
  (do ((tt thing (cdr tt)))
      ((not (consp tt)) (member tt items))
    (if (contains-p items (car tt)) (return T))))

(defmacroS mapS (&body expr-list) 
    "Causes EXPR-LIST to be mapped over the OSS variables in it."
  (setq expr-list (process-subforms expr-list))
  (isolate-non-oss +call+
    (if (null (cdr expr-list)) (car expr-list) `(progn . ,expr-list))))

;This expands all of the OSS exprs in forms as if they were in
;isolation.  You can process the result again, if you want it to be
;able to refer to OSS vars from outside.
(defun process-subforms (forms)
  (let ((*in-oss-expr* nil) (*renames* nil) (*user-names* nil))
    (mapcar #'m-&-r forms)))

(defmacroS funcallS (function &rest expr-list)
    "Applies an OSS function to the results of the expressions."
  (annotate +call+
    (if (frag-p function) (funcallS-frag0 function expr-list +call+)
	(case (quoted-function-p (setq function (my-macroexpand function)))
	  (lambdaS
	   (funcallS-frag0 (process-lambdas function (cadr function))
			   expr-list +call+))
	  (lambda-primitiveS
	   (funcallS-frag0 (process-lambda-primitiveS function (cadr function))
			   expr-list +call+))
	  (symbol
	   (let ((code (my-macroexpand (cons (cadr function) expr-list))))
	     (if (frag-p code) code (do-TmapF function expr-list))))
	  (otherwise (do-TmapF function expr-list))))))

(defun quoted-function-p (thing)
  (cond ((not (eq-car thing 'function)) nil)
	((symbolp (cadr thing)) 'symbol)
	((eq-car (cadr thing) 'lambda) 'lambda)
	((eq-car (cadr thing) 'lambdaS) 'lambdaS)
	((eq-car (cadr thing) 'lambda-primitiveS) 'lambda-primitiveS)))

(defun funcallS-frag0 (frag values call)
  (when (not (= (length values) (length (args frag))))
    (ers 7 "Wrong number of args to funcallS:~%~S" call))
  (funcallS-frag frag values))

(defun funcallS-frag (frag values)
  (mapc #'(lambda (v a) (+dflow (retify v) a)) values (args frag))
  (+frag frag))

(defmacroS prognS (&rest expr-list)
    "Delineates an OSS expression."
  (process-progns expr-list))

(defun process-progns (forms)
  (mapc #'(lambda (f) (force-n-rets 0 (fragify f))) (butlast forms))
  (fragify (car (last forms)))) ;forces NIL if no forms.

;note that this forces the values to either be all non-oss or all oss 
;and on-line with each other.  If you want more complicated outputs, you
;have to use the primitive definition facilities.

(defmacroS valS (&rest expr-list)
    "Returns multiple series values."
  (let ((frag (make-frag)))
    (dotimes (i (length expr-list) i)
      (let ((var (gensym "VAL-")))
	(+arg (make-sym :var var) frag)
	(+ret (make-sym :var var) frag)))
    (funcalls-frag frag expr-list)))

;LetS assumes that pass-valS doesn't appear in annotation.
(defmacroS pass-valS (n expr)
 "Used to pass multiple values from a non-OSS function into an OSS expression."
  (setq expr (my-macroexpand expr))
  (cond ((frag-p expr) (force-n-rets n expr))
	((= n 1) (annotate expr (fragify expr)))
	(T (let ((vars nil) frag)  ;note expr must be non-oss at top.
	     (dotimes (x n)
	       (push (gensym "VAL-") vars))
	     (setq frag (fragify `(multiple-value-setq ,vars ,expr)))
	     (setf (rets frag) nil)
	     (dolist (v vars)
	       (push v (aux frag))
	       (+ret (make-sym :var v) frag))
	     (annotate expr frag)))))

(defmacroS letS* (var-value-pair-list &body expr-list) 
    "Binds OSS variables in parallel."
  (let ((*renames* *renames*) (old-top *renames*))
    (dolist (p var-value-pair-list)
      (setq *renames* (process-lets-pair p *renames*)))
    (process-lets-body expr-list (ldiff *renames* old-top) +call+)))

(defmacroS letS (var-value-pair-list &body expr-list)
    "Binds OSS variables sequentially."
  (let ((new-renames *renames*) (old-top *renames*))
    (dolist (p var-value-pair-list)
      (setq new-renames (process-lets-pair p new-renames)))
    (let ((*renames* new-renames))
      (process-lets-body expr-list (ldiff *renames* old-top) +call+))))

(defun process-lets-pair (p alist)
  (setq p (normalize-pair p))
  (let* ((vars (car p))
	 (frag (fragify `(pass-valS ,(length vars) ,(cadr p)))))
    (mapc #'(lambda (v r)
	      (cond (v (push (cons v r) alist)				     
		       (push (cons (var r) v) *user-names*))
		    (T (kill-ret r))))
	  vars (copy-list (rets frag)))
    alist))

(defun normalize-pair (p)
  (cond ((and (consp p) (bind-var-p (car p)) (= (length p) 2))
	 (list (list (car p)) (cadr p)))
	((and (consp p) (consp (car p)) (every #'bind-var-p (car p))
	      (= (length p) 2)) p)
	(T (ers 9 "Malformed letS{*} binding pair ~S." p))))

(defun bind-var-p (thing)
  (or (null thing) (lambda-variable-p thing)))

(defun lambda-variable-p (thing)
  (and (variable-p thing)))

(defun variable-p (thing)
  (and thing (symbolp thing) (not (eq thing T)) (not (keywordp thing))
       (not (member thing lambda-list-keywords))))

(defun process-lets-body (forms alist call)
  (setq forms (normalize-dcls forms)) 
  (when (cddadr (car forms))
    (wrs 10 "The variable(s) ~S declared TYPE OSS in a letS{*}."
	 (cddadr (car forms))))
  (pop forms)
  (let ((dcls (process-subforms-&-rename (cdr (pop forms))))
	(frag (process-progns forms)))
    (setf (dcls frag) (append dcls (dcls frag))) ;assumes outputs never renamed
    (dolist (entry alist)
      (when (null (nxts (cdr entry)))
	(wrs 11 "The letS variable ~A is unused in:~%~A" (car entry) call)))
    frag))

(defun process-subforms-&-rename (forms)
  (mapcar #'rename (process-subforms forms)))

(defun rename (form)
  (m-&-r form #'(lambda (c) (if (sym-p c) (var c) c))))

(defmacroS lambdaS (var-list &body expr-list)
    "Form for specifying literal OSS functions."
    (declare (ignore var-list expr-list))
  (ers 6 "LambdaS used in inappropriate context:~%~S" +call+))

(defun process-lambdas (call lambdas)
  (starting-oss-expr call
    (let* ((arglist (cadr lambdas))
	   (forms (normalize-dcls (cddr lambdas)))
	   (oss-vars (cddadr (pop forms)))
	   (dcl (pop forms))
	   (arg-frag-rets
	    (mapcar
	     #'(lambda (a)
		 (when (not (lambda-variable-p a))
		   (ers 5 "Malformed lambdaS argument ~S." a))
		 (let* ((ret (make-sym
			      :var (gensym "ARG-")
			      :oss-var-p (not (null (member a oss-vars)))))
			(arg-frag (make-frag)))
		   (+ret ret arg-frag)
		   (push (cons a ret) *renames*)
		   ret))
	     arglist))
	   (frag (mergify (graphify `(prognS . ,forms)))))
      (setf (args frag)  ;get into the right order.
	    (mapcar #'handle-arg arg-frag-rets))
      (setf (dcls frag) (append (process-subforms-&-rename (cdr dcl))
				(dcls frag)))
      frag)))

(defun handle-arg (ret)
  (let ((arg (car (nxts ret))))
    (when (null arg) (setq arg ret))  ;input never used 
    (setf (prv arg) nil)
    (dolist (a (cdr (nxts ret)))      ;input used more than once.
      (nsubst (var arg) (var a) (fr a)))
    arg))

(defun normalize-dcls (forms &optional (allow-doc nil))
  (let ((doc nil) (oss-vars nil) (others nil))
    (prog ()
        L (when (and allow-doc (null doc) (stringp (car forms)) (cdr forms))
	    (setq doc (pop forms)) (go L))
	  (when (not (eq-car (car forms) 'declare)) (return nil))
	  (dolist (d (cdr (pop forms)))
	    (if (and (eq-car d 'type) (listp (cdr d)) (symbolp (cadr d))
		     (string-equal (string (cadr d)) "OSS"))
		(setq oss-vars (append (cddr d) oss-vars))
		(push d others)))
       (go L))
    `(,@(if doc (list doc))
      (declare (type oss . ,oss-vars))
      (declare . ,others)
      . ,forms)))

(defmacro defunS (name lambda-list
		  #-:GCLISP &environment #-:GCLISP *env*
		  &body expr-list)
    "Defines an OSS function, see LAMBDAS."
  (let ((call (list* 'defunS name lambda-list expr-list)))
    (top-starting-oss-expr call
      (dolist (v lambda-list)
	(when (and (member v lambda-list-keywords)
		   (not (member v '(&optional &key))))
	  (ers 3 "Unsuported &-keyword ~S in defunS arglist." v)))
      (let ((vars nil) (rev-arglist nil))
	(dolist (a lambda-list)
	  (cond ((member a lambda-list-keywords) (push a rev-arglist))
		(T (setq a (iterative-copy-tree a))
		   (setq vars (append vars (vars-of a)))
		   (if (and (listp a) (listp (cdr a)))
		       (setf (cadr a) `(copy-tree ',(cadr a))))
		   (push a rev-arglist))))
	(setq expr-list (normalize-dcls expr-list T))
	`(defmacroS ,name ,(reverse rev-arglist)
	   ,@(if (stringp (car expr-list)) (list (pop expr-list)))
	   (funcallS-frag
	     (list->frag
	       ',(frag->list
		   (process-lambdas call `(lambdaS ,vars . ,expr-list))))
	     (list . ,vars)))))))

(defun vars-of (arg)
  (cond ((member arg lambda-list-keywords) nil)
	((not (consp arg)) (list arg))
	(T (cons (if (consp (car arg)) (cadr arg) (car arg))
		 (copy-list (cddr arg))))))

;note the following does not assume that old and new are series
;(implicit mapping will happen if they are).  Also the alterS form found
;probably refers to vars which are not OLD itself.  This is ok because outputs
;never get renamed.  Also the input old to the frag most likely never
;gets used, but this makes sure that the dflow is logically correct.

;It is vital that this doesn't put the setf in the frag, because it is 
;important that the setf get combined with any IF or other form it is 
;nested in when implicit mapping happens.

;This makes the right annotation, because it does not expand into a
;frag.  As a result, instantiate-non-oss always ends up getting called
;around it and makes the right annotation.

(defmacroS alterS (destinations items) ;fix so can be top level
    "Alters the values in DESTINATIONS to be ITEMS."
  (let ((ret (retify destinations)))
    (let ((form (find-alter-form ret)))
      (when (null form)
	(ers 4 "AlterS applied to an unalterable form:~%~S" +call+))
      `(setf ,form
	     ,(annotate +call+
	        (funcallS-frag
	          (literal-frag  ;this gets the data flow dependencies right.
		    `(((old) (items)) ((items)) () () () () () () ()))
	          (list ret items)))))))

(defun find-alter-form (ret)
  (let* ((v (var ret))
	 (form (cadr (assoc v (alterable (fr ret))))))
    (if form form
	(dolist (a (args (fr ret)))
	  (when (or (eq v (var a))
		    (equal (prolog (fr ret)) `((setq ,v ,(var a)))))
	    (return (find-alter-form (prv a))))))))

;                         MERGING A GRAPH

;this proceeds in three phases
; (1) Implicit mapping and the like to fix type conflicts.
;     (a) find all non-series functions which must be mapped.
;     (b) signal error if there is a non-fixable oss/non-oss type conflict.
;     (c) Insert (Eoss :R ...) where needed to fix non-oss/oss type conflicts.
; (2) doing substitutions to get rid of trivial frags and improve the code.
; (3) the graph is scanned to find a dflow which should be isolated.
;     when one is found, the graph is split at this point.  The two
;     subgraphs are merged separately and then combined.  If the graph
;     cannot be split, then it consists solely of on-line dflow and can be
;     easily merged.  

(defun mergify (*graph*)
  (reset-marks)
  (do-coercion)
  (do-substitution)
  (eval (do-splitting *graph*)))

;takes advantage of the fact that frags are ordered consistently
;with the dflow so an implicit mapping of one fn cannot force earlier
;functions to be mapped.

(defun do-coercion ()
  (dofrags (f)
    (when (and (non-oss-p f)
	       (some #'(lambda (r) (oss-var-p r)) (all-prvs f)))
      (implicit-map f))
    (dolist (a (args f)) ;if map might have to map only some args.
      (let ((ret (prv a)))
	(cond ((and (not (oss-var-p ret)) (oss-var-p a))
	       (Eoss-coerce a))
	      ((and (oss-var-p ret) (not (oss-var-p a)))
	       (ers 14 "OSS value carried to non-OSS input ~
                        by data flow from:~%~S~%to:~%~S"
		    (code (fr ret)) (code f))))))
    (maybe-de-oss f))) ;might have to if Eoss coerced all of the inputs

(defun implicit-map (frag)
  (setf (body frag) (prolog frag))
  (setf (prolog frag) nil)
  (dolist (a (args frag)) (setf (oss-var-p a) T))
  (dolist (r (rets frag)) (setf (oss-var-p r) T))
  frag)

(defun Eoss-coerce (a)
  (when (off-line-spot a)
    (nsubst nil (off-line-spot a) (fr a)))
  (setf (oss-var-p a) nil))

;choose not to automatically map subexprs because it helps detect bugs,
;and doesn't take away much you want to do.

(defun do-substitution ()
  (dofrags (f)
    (multiple-value-bind (subable code) (substitutable-source f)
      (when subable
	(let* ((ret (car (rets f)))
	       (killable (not (null (nxts ret)))))
	  (dolist (arg (nxts ret))
	    (cond ((substitutable-destination ret arg code)
		   (nsubst code (var arg) (fr arg))
		   (-dflow ret arg)
		   (-arg arg))
		  (T (setq killable nil))))
	  (if killable (-frag f)))))))

(defun substitutable-source (f &aux code fn-type)
  (values (and (= (length (rets f)) 1)
	       (not (off-line-spot (car (rets f))))
	       (null (args f))
	       (null (epilog f))
	       (= 1 (length (setq code (append (prolog f) (body f)))))
	       (eq (var (car (rets f))) (setq-p (setq code (car code))))
	       ;;cheap check for free vars not bound in destination
	       (or (constantp (setq code (caddr code))) (symbolp code)
		   (and (setq fn-type (quoted-function-p code))
			(or (eq fn-type 'symbol)
			    (let ((free-var nil)
				  (*renames* nil)
				  (*in-oss-expr* nil))
			      (m-&-r (cadr code)
				     #'(lambda (c)
					 (when (and (variable-p c)
						    (not (assoc c *renames*)))
					   (push c free-var))
					 c))
			      (null free-var))))))
	  code))

(defun substitutable-destination (ret arg code)
  (not (or (off-line-spot arg)
	   (contains-p (list (var arg)) (rets (fr arg)))
	   ;;prevents weird declarations from appearing
	   (contains-p (list (var arg)) (dcls (fr arg)))
	   ;;cheap check for not binding
	   (and (variable-p code) (contains-p (list code) (cddr (fr arg))))
	   (not (or (numberp code) (null code) (eq code T) (symbolp code)
		    (and (null (cdr (nxts ret)))
			 (not-contained-twice (list (var arg))
					      (list (prolog (fr arg))
						    (body (fr arg))
						    (epilog (fr arg))))))))))

;Splitting cuts up the graph at all of the correct places, and creates a
;lisp expression which, when evaluated will merge everything together.
;Things area done this way so that all of the splitting will happen
;before any of the merging.  This makes error messages better and allows
;all the right code motion to happen easily.    
;  A throw is used to start all over again when recovering from an
;error, because it can be essential to restart from the top so that
;disconnected splitting will happen soon enough

(defun do-splitting (*graph*)
  (loop
    (reset-marks 0)
    (let ((result nil) (error nil))
      (setq error (catch :split
		    (setq result (non-oss-split *graph*))
		    nil))
      (when (not error) (return result))
      (case (car error)
	(:isolation
	  (make-port-isolated (cadr error) (caddr error)))
	(:connection
	  (make-disconnected (caddr error)))))))

;This takes a ret which is known not to be isolated and duplicates 
;code in order to make the ret be isolated.  In simple situations 
;it does a pretty good job of duplicating minimum code.

(defun make-port-isolated (ret args)
  (reset-marks 0)
  (let ((to-follow (list (fr ret))))
    (mark 2 (fr ret))
    (loop (if (null to-follow) (return nil))
	  (let ((frag (pop to-follow)))
	    (dolist (a (args frag))
	      (let ((r (prv a)))
		(when (not (marked-p 2 (fr r)))
		  (push (fr r) to-follow)
		  (mark 2 (fr r))))))))
  (let ((to-follow (mapcar #'(lambda (a) (fr a)) args))
	(followers nil) (*copied* nil))
    (declare (special *copied*))
    (loop (if (null to-follow) (return nil))
	  (let ((frag (pop to-follow)))
	    (when (not (marked-p 4 frag))
	      (mark 4 frag)
	      (push frag followers))
	    (dolist (r (rets frag))
	      (dolist (a (nxts r))
		(push (fr a) to-follow)))))
    (setq to-follow followers)
    (loop (if (null to-follow) (return nil))
	  (let ((frag (pop to-follow)))
	    (dolist (a (args frag))
	      (when (and (oss-var-p a) (not (member a args)))
		(let ((r (prv a)))
		  (when (not (marked-p 4 (fr r)))
		    (when (marked-p 2 (fr r))
		      (setq r (duplicate-frag r a)))
		    (push (fr r) to-follow)
		    (mark 4 (fr r))))))))))

(defun duplicate-frag (ret arg)
  (declare (special *copied*))
  (let* ((frag (fr ret)) new-frag new)
    (when (not (setq new-frag (cdr (assoc frag *copied*))))
      (setq new-frag (copy-fragment frag))
      (push (cons frag new-frag) *copied*)
      (let ((spot (member frag *graph*)))
	(rplacd spot (cons new-frag (cdr spot))))
      (mapc #'(lambda (old-arg new-arg)
		(+dflow (prv old-arg) new-arg))
	    (args frag)
	    (args new-frag)))
    (mapc #'(lambda (old-ret new-ret)
	      (when (eq old-ret ret)
		(setq new new-ret)
		(dolist (a (nxts old-ret))
		  (when (eq a arg)
		    (-dflow old-ret arg)
		    (+dflow new-ret arg)
		    (when (null (nxts old-ret))
		      (kill-ret old-ret))))))
	  (rets frag)
	  (rets new-frag))
    new))

;This is prone to copying much too much.

(defun make-disconnected (frag)
  (reset-marks 0)
  (let ((to-follow (list frag)) (preceders nil) (*copied* nil))
    (declare (special *copied*))
    (loop (if (null to-follow) (return nil))
	  (let ((frag (pop to-follow)))
	    (dolist (a (args frag))
	      (when (oss-var-p a)
		(let ((r (prv a)))
		  (when (not (marked-p 2 (fr r)))
		    (push (fr r) to-follow)
		    (mark 2 (fr r))))))))
    ;;preceders ends up in reverse dflow order
    (dofrags (f 2) (push f preceders))
    (mark 2 frag)
    (dolist (f preceders)
      (dolist (r (rets f))
	(when (oss-var-p r)
	  (dolist (a (nxts r))
	    (when (not (marked-p 2 (fr a)))
	      (duplicate-frag r a))))))))

(eval-when (eval load compile)
(defmacro doing-splitting (&body body)
  `(cond ((null (cdr *graph*)) (list 'quote (car *graph*)))
	 (T (reset-marks 1) (prog1 (progn . ,body) (reset-marks 0))))) )

;This breaks the expression up at points where there is no data flow
;between the subexpressions.  Since the size of part1 is minimized it is
;known that it must be fully connected.
; This is called at several different points, in order to guaranttee that
;as much disconnected splitting as possible is always done before off line
;splitting is done.  This also ensures that there cannot be any disconnected 
;pieces when check-connected is called.
;  This is called so often because it makes the eventual merging much
;better.  In particular, the following expression cannot be merged
;correctly at all unless the off-line outputs are merge BEFORE the
;disconnected chuncks are merged.

;(lets* ((e1 (Elist '(1 -2 -4 3)))
;	 (e2 (Elist '(1 -2 -4 3)))
;	 (e3 (Elist '(1 -2 -4 3)))
;	 (w1 (TsplitF e2 #'plusp))
;	((nil x2) (TsplitF e3 #'plusp)))
;  (list (Rlist (list e1 w1)) (Rlist (list w1 x2))))

;it is not at all easy to explain why this is the case.  However, in
;this example the key problem is that an output ends up getting used two
;ways, once off-line and once not.  Doing disconnected splitting early
;may not even fix the problem in general.  However, it is just possible
;that the all termination points must connect to all outputs condition
;actually makes things work out ok.

(defun disconnected-split (next *graph*)
  (doing-splitting
    (multiple-value-bind (part1 part2)
        (split-after (list (car *graph*))
		     #'(lambda (r a) (declare (ignore r a)) nil))
      (cond ((null part2) (funcall next part1))	
	    (T `(no-dflow-merge ,(funcall next part1)
				,(disconnected-split next part2)))))))

;This finds internal non-oss dflows and splits the graph at that point.
;If *graph* is a complete expression, then the two subexpressions cannot
;have external series inputs or outputs.  The size of part2 is minimized
;because it is felt that this will do a better job of equalizing the
;size of the two halves.  However, this can cause part1 to have
;disconnected parts.  Also, either half can contain more non-oss dflow.
;Therefore, both halves must be processed again by non-oss-split.

(defun non-oss-split (*graph*)
  (doing-splitting
    (block top
      (dofrags (f)
	(dolist (ret (rets f))
	  (when (not (oss-var-p ret))
	    (dolist (arg (nxts ret))
	      (when (marked-p 1 (fr arg))
		(return-from top (do-non-oss-split ret arg)))))))
      (disconnected-split #'off-line-input-split *graph*))))

(defun do-non-oss-split (ret arg)
  (let ((frag1 (fr ret))
	(frag2 (fr arg)))
    (multiple-value-bind (part1 part2)
        (split-before (list frag2)
		      #'(lambda (r a)
			  (declare (ignore r))
			  (not (oss-var-p a))))
      (when (member frag1 part2)
	(wrs 16 "Non-isolated non-oss data flow from:~%~S~%to:~%~S"
	     (code frag1) (code frag2))
	(throw :split `(:isolation ,ret ,(nxts ret))))
      `(non-oss-merge ,(non-oss-split part1)
		      ,(non-oss-split part2)))))

;This looks for data flows going to off-line input ports.  When
;splitting, it minimizes part1 so that the stuff that gets substituted
;in line will be as small as possible.  Either part can still have off-line
;inputs in it.  (Part1 may have to include some frags not yet scanned.)
;  Note that even if the whole does not have any external oss ports, the
;two pieces will.  Part2 will have an external off-line input (the one
;split on) and part1 will have an oss output which may be on-line.
;(It is possible that this output is used by a second off-line input
;<which is now still in part1 also> this forces complex merging cases
;to be handled.)
;  Note dflow can fan out, but not fan in.  For this reason, it is
;imperative that off-line inputs be split on before off-line outputs.
;Otherwise, one could fail to realize that an off-line input was not
;isolated.  (It is very convenient the way that error checking works out.)
;Also note that since there is no fan in, input-splitting cannot cause
;either part to become disconnected. 

(defun off-line-input-split (*graph*)
  (doing-splitting
    (block top
      (dofrags (f)
	(dolist (ret (rets f))
	  (dolist (arg (nxts ret))
	    (when (and (marked-p 1 (fr arg)) (off-line-spot arg))
	      (return-from top (do-off-line-input-split ret arg))))))
      (off-line-output-split *graph*))))

(defun do-off-line-input-split (ret arg)
  (let ((frag1 (fr ret))
	(frag2 (fr arg)))
    (multiple-value-bind (part1 part2)
	(split-after (list frag1)
		     #'(lambda (r a)
			 (and (eq r ret) (eq a arg))))
      (when (member frag2 part1)
	(wrs 17.1 "Non-isolated oss input at the end of the ~
		   data flow from:~%~S~%to:~%~S"
	     (code frag1) (code frag2))
	(throw :split `(:isolation ,ret ,(list arg))))
      `(off-line-merge ,(off-line-input-split part1) ',ret
		       ,(off-line-input-split part2) ',arg))))


;This looks for data flows going from off-line output ports.  When
;splitting, it minimizes part2 so that the stuff that gets substituted
;in line will be as small as possible.  This insures that part2 will be
;a connected piece.  However, part1 may not be.  (This means that on
;calls of this function, it cannot be assumed that the whole expression
;is connected.  This is a reason why it is vital to minimize part2.)
;Either half can have more off-line outputs in it.
;  Note that even if the whole does not have any external oss ports, the
;two pieces will.  Part1 will have an external off-line output (the one
;split on) and part2 will have an on-line oss input.

(defun off-line-output-split (*graph*)
  (doing-splitting
    (block top
      (dofrags (f)
	(dolist (ret (rets f))
	  (when (off-line-spot ret)
	    (let ((args nil))
	      (dolist (arg (nxts ret))
		(when (marked-p 1 (fr arg))
		  (pushnew arg args)))
	      (when args 
		(return-from top (do-off-line-output-split ret args)))))))
      (check-connected *graph*))))

(defun do-off-line-output-split (ret args)
  (let ((frag1 (fr ret))
	(frags2 (mapcar #'(lambda (a) (fr a)) args)))
    (multiple-value-bind (part1 part2)
	(split-before frags2 #'(lambda (r a)
				 (declare (ignore a))
				 (eq r ret)))
      (when (member frag1 part2)
	(wrs 17.2 "Non-isolated oss output at the start of the ~
		          data flow from:~%~S~%to:~%~S"
	     (code frag1) (code (car frags2)))
	(throw :split `(:isolation ,ret ,(nxts ret))))
      `(off-line-merge
	 ,(disconnected-split #'off-line-output-split part1)
	 ',ret
	 ,(disconnected-split #'off-line-output-split part2)
	 ',(car args)))))

;This function checks that there is a dflow path from every termination
;point to every output of an on-line subexpression.  It works by doing
;some fancy marker propagation.

(defun check-connected (*graph*)
  (doing-splitting
    (let ((counter 8.) (all-counters 0) (outputs nil) (terminations nil))
      (dofrags (f 1)
	(when (or (null (rets f))
		  (some #'(lambda (a) (not (marked-p 1 (fr a))))
			(all-nxts f)))
	  (push f outputs))
	(when (or (active-terminator-p f)
		  (some #'(lambda (r)
			    (and (not (marked-p 1 (fr r))) (oss-var-p r)))
			(all-prvs f)))
	  (push (cons counter f) terminations)
	  (mark (+ 4 counter) f)
	  (setq all-counters (+ all-counters counter))
	  (setq counter (* 2 counter))))
      (dofrags (f 5)				; 5 = 1+4
	(let ((current-marks (logand -4 (marks f))))
	  (dolist (a (all-nxts f))
	    (when (marked-p 1 (fr a))
	      (mark current-marks (fr a))))))
      (dolist (output outputs)
	(when (not (marked-p all-counters output))
	  (dolist (entry terminations)
	    (when (not (marked-p (car entry) output))
	      (wrs 18 "No data flow path from the termination point: ~%~S~%~
                     to the output:~%~S" (code (cdr entry)) (code output))
	      (throw :split `(:connection ,(cdr entry) ,output)))))))
    `(merge-on-line ',*graph*)))

;This splits the graph by dividing it into two parts (part1 and part2)
;so that to-follow is in part1, there is no data flow from part2 to
;part1 and all of the data flow from part1 to part2 satisfies the
;predicate CROSSABLE.    
;  The splitting is done by marker propogation (using the marker 2).
;The algorithm used has the effect of minimizing part1.

(defun split-after (to-follow crossable)
  (dolist (f to-follow) (mark 2 f))
  (loop (if (null to-follow) (return nil))
	(let ((frag (pop to-follow)))
	  (dolist (a (args frag))
	    (let ((r (prv a)))
	      (when (= (marks (fr r)) 1) ;ie 1 but not 2
		(push (fr r) to-follow)
		(mark 2 (fr r)))))
	  (dolist (r (rets frag))
	    (dolist (a (nxts r))
	      (when (and (= (marks (fr a)) 1) ;ie 1 but not 2
			 (not (funcall crossable r a)))
		(push (fr a) to-follow)
		(mark 2 (fr a)))))))
  (let ((part1 nil) (part2 nil))
    (dofrags (f 1)
      (if (marked-p 2 f) (push f part1) (push f part2)))
    (reset-marks 0)
    (values (nreverse part1) (nreverse part2))))

;This is almost exactly the same except propogation starts in part2 and part2
;is the part that is minimized.

(defun split-before (to-follow crossable)
  (dolist (f to-follow) (mark 2 f))
  (loop (if (null to-follow) (return nil))
	(let ((frag (pop to-follow)))
	  (dolist (a (args frag))
	    (let ((r (prv a)))
	      (when (and (= (marks (fr r)) 1) ;ie 1 but not 2
		         (not (funcall crossable r a)))
		(push (fr r) to-follow)
		(mark 2 (fr r)))))
	  (dolist (r (rets frag))
	    (dolist (a (nxts r))
	      (when (= (marks (fr a)) 1) ;ie 1 but not 2
		(push (fr a) to-follow)
		(mark 2 (fr a)))))))
  (let ((part1 nil) (part2 nil))
    (dofrags (f 1)
      (if (not (marked-p 2 f)) (push f part1) (push f part2)))
    (reset-marks 0)
    (values (nreverse part1) (nreverse part2))))

;  When it comes to merging a pair of fragments together, there are four
;basic situations based on the data flow between the frags chosen
;  1- non-oss  2- no data flow  3- off-line  4- on-line.
;In the first three cases, things are arranged so that there is never
;any data flow except between the two fragments in question.  In the
;fifth case, there can be other data flow, but it must be on-line
;data flow.  A problem stems from the fact that there can be ports on
;the segments to which no internal data flow is attached---i.e., ports which
;are inputs and outputs of the expression as a whole or ports which
;are inputs and outputs of subexpressions created in earlier splittings
;of the graph.  Even worse, for outputs, there can be additional data
;flow which goes to a frag in a different subexpression even though
;the output is also used in this subexpression.  (The way things are
;split this can only happen with oss outputs.)  Combining the frags
;together can require exterenally used oss ports to be modified.
;  Two cases are always simple.  If an extraneous input or output
;carries a non-series value, then there is never a problem.  If it is
;an input than it must be available from the very start of computation
;and therefore will always be readable no matter how the frags are
;combined.  If the port is an output, then it does not need to be
;available until after everything is done, and the strongly connected
;check insures that it will be eventually computed.
;  Things are also basically simple if an extraneous input or output is
;off-line.  In this situation, a specific marker says exactly where
;connected computation should be put, and this marker will always end
;up in an appropriate place no matter how the fragments are combined.
;The only thing which requires care is making sure that these
;markers stay at top level.  
;  One problem case however, is that it is possible for an off-line
;output to be used by an off-line input.  This can cause a splitting
;to happen that ends up in a situation where an off-line input is used
;both internally and externally.  If so, the output has to be
;preserved the first time it is used so that it can be used again.
;  On the other hand, if an extraneous input or output is on-line,
;significant complexities can arise.  If an extraneous port is
;on-line then it may have to be changed into an off-line port.
;Fortunately, things are arranged so that a graph is never split by
;breaking an on-line to on-line data flow.  However, an on-line port
;can be on one end of a broken data flow.  Nevertheless, most
;instances of extranious on-line ports come from weird lambdaS bodies.
;Except in simple situations extranious on-line ports are not
;supported unless they come from complete expressions.
;  A key goal of the above is that every situation which can arise in
;a complete oss expression is properly dealt with.  Beyond this
;certain weird situations in lambdaSs are dealt with while others
;generate error messages.  You have to use the primitive definition
;facilities in this situation.  (It should be noted that basically all of
;the problem cases in question are really quite rare indeed.)

;    Consider the various problematical situations in detail
;  1- the frags to be combined are connected by non-oss dflow.
;The way graph splitting works insures that in a complete expression,
;both frags must be non-oss.  There is no problem as long as at least
;one of the frags is non-oss.  If one has series ports, it can be left totally
;alone.  The other can be placed entirely in the prolog or epilog.
;The case of one non-oss frag is handled because it comes up often in
;lambdaS's and is easy to handle.
;  If both frags have series ports, then the ports on one of the frags would
;have to become off-line.  (A problem here is that it is not obvious
;which frag to do this to.)  An error message is issued rather than
;make the combination.

(defun non-oss-merge (ret-frag arg-frag)
  (when (not (non-oss-p ret-frag))
    (when (not (non-oss-p arg-frag))
      (ers 19 "LambdaS body too complex to merge into a single unit:~%~S~%~S"
	   (code ret-frag) (code arg-frag)))
    (implicit-epilog arg-frag))
  (handle-dflow ret-frag
    #'(lambda (r a)
	(and (eq (fr r) ret-frag) (eq (fr a) arg-frag))))
  (merge-frags ret-frag arg-frag))

(defun implicit-epilog (frag)
  (setf (epilog frag) (prolog frag))
  (setf (prolog frag) nil)
  frag)

;  2- There is no data flow between the frags.  
;The way graph splitting works insures that in a complete expression,
;both frags must be non-oss.  As in the case above, there is no problem
;as long as at least one of the frags is non-oss.  Beyond that, since
;there is no data flow between the frags, things are still fine.
;(Non-oss and off-line are never a problem, and on-line inputs and
;outputs will run along nicely in phase when the frags are merged side
;by side.) 

(defun no-dflow-merge (frag1 frag2)
  (merge-frags frag1 frag2))

;  3- the frags to be combined are connected by an off-line dflow.
;(This may be from an on-line or off-line output to an on-line or
;off-line input.)  Here things are quite complicated as indicated below.
;  A- The ret is off-line and the arg is on-line
;There are two basic ways in which this can be handled.  
; A1- The most straightforward way is to insert the arg frag into the
;off-line-spot in the ret-frag.  This has the feature that it is very
;simple and allows on-line inputs and outputs of the ret-frag
;to remain unchanged.  However, on-line inputs and outputs of the
;arg-frag are forced to become off-line.
; A2- The ret-frag is turned inside out and converted into an
;enumerator, which has on-line data flow to the arg-frag.  This
;requires the use of a flag variable, and the makinf off-line of any
;on-line inputs or outputs of the ret-frag.  However, it allows any
;extraneous inputs and outputs of the arg-frag to remain unchanged.
; If either of the two frags has no extraneous on-line ports, then the
;appropriate combination method above is used and everything works
;out great.  If they both have extraneous on-line ports, then which
;every one has fewer of these ports has them changed to off-line
;ports and the appropriate process above is then applied.
;  In either case, special care has to be taken to insure that the
;off-line output will still exist if it is used someplace other than
;in the arg-frag.  (It is possible that it will exist, but will get
;changed to on-line.  This does not cause confusion since the input it
;is connected to must be off-line, or the splitting which caused the
;difficultly in the first place would not have occured.)
;  B- The ret is on-line and the arg is off-line.  This case is
;closely analogous to the one above.  Again, there are two basic ways
;to proceed. 
; B1- The most straightforward way is to insert the ret frag into the
;off-line-spot in the arg-frag.  This has the feature that it is very
;simple and allows all on-line inputs and outputs of the arg-frag
;to remain unchanged.  However, on-line inputs and outputs of the
;ret-frag are forced to become off-line.
; B2- The arg-frag is turned inside out and converted into a
;reducer which receives on-line data flow from the ret-frag.  This
;requires the use of a flag variable, and it forces off-line any
;extraneous on-line inputs or outputs of the arg-frag.  However, it allows any
;extraneous inputs and outputs of the ret-frag to remain unchanged.
; If either of the two frags has no extraneous ports, then the
;appropriate combination method above is used and everything works
;out great.  If the both have extraneous ports then which every has
;fewer has them changed to off-line and things proceed as above.
;  C- the ret and arg are both off-line.  Here it is
;not possible to simultaneously substitute the frags into each other.
;However, it is possible to combine them after A2 is applied to the
;ret-frag or B2 is applied to the arg-frag.  Again this presents two
;options and it is possible to preserve either the extraneous ports of
;the ret-frag or the arg-frag, but not both.
;  Note we have to be prepared for the general case more often than you might
;think, because the compination process can cause ports to become off-line

(defun off-line-merge (ret-frag ret arg-frag arg) 
  (handle-dflow (fr ret)
		#'(lambda (r a)
		    (eq r ret) (eq (fr a) arg-frag)))
  (let* ((ret-rating (count-on-line ret-frag))
	 (arg-rating (count-on-line arg-frag)))
    (cond ((not (off-line-spot arg))
	   (if (> arg-rating ret-rating)
	       (convert-to-enumerator ret nil)
	       (substitute-in-output ret arg)))
	  ((not (off-line-spot ret))
	   (if (and (> ret-rating arg-rating) (null (off-line-exit arg)))
	       (convert-to-reducer arg)
	       (substitute-in-input ret arg)))
	  (T (cond ((and (> ret-rating arg-rating) (null (off-line-exit arg)))
		    (convert-to-reducer arg)
		    (substitute-in-output ret arg))
		   (T (convert-to-enumerator ret (off-line-exit arg))
		      (substitute-in-input ret arg))))))
  (maybe-de-oss (merge-frags ret-frag arg-frag)))

(defun find-on-line (syms)
  (do ((s syms (cdr s)) (r nil))
      ((null s) (nreverse r))
    (when (and (oss-var-p (car s)) (null (off-line-spot (car s))))
      (push (car s) r))))

(defun count-on-line (frag)
  (+ (length (find-on-line (args frag))) (length (find-on-line (rets frag)))))

(defun substitute-in-output (ret arg)
  (let ((ret-frag (fr ret)) (arg-frag (fr arg)))
    (make-ports-off-line arg-frag (off-line-exit arg))
    (setf (body ret-frag)
	  (nsubst-inline (body arg-frag) (off-line-spot ret) (body ret-frag)
			 (nxts ret)))
    (setf (body arg-frag) nil)))

(defun substitute-in-input (ret arg)
  (let ((ret-frag (fr ret)) (arg-frag (fr arg)))
    (make-ports-off-line ret-frag (off-line-exit arg))
    (when (off-line-exit arg)
      (dolist (a (args (fr ret)))
        (if (and (oss-var-p a) (not (off-line-exit a)))
	    (setf (off-line-exit a) (off-line-exit arg))))
      (nsubst (off-line-exit arg) `END (body ret-frag)))
    (setf (body arg-frag)
	  (nsubst-inline (body ret-frag) (off-line-spot arg) (body arg-frag)))
    (setf (body ret-frag) nil)))

(defun nsubst-inline (new-list old list &optional (save-spot nil))
  (let ((tail (member old list)))
    (cond (save-spot (rplacd tail (nconc new-list (cdr tail))))
	  (new-list (rplaca tail (car new-list))
		    (rplacd tail (nconc (cdr new-list) (cdr tail))))
	  ((cdr tail) (rplaca tail (cadr tail))
	              (rplacd tail (cddr tail)))
	  (T (setq list (nbutlast list)))))
    list)

(defun make-ports-off-line (frag off-line-exit)
  (make-inputs-off-line frag off-line-exit)
  (make-outputs-off-line frag))

(defun make-outputs-off-line (frag)
  (dolist (out (find-on-line (rets frag)))
    (let ((-X- (gensym "-X-")))
      (setf (off-line-spot out) -X-)
      (setf (body frag) `(,@(body frag) ,-X-)))))

(defun make-inputs-off-line (frag off-line-exit)
  (dolist (in (find-on-line (args frag)))
    (let ((-X- (gensym "-X-")))
      (setf (off-line-spot in) -X-)
      (setf (off-line-exit in) off-line-exit)
      (setf (body frag) `(,-X- . ,(body frag))))))

(defun convert-to-enumerator (ret off-line-exit)
  (let ((frag (fr ret)))
    (make-ports-off-line frag off-line-exit) 
    (let* ((tail (member (off-line-spot ret) (body frag)))
	   (head (ldiff (body frag) tail))
	   (flag (gensym "FLAG-"))
	   (E (gensym "E-")))
      (setf (off-line-spot ret) nil)
      (cond ((null (cdr tail)) (setf (body frag) head))
	    (T (push flag (aux frag))
	       (push `(setq ,flag nil) (prolog frag))
	       (setf (body frag)
		     `((when (null ,flag) (setq ,flag T) (go ,E))
		       ,@(cdr tail)
		       ,E . ,head)))))
    frag))

(defun convert-to-reducer (arg)
  (let ((frag (fr arg)))
    (make-outputs-off-line frag)
    (let* ((tail (member (off-line-spot arg) (body frag)))
	   (head (ldiff (body frag) tail))
	   (flag (gensym "FLAG-"))
	   (M (gensym "M-"))
	   (N (gensym "N-")))
      (push flag (aux frag))
      (push `(setq ,flag nil) (prolog frag))
      (setf (body frag)
	    `((if (null ,flag) (go ,M))
	  ,N ,@(cdr tail)
	  ,M ,@head
	      (when (null ,flag) (setq ,flag T) (go ,N)))))
    frag))

;  4- The frags to be combined are connected by on-line data flow.
;here things are complicated because there can be a lot of frags.
;All of the internal data flow must be on-line.  There may well be
;external on-line inputs and outputs.  There may also be on-line
;outputs which are used both internally and externally.  There may
;also be external off-line ports, but they cannot be used internaly.
;However, all of this is no problem.  All of the on-line ports will
;stay on-line and the same for the off-line ones.  The only which one
;has to be careful about is making sure that an on-line port which is
;used both internaly and externally does not go away.

(defun merge-on-line (*graph*) ;merge everything, all dflow is on-line.
  (let ((frag nil))
    (dofrags (f)
      (handle-dflow f
	#'(lambda (r a) (declare (ignore r))
	    (member (fr a) *graph*)))
      (if (not frag) (setq frag f) (setq frag (merge-frags frag f))))
    (maybe-de-oss frag)))

;This is used for the variable renaming part of all kinds of dflow.
;rets must be saved either if they have no dflow from them (they are
;outputs of the whole top level expression) or if there is a dflow to
;a frag which is not currently being dealt with.

(defun handle-dflow (source allowable-p)
  (dolist (ret (rets source))
    (let ((ret-killable (not (null (nxts ret)))))
      (dolist (arg (nxts ret))
	(cond ((not (funcall allowable-p ret arg)) (setq ret-killable nil))
	      (T (nsubst (var ret) (var arg) (fr arg))
		 (-dflow ret arg)
		 (-arg arg))))
      (if ret-killable (-ret ret)))))

;                        TURNING A FRAG INTO CODE

;this takes a non-oss frag and makes it into a garden variety chunk of code.
;It assumes that it will never be called on a frag with an oss input.

(defun codify (frag)
  (if *oss-tutorial-mode* (allow-oss-outputs frag))
  (dolist (r (rets frag))
    (if (oss-var-p r) (-ret r)))
  (maybe-de-oss frag)
  (let ((rets (mapcar #'(lambda (r) (var r)) (rets frag)))
	(aux (aux frag))
	(code (prolog frag)))
    (when (wrappers frag)
      (if (cdr code) (setq code (cons 'progn code)) (setq code (car code)))
      (dolist (wrp (wrappers frag))
	(setq code (funcall (eval wrp) code)))
      (setq code (list code)))
    (if (and rets (null (cdr rets)))
	(setq rets (car rets))
	(setq rets `(values . ,rets)))
    (setq code (nconc code (list rets)))
    (multiple-value-setq (aux code) (clean-code aux code))
    (setq aux (sort aux #'(lambda (a b) (string-lessp (string a) (string b)))))
    (if (dcls frag) (push `(declare . ,(clean-dcls aux (dcls frag))) code))
    (setq code `(let ,aux . ,code))
    (use-user-names aux code)
    (setq *last-oss-loop* code)))

(defun use-user-names (aux loop)
  (let ((alist nil))
    (dolist (v aux)
      (let ((u (cdr (assoc v *user-names*))))
	(if (and u (not (contains-p (list u) loop)) (not (rassoc u alist)))
	    (push (cons v u) alist))))
    (if alist (nsublis alist loop))))

;this takes an oss frag all of whose inputs and outputs are non-oss
;things and makes it into a non-oss frag.

(defun maybe-de-oss (frag)
  (when (and (non-oss-p frag) (or (body frag) (epilog frag)))
    (when (not (or *permit-non-terminating-oss-expressions*
		   (active-terminator-p frag)))
      (wrs 15 "Non-terminating OSS expression:~%~S" (code frag)))
    (let ((lab (gensym "L-")))
      (setf (prolog frag)
	    `((tagbody ,@(prolog frag)
		       ,lab ,@(body frag) (go ,lab)
		    END ,@(epilog frag)))))
    (setf (body frag) nil)
    (setf (epilog frag) nil)
    (clean-labs frag (cdar (prolog frag))))
  frag)

;This cleans out unneeded vars 
;and turns (funcall #'name . args) into (name args).
;together with the in-line substitution which is performed when
;fragments are combined, this transformation allows macros to be used
;as the arguments of oss functions.

(defun clean-code (aux code)
  (let* ((suspicious (not-contained-twice aux code))
	 (dead-aux (clean-code1 suspicious code)))
    (clean-code3 code)
    (values (set-difference aux dead-aux) code)))

(defun not-contained-twice (items thing)
  (let ((found-once nil) (found-twice nil))
    (labels ((look-at (tree)
	       (cond ((symbolp tree)
		      (let ((found (car (member tree items))))
			(when found
			  (if (member found found-once)
			      (pushnew found found-twice)
			      (push found found-once)))))
		     (T (do ((tt tree (cdr tt)))
			    ((not (consp tt)) nil)
			  (look-at (car tt)))))))
      (look-at thing))
    (set-difference items found-twice)))

(defun clean-code1 (suspicious code)
  (let ((dead nil))
    (labels ((clean-code2 (prev-parent parent code &aux var)
               (tagbody
		 R (when (setq var (car (member (setq-p code) suspicious)))
		     (push var dead)
		     (rplaca parent (setq code (caddr code)))
		     (when (or (symbolp code) (constantp code))
		       (cond ((consp (cdr parent))
			      (rplaca parent (cadr parent))
			      (rplacd parent (cddr parent))
			      (setq code (car parent))
			      (go R)) ;do would skip the next element
			     (prev-parent (pop (cdr prev-parent)))))))
	       (when (consp code)
		 (clean-code2 nil code (car code))
		 (do ((tt code (cdr tt)))
		     ((not (and (consp tt) (consp (cdr tt)))) nil)
		   (clean-code2 tt (cdr tt) (cadr tt))))))
      (clean-code2 nil nil code) ;depends on code not being setq at top.
      dead)))

(defun clean-code3 (code)
  (cond ((not (consp code)) code)
	(T (when (and (eq (car code) 'funcall) 
		      (eq (quoted-function-p (cadr code)) 'symbol))
	     (rplaca code (cadadr code))
	     (rplacd code (cddr code)))
	   (do ((tt code (cdr tt)))
	       ((not (consp tt)))
	     (clean-code3 (car tt))))))

;this cleans up type dcls and leaves other ones alone.
;the key problem is that there can end up being several type decls for the
;same variable when fragments are combined.

(proclaim '(special *type-info*))

(defun clean-dcls (aux dcls)
  (let ((*type-info* (mapcar #'list aux))
	(new-dcls nil))
    (dolist (dcl dcls)
      (let ((d (type-dcl-p dcl)))
	(if (null d) (push dcl new-dcls)
	    (dolist (var (cdr d))
	      (when (variable-p var)
		(process-type-dcl (car d) var))))))
    (nconc (make-type-dcls) (nreverse new-dcls))))

(defun type-dcl-p (dcl)
  (cond ((not (consp dcl)) nil)
	((eq (car dcl) 'type) (cdr dcl))
	((subtypep (car dcl) 'common) dcl)))

(defun process-type-dcl (type var)
  (let ((entry (assoc var *type-info*)))
    (when entry
      (setf (cdr entry) (best-type (cdr entry) type)))))

(defun best-type (type1 type2)
  (cond ((null type1) type2)
	((eq type1 :notype) type1)
	((subtypep type1 type2) type1)
	((subtypep type2 type1) type2)
	(T :notype)))

(defun make-type-dcls ()
  (let ((dcls-by-type nil))
    (dolist (entry (nreverse *type-info*)) ;to get lexical order right at end
      (when (and (cdr entry) (not (eq (cdr entry) :notype)))
	(let ((new-entry (assoc (cdr entry) dcls-by-type :test #'equal)))
	  (if (null new-entry)
	      (push (list (cdr entry) (car entry)) dcls-by-type)
	      (push (car entry) (cdr new-entry))))))
    (mapcar #'(lambda (d) (cons 'type d)) dcls-by-type)))

;this gets rid of duplicate labs in a row.
(defun clean-labs (frag stmtns)
  (let ((alist nil))
    (do ((l stmtns (cdr l))) ((not (consp (cdr l))))
      L (when (and (car l) (symbolp (car l))
		   (cadr l) (symbolp (cadr l)))
	  (push (cons (pop (cdr l)) (car l)) alist)
	  (go L)))	  
    (nsublis alist frag)))

;this stuff supports tutorial-mode

(defvar *standard-readtable* nil)
(defvar *tutorial-readtable* nil)

(defun oss-tutorial-mode (&optional (T-or-nil T))
  (when (null *tutorial-readtable*)
    (setq *standard-readtable* *readtable*)
    (setq *tutorial-readtable* (copy-readtable *readtable*))
    (set-macro-character #\[ #'oss-reader nil *tutorial-readtable*)
    (set-macro-character #\] #'oss-end-reader nil *tutorial-readtable*))
  (setq *oss-tutorial-mode* T-or-nil)
  (cond (*oss-tutorial-mode*
	 (setq *readtable* *tutorial-readtable*)
	 "TUTORIAL-MODE-ON")
	(T (setq *readtable* *standard-readtable*)
	   "TUTORIAL-MODE-OFF")))

(defstruct (literal-oss (:print-function literal-oss-print))
  contents)

(defun literal-oss-print (literal-oss stream level &aux first)
    (declare (ignore level))
  (setq first T)
  (princ "[" stream)
  (dolist (item (literal-oss-contents literal-oss))
    (if first (setq first nil) (princ " " stream))
    (if (eq item '|oss-elipsis|)
	(princ "..." stream)
	(prin1 item stream)))
  (princ "]" stream))

(defun oss-end-reader (stream char)
    (declare (ignore stream char))
  '|end-of-literal-oss|)

(defun oss-reader (stream char)
    (declare (ignore char))
  (prog ((stuff nil) item)
      L (setq item (read stream))
	(if (eq item '|end-of-literal-oss|)
	    (return (make-literal-oss :contents (nreverse stuff))))
	(push item stuff)
	(go L)))

;This stuff is called by my-macroexpand in tutorial mode

(defun allow-literal-oss-inputs (thing)
  (cond ((literal-oss-p thing)
         (annotate thing
	   (funcallS-frag
	     (literal-frag
	       `(() ((items T)) (items list-ptr) () ()
		 ((setq list-ptr ',(literal-oss-contents thing)))
		 ((if (null list-ptr) (go END))
		  (setq items (pop list-ptr))) () ())) nil)))
	(T thing)))

;this stuff is called by codify in tutorial mode

(defun allow-oss-outputs (frag)
  (dolist (r (rets frag))
    (when (oss-var-p r)
      (convert-to-literal-oss r))))

(defun convert-to-literal-oss (ret)
  (let* ((frag (fr ret))
	 (var (gensym "O-"))
	 (step `((push ,(var ret) ,var))))
    (if (not (active-terminator-p frag))
	(setq step (append step `((when (> (length ,var) 10)
				    (push '|oss-elipsis| ,var) (go END))))))
    (push var (aux frag))
    (push `(setq ,var nil) (prolog frag))
    (push `(setq ,var (make-literal-oss :contents (nreverse ,var)))
	  (epilog frag))
    (cond ((null (off-line-spot ret))
	   (setf (body frag) (append (body frag) step)))
	  (T (nsubst-inline step (off-line-spot ret) (body frag))))
    (setf (oss-var-p ret) nil)
    (setf (off-line-spot ret) nil)
    (setf (var ret) var)
    frag))

;              SUB-PRIMITIVES FOR DEFINING COMPLEX FRAGS

(defmacro terminateS ()  ;important is not defmacroSed
    "Subprimitive that causes the containing OSS function to terminate."
  '(go END))

(defmacroS lambda-primitiveS (input-list output-list aux-list &body expr-list)
    "Subprimitive for specifying literal OSS functions."
    (declare (ignore input-list output-list aux-list expr-list))
  (ers 21 "Lambda-primitiveS used in inappropriate context:~%~S" +call+))

(defmacroS prologS (&body expr-list) 
    "Subprimitive for defining computations that occur before an OSS function starts."
    (declare (ignore expr-list))
  (ers 22.1 "PrologS used in inappropriate context:~%~S" +call+))

(defmacroS epilogS (&body expr-list)
    "Subprimitive for defining computations that occur after an OSS function stops."
    (declare (ignore expr-list))
  (ers 22.2 "EpilogS used in inappropriate context:~%~S" +call+))

(defmacroS next-inS (var &rest expr-list)
    "Subprimitive for defining off-line inputs."
    (declare (ignore var expr-list))
  (ers 22.3 "Next-inS used in inappropriate context:~%~S" +call+))

(defmacroS next-outS (var)
    "Subprimitive for defining off-line outputs."
    (declare (ignore var))
  (ers 22.4 "Next-outS used in inappropriate context:~%~S" +call+))

(defmacroS wrapS (function)
    "Subprimitive for defining wrapping functions."
    (declare (ignore function))
  (ers 22.5 "WrapS used in inappropriate context:~%~S" +call+))

(defmacroS alterableS (var form)
    "Specifies how to alter the LAMBDA-PRIMITIVES output VAR."
    (declare (ignore var form))
  (ers 22.6 "AlterableS used in inappropriate context:~%~S" +call+))

(defmacro defun-primitiveS (name input-list output-list aux-list
			    #-:GCLISP &environment #-:GCLISP *env*
			    &body expr-list)
    "Subprimitive that defines an OSS function."
  (let ((call (list* 'defun-primitiveS name input-list output-list
		     aux-list expr-list)))  
    (top-starting-oss-expr call
      (setq expr-list (normalize-dcls expr-list T))
      `(defmacroS ,name ,input-list
	 ,@(if (stringp (car expr-list)) (list (pop expr-list)))
	 (funcallS-frag
	   (list->frag
	     ',(frag->list
		 (process-lambda-primitiveS call
		   `(lambda-primitiveS . ,(cddr call)))))
	   (list . ,input-list))))))

(defun process-lambda-primitiveS (call lambda-primitiveS)
  (starting-oss-expr call
    (let* ((ins (cadr lambda-primitiveS))
	   (outs (caddr lambda-primitiveS))
	   (aux (cadddr lambda-primitiveS))
	   (forms (normalize-dcls (cddddr lambda-primitiveS)))
	   (oss-vars (cddadr (pop forms)))
	   (dcl (pop forms))
	   (frag (make-frag :code call)))
      (dolist (v ins)
	(when (not (lambda-variable-p v))
	  (ers 23.1 "Bad lambda-primitiveS input variable: ~S" v))
	(let* ((var (gensym (root v)))
	       (arg (make-sym :var var
			      :oss-var-p (not (null (member v oss-vars))))))
	  (+arg arg frag)
	  (push (cons v arg) *renames*)))
      (dolist (v aux)
	(when (or (not (lambda-variable-p v)) (member v ins))
	  (ers 23.3 "Bad lambda-primitiveS aux variable: ~S" v))
	(let ((var (gensym (root v))))
	  (push var (aux frag))
	  (push (cons v var) *renames*)))
      (dolist (v outs)
	(when (not (or (member v ins) (member v aux)))
	  (ers 23.2 "Bad lambda-primitiveS output variable: ~S" v))
	(let* ((var (rename v))
	       (ret (make-sym :var var
			      :oss-var-p (not (null (member v oss-vars))))))
	  (+ret ret frag)))
      (setf (dcls frag) (process-subforms-&-rename (cdr dcl)))
      (let* ((alist nil) (new-forms nil))
	(dolist (f forms)
	  (cond ((not (symbolp f)) (push f new-forms))
		(T (let ((new (gensym (root f))))
		     (push (cons `(go ,f) `(go ,new)) alist)
		     (push new new-forms)))))
        (when alist
	  (setq forms (sublis alist (nreverse new-forms) :test #'equal))))

      (dolist (form forms)
	(case (and (consp form) (car form))
	  (prologS
	    (setf (prolog frag)
		  (append (prolog frag)
			  (process-subforms-&-rename (cdr form)))))
	  (epilogS
	    (setf (epilog frag)
		  (append (epilog frag)
			  (process-subforms-&-rename (cdr form)))))
	  (wrapS (when (not (and (cdr form) (consp (cdr form))
				 (null (cddr form))
				 (quoted-function-p (cadr form))))
		   (ers 26 "Malformed wrapS call:~%~S" form))
		 (setf (wrappers frag) (append (wrappers frag) (cdr form))))
	  (next-inS
	   (let ((arg (cdr (assoc (cadr form) *renames*)))
		 (actions (process-subforms-&-rename (cddr form)))
		 (E (gensym "E-"))
		 (F (gensym "F-"))
		 (-X- (gensym "-X-")))
	     (when (not (and (member arg (args frag))
			     (oss-var-p arg)
			     (null (off-line-spot arg))))
	       (ers 24 "Malformed next-inS call:~%~S" form))
	     (setf (off-line-spot arg) -X-)
	     (if actions (setf (off-line-exit arg) E))
	     (setf (body frag) (append (body frag)
				       (if (null actions) (list -X-)
					   `(,-X- (go ,F) ,E ,@actions ,F))))))
	  (next-outS
	   (let* ((var (cdr (assoc (cadr form) *renames*)))
		  (ret (find-if #'(lambda (r) (eq var (var r))) (rets frag)))
		  (-X- (gensym "-X-")))
	     (when (not (and ret
			     (oss-var-p ret)
			     (null (off-line-spot ret))
			     (null (cddr form))))
	       (ers 25 "Malformed next-outS call:~%~S" form))
	     (setf (off-line-spot ret) -X-)
	     (setf (body frag) (append (body frag) (list -X-)))))
	  (alterableS
	   (let ((var (cdr (assoc (cadr form) *renames*)))
		 (setf-form (car (process-subforms-&-rename (cddr form)))))
	     (when (not (and (null (cdddr form))
			     (member (cadr form) outs)
			     (not (contains-p ins (caddr form)))
			     (not (assoc var (alterable frag)))))
	       (ers 27 "Malformed alterableS call:~%~S" form))
	     (setf (alterable frag)
		   (append (alterable frag) `((,var ,setf-form))))))
	  (otherwise
	    (setf (body frag)
		  (append (body frag)
			  (process-subforms-&-rename (list form)))))))
      frag)))

;                  FUNCTIONS FOR DEALING WITH FEXPRS

;M-&-R takes in a piece of code.  It assumes CODE is a semantic whole.  Ie, it
;is something which could be evaled (as opposed to a disembodied cond clause).
;It scans over CODE macroexpanding all of the parts of it, and performing
;renames as specified by *RENAMES*.  M-&-R puts entries on the variable
;*RENAMES* which block the renaming of bound variables.
;  M-&-R also calls FN (if any) on every subpart of CODE (including the whole
;thing) which could possibly be evaluated.  The result of consing together all
;of the results of FN is returned.  Ie, the result is isomorphic to the input
;with each part replaced with what FN returned.  This is done totally by
;copying.  The input is not altered.
;  In addition, m-&-R checks to see that the code isn't setqing variables
;it shouldn't be.

;In order to do the above, M-&-R has to be able to understand fexprs.  It
;understands fexprs by having a description of each of the standard ones (see
;below).  It will not work on certain weird ones.
;  fexprs are understood by means of templates which are (usually circular)
;lists of function names.  These fns are called in order to processes the
;various fields of the fexpr.  The template can be a single fn in which case
;this fn is called to process the fexpr as a whole.

(eval-when (eval load compile)
(defmacro make-template (head rest)
  `(let ((h (append ',head nil))
	 (r (append ',rest nil)))
     (nconc h r r)))

(defmacro deft (name head rest)
  `(setf (get ',name 'scan-template) (make-template ,head ,rest))) )

(proclaim '(special *being-setqed* ;T if in the assignment part of a setq
		    *fn*))         ;FN being scanned over code
;ugh an infinite loop ensues if you recompile these in symbolics
;version 6 when they are defconstants
(defvar *expr-template* (make-template (Q) (E)))
(defvar *eval-all-template* (make-template () (E)))
(defvar *fexprs-not-handled*
  '(COMPILER-LET FLET LABELS MACROLET               ;CL forms
    DEF DEFF DEFPROP DEFUN LETF LETF* MACRO))       ;Lispm forms

(defun m-&-r (code &optional (*fn* nil))
  (let ((*being-setqed* nil))
    (m-&-r1 code)))

;on lispm '(lambda ...) macroexpands to (function (lambda ...)) ugh!

(defun my-macroexpand (code &aux (flag T))
  (if *oss-tutorial-mode* (setq code (allow-literal-oss-inputs code)))
  (loop
    (if (or (null flag) (frag-p code)
	    (and (consp code) (symbolp (car code))
		 (get (car code) 'scan-template))) (return))
    (multiple-value-setq (code flag) (macroexpand-1 code #-:GCLISP *env*)))
  code)

(defun m-&-r1 (code)
  (let ((*renames* *renames*) new)
    (setq code (my-macroexpand code))
    (when (and (symbolp code) (setq new (cdr (assoc code *renames*))))
      (if (and *being-setqed* (sym-p new))
	  (ers 12 "The letS{*} variable ~S setqed." code))
      (setq code new))
    (if *fn* (setq code (funcall *fn* code)))
    (if (not (consp code)) code
	(m-&-r2 code
          (let ((head (car code)))
	    (if (member head *fexprs-not-handled*)
		(ers 20 "The form ~S not allowed in OSS expressions." head))
	    (if (symbolp head)
		(or (get head 'scan-template) *expr-template*)
		*eval-all-template*))))))

(defun m-&-r2 (code template)
  (if (not (listp template)) (funcall template code)
      (mapcar #'(lambda (tm c) (funcall tm c)) template code)))

;the following are the fns allowed in templates.

(defun Q   (code) code)
(defun E   (code) (m-&-r1 code))
(defun S   (code) (let ((*being-setqed* T)) (m-&-r1 code)))
(defun L   (code) (if (symbolp code) code (m-&-r1 code)))
(defun B   (code) (bind-list code nil))
(defun B*  (code) (bind-list code T))
(defun A   (code) (arg-list code))

;This handles binding lists for PROG and LET.

(defun bind-list (args sequential &aux (pending nil))
  (prog1 (mapcar #'(lambda (arg)
		     (let* ((val? (and (consp arg) (cdr arg)))
			    (new-val (if val? (m-&-r1 (cadr arg))))
			    (var (if (consp arg) (car arg) arg)))
		       (if sequential (push (list var) *renames*)
			   (push (list var) pending))
		       (if val? (list (car arg) new-val) arg)))
		   args)
	   (setq *renames* (append pending *renames*))))

(defun arg-list (args)  
  (mapcar #'(lambda (arg)
	      (let* ((vars (vars-of arg))
		     (val? (and (consp arg) (cdr arg)))
		     (new-val (if val? (m-&-r1 (cadr arg)))))
		(setq *renames* (append (mapcar #'list vars) *renames*))
		(if val? (list* (car arg) new-val (cddr arg)) arg)))
	  args))

;templates for special forms.  Note that the following are not handled
;  COMPILER-LET FLET LABELS MACROLET  but must not macroexpand

(deft                block (Q Q)  (E))
(deft                catch (Q)    (E))
(deft             function (Q Q)  ())
(deft            eval-when (Q Q)  (E))
(deft                   go (Q Q)  ())
(deft                   if (Q)    (E))
(deft               lambda (Q A)  (E))
(deft                  let (Q B)  (E))
(deft                 let* (Q B*) (E))
(deft  multiple-value-call (Q)    (E))
(deft multiple-value-prog1 (Q)    (E))
(deft                progn (Q)    (E))
(deft                progv (Q)    (E))
(deft                quote (Q Q)  ())
(deft          return-from (Q Q)  (E))
(deft                 setq (Q)    (S E))
(deft              tagbody (Q)    (L))
(deft                  the (Q Q)  (E))
(deft                throw (Q)    (E))
(deft                 type (Q Q)  (E))
(deft       unwind-protect (Q)    (E))


;These fix problems in Lucid/Sun Common Lisp.
;FLET and DECLARE in particular are macros there and messed things up
;by expanding at the wrong time.

(deft                 flet (Q)    (E))
(deft              declare (Q)    (EX))  ;needed by Xerox CL

(deft         compiler-let (Q)    (E))
(deft             macrolet (Q)    (E))
(deft               labels (Q)    (E))

;this stuff is for the Lispm, it should not be needed for more real common
;lisps, but cannot hurt.  (Many to many things are special forms on
;the lispm.)

(defun EX (code) (m-&-r2 code *expr-template*))
(defun EA (code) (m-&-r2 code *eval-all-template*))
(defun SA (code) (let ((*being-setqed* T)) (m-&-r2 code *eval-all-template*)))
(defun DOB (code) (do-bind code nil))
(defun DOB* (code) (do-bind code T))

(defun DO-bind (code sequential? &aux (pending nil))
  (let* ((inits (mapcar
		  #'(lambda (e)
		      (cond ((and (consp e) (cdr e))
			     (prog1 (m-&-r1 (cadr e))
				    (if sequential?
					(push (list (car e)) *renames*)
					(push (list (car e)) pending))))
			    (T (if sequential?
				   (push (list e) *renames*)
				   (push (list e) pending)))))
		       code)))
    (setq *renames* (append pending *renames*))	 
    (let ((updates (mapcar #'(lambda (e)
			       (if (and (consp e) (cddr e))
				   (m-&-r1 (caddr e))))
			   code)))
      (mapcar #'(lambda (e i u)
		  (cond ((not (consp e)) e)
			((cddr e) (list (car e) i u))
			((cdr e) (list (car e) i))
			(T e)))
	      code inits updates))))

(defun WSLB (list)
  (prog1 (EX list) (push (list (car list)) *renames*)))

;the following are just like exprs from the point of view of OSS.
;  *CATCH AND INHIBIT-STYLE-WARNINGS MULTIPLE-VALUE-LIST 
;  MULTIPLE-VALUE-RETURN OR PROGW RETURN RETURN-LIST 
;  VARIABLE-BOUNDP VARIABLE-LOCATION VARIABLE-MAKUNBOUND
; AND and OR have to have templates because the lispm does something
; odd with the way it expands them.  The value gets lost sometimes.

(deft                   AND (Q) (E)) ;this fixes an old lispm bug
(deft               COMMENT () (Q))
(deft                  COND (Q) (EA))
(deft                    DO (Q DOB EA) (L)) ;no old DO
(deft                   DO* (Q DOB* EA) (L))
(deft              DO-NAMED (Q Q DOB EA) (L))
(deft             DO*-NAMED (Q Q DOB* EA) (L))
(deft               GRINDEF () (Q))
(deft                LET-IF (Q E B) (E))
(deft        MULTIPLE-VALUE (Q SA) (E))
(deft                    OR (Q) (E)) ;this fixes an old lispm bug
(deft                  SETF (Q) (E)) ;fixes wierd interaction with lispm setf
(deft         SETQ-GLOBALLY (Q) (S E))
(deft                 SIGNP (Q Q) (E))
(deft               SSTATUS () (Q))
(deft                STATUS () (Q))
(deft                 TRACE () (Q))
(deft               UNTRACE () (Q))
(deft       WITH-STACK-LIST (Q WSLB) (E))
(deft      WITH-STACK-LIST* (Q WSLB) (E))

(defun multiple-value-bind-scan (body)
  (let ((source (E (caddr body)))  ;note order of eval
	(bind (B (cadr body)))
	(forms (EA (cdddr body))))
    (list* (car body) bind source forms)))

(setf (get 'multiple-value-bind 'scan-template) #'multiple-value-bind-scan)

(defvar *prog-template* (make-template (Q B) (L)))
(defvar *named-prog-template* (make-template (Q Q B) (L)))
(defvar *prog*-template* (make-template (Q B*) (L)))
(defvar *named-prog*-template* (make-template (Q Q B*) (L)))

(defun prog-scan (body)
  (ps0 body *prog-template* *named-prog-template*))

(defun prog*-scan (body)
  (ps0 body *prog*-template* *named-prog*-template*))

(defun ps0 (body template named-template)
  (if (and (cdr body) (cadr body) (symbolp (cadr body)))
      (m-&-r2 body named-template)
      (m-&-r2 body template)))

(setf (get 'prog 'scan-template) #'prog-scan)
(setf (get 'prog* 'scan-template) #'prog*-scan)

;                       SERIES FUNCTION LIBRARY

;Special form for defining series functions directly in the internal form.
;The various variables and the exit label must be unique in the body.
;The exit label must be END.  Also everything is arranged just as it is
;in an actual frag structure.

(eval-when (eval load compile)
(defmacro defS (name arglist doc args rets aux dcls alt
		prolog body epilog wrappers)
  (let* ((vals (mapcar #'car args))
	 (syms aux)
	 (stuff (list args rets aux dcls alt prolog body epilog wrappers)))
    (dolist (a args)
      (push (car a) syms)
      (if (written-p (car a) stuff)
	  (error "Malformed defS: Input written ~A" (car a))))
    (dolist (r rets)
      (if (not (member (car r) syms))
	  (error "Malformed defS: Free ret ~A" (car r))))
    (if (eq arglist T) (setq arglist vals))
    `(defmacroS ,name ,arglist ,@(if doc (list doc))
       (funcallS-frag (literal-frag ',stuff) (list . ,vals)))))

(defun written-p (var thing)
  (if (eq var (setq-p thing)) T
    (do ((tt thing (cdr tt)))
	((not (consp tt)) nil)
      (if (written-p var (car tt)) (return T)))))

(defun setq-p (thing)
  (and (eq-car thing 'setq)
       (= (length thing) 3)
       (cadr thing)))

(defun eq-car (thing item)
  (and (consp thing) (eq (car thing) item))) )

(defmacroS Eoss (&rest expr-list)
    "Creates a series of the results of the expressions."
  (let ((spot (member :R expr-list)))
    (when (and spot (null (cdr spot)))
      (setq expr-list (ldiff expr-list spot))
      (setq spot nil))
    (cond ((null spot)
	   (let ((ins nil))
	     (dotimes (i (length expr-list) i)
	       (push (gensym "IN-") ins))	    
	     (funcallS-frag
	       (literal-frag
		 `(,(mapcar #'list ins) ((items T)) (items list-ptr) () ()
		   ((setq list-ptr (list . ,ins)))
		   ((if (null list-ptr) (go END))
		    (setq items (car list-ptr))
		    (setq list-ptr (cdr list-ptr))) () ()))
	       expr-list)))
	  ((and (eq expr-list spot) (null (cddr spot)))
	   (funcallS-frag
	     (literal-frag
	       '(((expr)) ((expr T)) () () ()
		 () () () ()))
	    (list (cadr spot))))
	  (T (let ((first-part (ldiff expr-list spot))
		   (second-part (cdr spot))
		   (ins1 nil) (ins2 nil))
	       (dotimes (i (length first-part) i)
	         (push (gensym "IN-") ins1))
	       (dotimes (i (length second-part) i)
	         (push (gensym "IN-") ins2))
	       (funcallS-frag
		 (literal-frag
		   `(,(mapcar #'list (append ins1 ins2))
		       ((items T)) (items list-ptr) () ()
		     ((setq list-ptr
			    (let ((x (list . ,ins1))
				  (y (list . ,ins2)))
			      (nconc x y y))))
		     ((setq items (pop list-ptr))) () ()))
		 (append first-part second-part)))))))

(defmacroS Eup (&rest args)
    "Creates a series of numbers by counting up from START by :BY."
  (let ((start 0) (by nil) (limit-type :none) (limit nil))
    (when (and args (not (member (car args) '(:to :below :length :by))))
      (setq start (pop args)))
    (prog ()
	L (if (null args) (return nil))
	  (when (and (eq (car args) :by) (null by) (cdr args))
	    (pop args)
	    (setq by (pop args))
	    (go L))
	  (when (and (member (car args) '(:to :below :length))
		     (eq limit-type :none) (cdr args))
	    (setq limit-type (pop args))
	    (setq limit (pop args))
	    (go L))
	  (ers 1.1 "Too many keywords specified in a call on Eup:~%~S" +call+))
    (when (null by) (setq by 1))
    (if (eq limit-type :none)
        (funcallS-frag
	  (literal-frag
	    '(((start) (by)) ((numbers T)) (numbers) () ()
	      ((setq numbers (- start by)))
	      ((setq numbers (+ numbers by))) () ()))
	  (list start by))
        (funcallS-frag
	  (literal-frag
	    (case limit-type
	      (:to '(((start) (to) (by)) ((numbers T)) (numbers) () ()
		     ((setq numbers (- start by)))
		     ((setq numbers (+ numbers by))
		      (if (> numbers to) (go END))) () ()))
	      (:below '(((start) (below) (by)) ((numbers T)) (numbers) () ()
			((setq numbers (- start by)))
			((setq numbers (+ numbers by))
			 (if (not (< numbers below)) (go END))) () ()))
	      (:length '(((start) (length) (by)) ((numbers T))
			  (numbers counter) () ()
			 ((setq numbers (- start by)) (setq counter length))
			 ((setq numbers (+ numbers by))
			  (if (not (plusp counter)) (go END))
			  (decf counter)) () ()))))
	  (list start limit by)))))

(defmacroS Edown (&rest args)
    "Creates a series of numbers by counting down from START by :BY."
  (let ((start 0) (by nil) (limit-type :none) (limit nil))
    (when (and args (not (member (car args) '(:to :above :length :by))))
      (setq start (pop args)))
    (prog ()
	L (if (null args) (return nil))
	  (when (and (eq (car args) :by) (null by) (cdr args))
	    (pop args)
	    (setq by (pop args))
	    (go L))
	  (when (and (member (car args) '(:to :above :length))
		     (eq limit-type :none) (cdr args))
	    (setq limit-type (pop args))
	    (setq limit (pop args))
	    (go L))
	  (ers 1.2 "Too many keywords specified in a call on Eup:~%~S" +call+))
    (when (null by) (setq by 1))
    (if (eq limit-type :none)
        (funcallS-frag
	  (literal-frag
	    '(((start) (by)) ((numbers T)) (numbers) () ()
	      ((setq numbers (+ start by)))
	      ((setq numbers (- numbers by))) () ()))
	  (list start by))
        (funcallS-frag
	  (literal-frag
	    (case limit-type
	      (:to '(((start) (to) (by)) ((numbers T)) (numbers) () ()
		     ((setq numbers (+ start by)))
		     ((setq numbers (- numbers by))
		      (if (< numbers to) (go END))) () ()))
	      (:above '(((start) (above) (by)) ((numbers T)) (numbers) () ()
			((setq numbers (+ start by)))
			((setq numbers (- numbers by))
			 (if (not (> numbers above)) (go END))) () ()))
	      (:length '(((start) (length) (by)) ((numbers T))
			  (numbers counter) () ()
			 ((setq numbers (+ start by)) (setq counter length))
			 ((setq numbers (- numbers by))
			  (if (not (plusp counter)) (go END))
			  (decf counter)) () ()))))
	  (list start limit by)))))

(defS Esublists (list &optional (end-test '#'endp))
    "Creates a series of the sublists in a list."
  ((list) (end-test)) ((sublists T)) (sublists list-ptr) () ()
  ((setq list-ptr list))
  ((if (funcall end-test list-ptr) (go END))
   (setq sublists list-ptr)
   (setq list-ptr (cdr list-ptr))) () ())

(defS Elist (list &optional (end-test '#'endp))
    "Creates a series of the elements in a list."
  ((list) (end-test)) ((elements T)) (elements list-ptr parent)
    () ((elements (car parent)))
  ((setq list-ptr list))
  ((if (funcall end-test list-ptr) (go END))
   (setq parent list-ptr)
   (setq elements (car list-ptr))
   (setq list-ptr (cdr list-ptr))) () ())

(defS Ealist (alist &optional (test '#'eql))
    "Creates two series containing the keys and values in an alist."
  ((alist) (test)) ((keys T) (values T)) (alist-ptr keys values parent)
   () ((keys (car parent)) (values (cdr parent)))
  ((setq alist-ptr alist))
  (L (if (null alist-ptr) (go END))
     (setq parent (car alist-ptr))
     (setq alist-ptr (cdr alist-ptr))
     (if (or (null parent)
	     (not (eq parent (assoc (car parent) alist :test test))))
	 (go L))
     (setq keys (car parent))
     (setq values (cdr parent))) () ())

(defS Eplist T
    "Creates two series containing the indicators and values in a plist."
  ((plist)) ((indicators T) (values T)) (indicators values plist-ptr parent)
   () ((indicators (car parent)) (values (cadr parent)))
  ((setq plist-ptr plist))
  (L (if (null plist-ptr) (go END))
     (setq parent plist-ptr)
     (setq indicators (car plist-ptr))
     (setq plist-ptr (cdr plist-ptr))
     (setq values (car plist-ptr))
     (setq plist-ptr (cdr plist-ptr))
     (do ((ptr plist (cddr ptr)))
	 ((eq (car ptr) indicators)
	  (if (not (eq ptr parent)) (go L))))) () ())

(defS Etree (tree &optional (leaf-test '#'atom))
    "Creates a series of the nodes in a tree."
  ((tree) (leaf-test)) ((nodes T)) (nodes state) () ()
  ((setq state (list tree)))
  ((if (null state) (go END))
   (setq nodes (car state))
   (setq state (cdr state))
   (when (not (funcall leaf-test nodes))
     (do ((ns nodes (cdr ns)) 
	  (r nil (cons (car ns) r)))
	 ((not (consp ns))
	  (setq state (nreconc r state)))))) () ())

(defS Efringe (tree &optional (leaf-test '#'atom))
    "Creates a series of the leaves of a tree."
  ((tree) (leaf-test)) ((leaves T)) (leaves parent state)
    () ((leaves (car parent)))
  ((setq state (list (list tree))))
  (L (if (null state) (go END))
     (setq leaves (car state))
     (setq state (cdr state))
     (setq parent leaves)
     (setq leaves (car leaves))
     (when (not (funcall leaf-test leaves))
       (do ((ns leaves (cdr ns)) 
	    (r nil (cons ns r)))
	   ((not (consp ns)) (setq state (nreconc r state))))
       (go L))) () ())

(defmacroS Evector (vector &optional (indices (list 'Eup)))
    "Creates a series of the elements in a vector."
  (if (equal indices '(Eup))
      (funcallS-frag
	(literal-frag
	  '(((vector)) ((elements T)) (elements last index vect)
	    ((type integer last index)) ((elements (aref vect index)))
	    ((setq index -1)
	     (setq last (length vector))
	     (setq vect vector))
	    ((incf index)
	     (if (not (< index last)) (go END))
	     (setq elements (aref vector index))) () ()))
	(list vector))
      (funcallS-frag
	(literal-frag
	  '(((vector) (indices T)) ((elements T)) (elements last vect index)
	    ((type integer last index)) ((elements (aref vect index)))
	    ((setq last (length vector)) (setq vect vector))
	    ((if (not (< indices last)) (go END))
	     (setq index indices)
	     (setq elements (aref vector indices))) () ()))
	(list vector indices))))

(defS Esequence (sequence &optional (indices (list 'Eup)))
    "Creates a series of the elements in a sequence."
  ((sequence) (indices T)) ((elements T)) (elements last seq index)
    () ((elements (elt seq index)))
  ((setq last (length sequence)) (setq seq sequence))
  ((if (not (< indices last)) (go END))
   (setq index indices)       
   (setq elements (elt sequence indices))) () ())

(defmacroS Efile (name)
    "Creates a series of the forms in the file named NAME."
  (let ((file (gensym "FILE-")))
    (funcallS-frag
      (literal-frag
	`(() ((items T)) (items) () ()
	  ()
	  ((if (eq (setq items (read ,file nil ,file)) ,file) (go END))) ()
	  (#'(lambda (code)
	       (list 'with-open-file
		     '(,file ,name :direction :input)
		     code)))))
      nil)))

#-lispm
(defS Ehash T
    "Creates two series containing the keys and values in a hash table."
  ((table)) ((keys T) (values T)) (keys values list-ptr) () ()
  ((setq list-ptr nil)
   (maphash #'(lambda (key val) (push (cons key val) list-ptr)) table))
  ((if (null list-ptr) (go END))
   (setq keys (caar list-ptr))
   (setq values (cdar list-ptr))
   (setq list-ptr (cdr list-ptr))) () ())

#+lispm ;see hash-elements loop code
(defS Ehash T 
    "Creates two series containing the keys and values in a hash table."
  ((table)) ((keys T) (values T)) (state keys values) () ()
  ((setq state nil))
  ((if (not (multiple-value-setq (state keys values)
	      (si:send table :next-element state)))
       (go END))) ()
  (#'(lambda (c) `(si:inhibit-gc-flips ,c))))

#-lispm
(defS Esymbols (&optional (package nil))
    "Creates a series of the symbols in PACKAGE."
  ((package)) ((symbols T)) (symbols list-ptr) () ()
  ((setq list-ptr nil)
   (do-symbols (s (or package *package*)) (push s list-ptr)))
  ((if (null list-ptr) (go END))
   (setq symbols (car list-ptr))
   (setq list-ptr (cdr list-ptr))) () ())

#+lispm ;see do-symbols
(defS Esymbols (&optional (package nil))
    "Creates a series of the symbols in PACKAGE."
  ((package)) ((symbols T)) (index state symbols) () ()
  ((multiple-value-setq (index symbols state)
     (si:loop-initialize-mapatoms-state (or package *package*) nil)))
  ((if (multiple-value-setq (nil index symbols state)
	 (si:loop-test-and-step-mapatoms index symbols state))
       (go END))) () ())

(defmacroS EnumerateF (init step &optional (test nil test-p))
    "Creates a series by applying STEP to INIT until TEST returns non-null."
  (if test-p
      (funcallS-frag
	(literal-frag
	  '(((init) (step) (test)) ((items T)) (items state) () ()
	    ((setq state init))
	    ((cond ((funcall test state) (go END))
		   (T (setq items state)
		      (setq state (funcall step state))))) () ()))
	(list init step test))
      (funcallS-frag
	(literal-frag
	  '(((init) (step)) ((items T)) (items state) () ()
	    ((setq state init))
	    ((setq items state state (funcall step state))) () ()))
	(list init step))))

(defS Enumerate-inclusiveF T
    "Creates a series containing one more element than EnumerateF."
  ((init) (step) (test)) ((items T)) (items state done) () ()
  ((setq done nil) (setq state init))
  ((if done (go END))
   (setq done (funcall test state))
   (setq items state)
   (if (not done) (setq state (funcall step state)))) () ())

(defmacroS Tprevious (items &optional (default nil) (amount 1)) 
    "Shifts ITEMS to the right by AMOUNT inserting DEFAULT."
  (if (eql amount 1)
      (funcallS-frag
	(literal-frag
	  '(((items T) (default)) ((shifted-items T)) (shifted-items state)
	     () ()
	    ((setq state default))
	    ((setq shifted-items state) (setq state items)) () ()))
	(list items default))
      (funcallS-frag
	(literal-frag
	  '(((items T) (default) (amount)) ((shifted-items T))
             (shifted-items ring) () ()
	    ((setq ring (make-list (1+ amount) :initial-element default))
	     (nconc ring ring))
	    ((setf (car ring) items)
	     (setq ring (cdr ring))
	     (setq shifted-items (car ring))) () ()))
	(list items default amount))))

(defmacroS Tlatch (items &key (after nil) (before nil)
			      (pre nil pre?) (post nil post?))
    "Modifies a series before or after a latch point."
  (when (and after before)
    (ers 1.3 "Too many keywords specified in call on Tlatch:~%~S" +call+))
  (if (not (or before after)) (setq after 1))
  (if (null pre?) (setq post? T))
  (funcallS-frag
    (literal-frag
      `(((items T) (for) ,@(if pre? '((pre T))) ,@(if post? '((post T))))
	  ((masked-items T)) (masked-items state) () ()
	((setq state for))
	((cond (,@(if before
		      '((and (plusp state)
			     (or (null items)
				 (not (zerop (setq state (1- state)))))))
		      '((plusp state)
			(if items (decf state))))
		(setq masked-items ,(if pre? 'pre 'items)))
	       (T (setq masked-items ,(if post? 'post 'items))))) () ()))
    `(,items ,(or before after)
      ,@(if pre? (list pre)) ,@(if post? (list post)))))

(defS Tuntil T
 "Returns ITEMS up to, but not including, the first non-null element of BOOLS."
  ((bools T) (items T)) ((items T)) () () ()
  () ((if bools (go END))) () ())

(defS TuntilF T
    "Returns ITEMS up to, but not including, the first element which satisfies PRED."
  ((pred T) (items T)) ((items T)) () () ()
  () ((if (funcall pred items) (go END))) () ())

(defmacroS Tcotruncate (items &rest more-items)
    "Truncates all the inputs to the length of the shortest input."
  (let ((frag (make-frag))
	(stuff (cons items more-items)))
    (dotimes (i (length stuff) i)
      (let ((var (gensym "CT-")))
	(+arg (make-sym :var var :oss-var-p T) frag)
	(+ret (make-sym :var var :oss-var-p T) frag)))
    (funcalls-frag frag stuff)))

(defmacroS TmapF (function &rest items-list)
    "Maps FUNCTION over the input series."
  (do-TmapF function items-list))

(defun do-TmapF (function items-list)
  (let ((frag (make-frag))
	(params nil)
	(retvar (gensym "ITEMS-"))
	(fn (gensym "FUNCTION-")))
    (+arg (make-sym :var fn) frag)
    (+ret (make-sym :var retvar :oss-var-p T) frag)
    (setf (aux frag) (list retvar))
    (dotimes (i (length items-list) i)
      (let ((var (gensym "M-")))
	(push var params)
	(+arg (make-sym :var var :oss-var-p T) frag)))
    (setf (body frag)
	  `((setq ,retvar (funcall ,fn . ,(nreverse params)))))
    (funcalls-frag frag (cons function items-list))))

(defmacroS TscanF (&rest arg-list)
    "Computes cumulative values by applying FUNCTION to the elements of ITEMS."
  (if (= (length arg-list) 3)
      (funcallS-frag
	(literal-frag
	  '(((init) (function) (items T)) ((results T)) (results) () ()
	    ((setq results init))
	    ((setq results (funcall function results items))) () ()))
	arg-list)
      (funcallS-frag
	(literal-frag
	  '(((function) (items T)) ((results T)) (first results) () ()
	    ((setq first T))
	    ((if first (setq first nil results items)
	         (setq results (funcall function results items)))) () ()))
	arg-list)))

(defS Tremove-duplicates (Oitems &optional (comparitor '#'eql))
    "Removes the duplicate elements from a series."
  ((Oitems T -X-) (comparitor)) ((Oitems T)) (seen) () ()
  ((setq seen nil))
  (L -X-
     (if (member Oitems seen :test comparitor) (go L))
     (push Oitems seen)) () ())

(defS Tchunk T
    "Creates a series of lists of length AMOUNT of non-overlapping subseries of OITEMS."
  ((amount) (Oitems T -X-)) ((lists T)) (lists i state) () ()
  ((setq state nil) (setq i amount)) 
  (L -X-
     (decf i)
     (push Oitems state)
     (if (plusp i) (go L))
     (setq lists (nreverse state))
     (setq state nil) (setq i amount)) () ())

(defS Twindow T 
    "Creates a series of lists of length AMOUNT of successive overlapping subseries."
  ((amount) (Oitems T -X-)) ((lists T)) (lists ring count) () ()
  ((setq ring (make-list amount))
   (setq count amount)
   (nconc ring ring))
  (L -X- 
     (decf count)
     (setq ring (cdr ring))
     (setf (car ring) Oitems)
     (if (plusp count) (go L))
     (let ((spot (cdr ring))) ;Avoids bug in Dec CL.
       (rplacd ring nil)
       (setq lists (copy-list spot))
       (rplacd ring spot))) () ())

(defS Tpositions (Obools)
    "Returns a series of the positions of non-null elements in OBOOLS."
  ((Obools T -X-)) ((index T)) (index) () ()
  ((setq index -1))
  (L -X- (incf index) (if (not Obools) (go L))) () ())

(defS Tmask T 
    "Creates a series continuing T in the indicated positions."
  ((Omonotonic-indices T -X- D)) ((bools T)) (bools index) () ()
  ((setq index -1 bools T))
  (  (if (not bools) (go F))
     -X- (go F) D (setq index nil)
   F (setq bools (and index (= (progn (incf index) index)
			       Omonotonic-indices)))) () ())

(defmacroS Tselect (bools &optional (items nil items-p))
   "Selects the elements of ITEMS corresponding to non-null elements of BOOLS."
  (if items-p
      (funcallS-frag
	(literal-frag
	  '(((bools T) (items T)) ((items T -X-)) () () ()
	    () ((if (not bools) (go F)) -X- F) () ()))
	(list bools items))
      (funcallS-frag
	(literal-frag
	  '(((bools T -X-)) ((bools T)) () () ()
	    () (L -X- (if (not bools) (go L))) () ()))
	(list bools))))

(defS TselectF T
    "Selects the elements of ITEMS for which PRED is non-null."
  ((pred) (Oitems T -X-)) ((Oitems T)) () () ()
  () (L -X- (if (not (funcall pred Oitems)) (go L))) () ())

(defS Texpand (bools Oitems &optional (default nil))
    "Spreads the elements of ITEMS out into the indicated positions."
  ((bools T) (Oitems T -X-) (default)) ((items T)) (items) () ()
  ()
  ((when (not bools) (setq items default) (go F))
   -X- (setq items Oitems)
   F) () ())

(defmacroS Tsubseries (Oitems start &optional (below nil))
   "Returns the elements of OITEMS from START up to, but not including, BELOW."
  (if below
      (funcallS-frag
	(literal-frag
	 '(((items T -X-) (start) (below)) ((items T)) (index) () ()
	   ((setq index -1))
	   (LP -X-
	       (incf index)
	       (if (not (< index below)) (go END))
	       (if (< index start) (go LP))) () ()))
	(list Oitems start below))
      (funcallS-frag
	(literal-frag
	  '(((items T -X-) (start)) ((items T)) (index) () ()
	    ((setq index -1))
	    (LP -X-
	        (incf index)
	        (if (< index start) (go LP))) () ()))
	(list Oitems start))))

(defS Tmerge T "Merges two series into one."
  ((Oitems1 T -X1- F1) (Oitems2 T -X2- F2) (comparator)) ((items T))
    (items need1 need2) () ()
  ((setq need1 1 need2 1))
  (   (if (not (plusp need1)) (go F1))
      (setq need1 -1)
      -X1-
      (setq need1 0)
   F1 (if (not (plusp need2)) (go F2))
      (setq need2 -1)
      -X2-
      (setq need2 0)
   F2 (cond ((and (minusp need1) (minusp need2)) (go END))
	    ((minusp need1) (setq items Oitems2) (setq need2 1))
	    ((minusp need2) (setq items Oitems1) (setq need1 1))
	    ((funcall comparator Oitems1 Oitems2)
	     (setq items Oitems1) (setq need1 1))
	    (T (setq items Oitems2) (setq need2 1)))) () ())

(defS Tlastp T
    "Determines which element of the input is the last."
  ((Oitems T -X- F)) ((bools T) (items T)) (bools items started) () ()
  ((setq started nil) (setq bools nil))
  (  (if bools (go END))
   L (setq items Oitems)
     -X-
     (when (not started) (setq started T) (go L))
     (go D)
   F (if (not started) (go END))
     (setq bools T)
   D) () ())

(defmacroS Tconcatenate (Oitems1 Oitems2 &rest more-Oitems) ;fix!
    "Concatenates two or more series end to end."
  (let (args body (len (+ 2 (length more-Oitems))))
    (dotimes (i (1- len))
      (let ((in (gensym "I-"))
	    (spot (gensym "-X-"))
	    (exit (gensym "E-"))
	    (skip (gensym "F-")))
	(push (list in T spot exit) args)
	(setq body (nconc body `((if (not (= state ,i)) (go ,skip))
				 ,spot (setq items ,in) (go D)
				 ,exit (incf state) ,skip)))))
    (let ((in (gensym "I-"))
	  (spot (gensym "-X-")))
      (push (list in T spot) args)
      (setq body (nconc body `(,spot (setq items ,in) D))))
    (funcallS-frag
      (literal-frag
        `(,(reverse args) ((items T)) (items state) () ()
	  ((setq state 0)) ,body () ()))
      (list* Oitems1 Oitems2 more-Oitems))))

(defmacroS Tsplit (items bools &rest more-bools)
    "Divides a series into multiple outputs based on BOOLS."
  (do-Tsplit items (cons bools more-bools) T))

(defmacroS TsplitF (items pred &rest more-pred)
    "Divides a series into multiple outputs based on PRED."
  (do-Tsplit items (cons pred more-pred) nil))

(defun do-Tsplit (items stuff bools-p)
  (let ((frag (make-frag))
	(ivar (gensym "ITEMS-"))
	(D (gensym "D-")))
    (+arg (make-sym :var ivar :oss-var-p T) frag)
    (dotimes (i (length stuff) i)
      (let ((var (gensym "B-"))
	    (-X- (gensym "-X-"))
	    (S (gensym "S-")))
	(+arg (make-sym :var var :oss-var-p bools-p) frag)
	(+ret (make-sym :var ivar :oss-var-p T :off-line-spot -X-) frag)
	(setf (body frag)
	      `(,@(body frag)
		  (if (not ,(if bools-p var `(funcall ,var ,ivar))) (go ,S))
	          ,-X-
	          (go ,D)
	       ,S ))))
    (let ((-X- (gensym "-X-")))
      (+ret (make-sym :var ivar :oss-var-p T :off-line-spot -X-) frag)
      (setf (body frag)
	    `(,@(body frag)
	       ,-X- ,D)))
    (funcalls-frag frag (cons items stuff))))

(defmacroS TconcatenateF (enumerator Oitems)
   "Concatenates the results of applying ENUMERATOR to the elements of OITEMS."
  (let* ((in (gensym "IN-"))
	 (enum-form `(lambdaS (,in) (funcallS ,enumerator ,in)))
	 (enum (process-lambdaS enum-form enum-form))
	 (flag (gensym "FLAG-"))
	 (-X- (gensym "-X-"))
	 (E (gensym "E-"))
	 (C (gensym "C-")))
      (when (or (non-oss-p enum) (not (active-terminator-p enum))
		(not (rets enum)) (not (oss-var-p (car (rets enum))))
		(epilog enum) (wrappers enum))
	(ers 2 "Invalid enumerator arg to TconcatenateF:~%~S" enumerator))
      (push flag (aux enum))
      (setf (oss-var-p (car (args enum))) T)
      (setf (off-line-spot (car (args enum))) -X-)
      (nsubst E 'END enum)
      (setf (body enum)
	   `(   (if ,flag (go ,C) (setq ,flag T))
	     ,E ,-X-
	        ,@(prolog enum)
	     ,C ,@(body enum)))
      (setf (prolog enum) `((setq ,flag nil)))
      (annotate +call+ (funcallS-frag enum (list Oitems)))))

(defS Rlist T
    "Combines the elements of ITEMS together into a list."
  ((items T)) ((the-list)) (the-list tail) () ()
  ((setq the-list nil) (setq tail nil))
  ((if (null the-list)
     (setq the-list (setq tail (list items)))
     (rplacd tail (setq tail (list items)))))
  () ())

(defS Rbag T
    "Combines the elements of ITEMS together into an unordered list."
  ((items T)) ((list)) (list) () ()
  ((setq list nil)) ((setq list (cons items list))) () ())

(defS Rappend T
    "Appends the elements of LISTS together into a single list."
  ((lists T)) ((list)) (list end) () ()
  ((setq end nil) (setq list nil))
  ((when lists
     (let ((copy (copy-list lists)))
       (if end (setf (cdr (last end)) copy))
       (setq end copy)
       (if (null list) (setq list copy))))) () ())

(defS Rnconc T
    "Destructively appends the elements of LISTS together into a single list."
  ((lists T)) ((list)) (list end) () ()
  ((setq end nil) (setq list nil))
  ((when lists
     (if end (setf (cdr (last end)) lists))
     (setq end lists)
     (if (null list) (setq list lists)))) () ())

(defmacroS Rvector (items &rest option-plist
		    &key (size nil) &allow-other-keys)
    "Combines the elements of ITEMS together into a vector."
  (cond (size
	 (remf option-plist :size)
	 (funcallS-frag
	   (literal-frag
	     `(((items T)) ((vector)) (vector index) () ()
	       ((setq vector (make-array ,size . ,option-plist))
		(setq index 0))
	       ((setf (aref vector index) items) (incf index)) () ()))
	   (list items)))
	(T (setf (getf option-plist :adjustable) T)
	   (setf (getf option-plist :fill-pointer) 0)
	   (funcallS-frag
	    (literal-frag
	      `(((items T)) ((vector)) (vector) () ()
		((setq vector (make-array 32 . ,option-plist)))
		((vector-push-extend items vector)) () ()))
	    (list items)))))

(defmacroS Rhash (keys values &rest option-plist)
 "Combines a series of keys and a series of values together into a hash table."
  (funcallS-frag
    (literal-frag
      `(((keys T) (values T)) ((table)) (table) () ()
        ((setq table (make-hash-table . ,option-plist)))
	((setf (gethash keys table) values)) () ()))
    (list keys values)))

(defmacroS Rfile (name items &rest option-plist)
    "Prints the elements of ITEMS into a file."
  (setf (getf option-plist :direction) :output)
  (funcallS-frag
    (literal-frag
      `(((items T)) ((out)) (out) () ()
	((setq out T)) ((print items file)) ()
	(#'(lambda (c)
	     (list 'with-open-file '(file ,name . ,option-plist) c)))))
    (list items)))

(defS Ralist T
    "Combines a series of keys and a series of values together into an alist."
  ((keys T) (values T)) ((alist)) (alist) () ()
  ((setq alist nil))
  ((setq alist (cons (cons keys values) alist))) 
  ((setq alist (nreverse alist))) ())

(defS Rplist T 
"Combines a series of indicators and a series of values together into a plist."
  ((indicators T) (values T)) ((plist)) (plist) () ()
  ((setq plist nil))
  ((setq plist (list* values indicators plist)))
  ((setq plist (nreverse plist))) ())

(defS Rfirst-late (items &optional (default nil))
    "Returns the first element of ITEMS."
  ((items T) (default)) ((item)) (item found) () ()
  ((setq item default) (setq found nil))
  ((when (not found) (setq item items) (setq found T))) () ())

(defS Rlast (items &optional (default nil))
    "Returns the last element of ITEMS."
  ((items T) (default)) ((item)) (item) () ()
  ((setq item default)) ((setq item items)) () ())

(defS Rnth-late (n items &optional (default nil))
    "Returns the nth element of ITEMS."
  ((n) (items T) (default)) ((item)) (item counter) () ()
  ((setq item default) (setq counter n))
  ((when (zerop counter) (setq item items)) (decf counter)) () ())

(defS Rlength T "Returns the number of elements in ITEMS."
  ((items T)) ((number)) (number) () ()
  ((setq number 0)) ((incf number)) () ())

(defS Rand-late T "Computes the AND of the elements of BOOLS."
  ((bools T)) ((bool)) (bool) () ()
  ((setq bool T))
  ((setq bool (and bool bools))) () ())

(defS Ror-late T "Computes the OR of the elements of BOOLS."
  ((bools T)) ((bool)) (bool) () ()
  ((setq bool nil))
  ((setq bool (or bool bools))) () ())

(defS Rsum T "Computes the sum of the elements in NUMBERS."
  ((numbers T)) ((num)) (num) ((type number numbers num)) ()
  ((setq num 0))
  ((setq num (+ num numbers))) () ())

(defS Rmax T "Returns the maximum element of NUMBERS."
  ((numbers T)) ((number)) (number) () ()
  ((setq number nil))
  ((if (or (null number) (< number numbers)) (setq number numbers))) () ())

(defS Rmin T "Returns the minimum element of NUMBERS."
  ((numbers T)) ((number)) (number) () ()
  ((setq number nil))
  ((if (or (null number) (> number numbers)) (setq number numbers))) () ())

(defS ReduceF T
   "Computes a cumulative value by applying FUNCTION to the elements of ITEMS."
  ((init) (function) (items T)) ((result)) (result) () ()
  ((setq result init))
  ((setq result (funcall function result items))) () ())

(defS Rfirst (items &optional (default nil))
    "Returns the first element of ITEMS, terminating early."
  ((items T) (default)) ((item)) (item) () ()
  ((setq item default))
  ((setq item items) (go END)) () ())

(defS Rnth (n items &optional (default nil))
    "Returns the nth element of ITEMS, terminating early."
  ((n) (items T) (default)) ((item)) (counter item) () ()
  ((setq item default) (setq counter n))
  ((when (zerop counter) (setq item items) (go END)) (decf counter)) () ())

(defS Rand T
    "Computes the AND of the elements of BOOLS, terminating early."
  ((bools T)) ((bool)) (bool) () ()
  ((setq bool T)) ((if (null (setq bool bools)) (go END))) () ())

(defS Ror T 
    "Computes the OR of the elements of BOOLS, terminating early."
  ((bools T)) ((bool)) (bool) () ()
  ((setq bool nil)) ((if (setq bool bools) (go END))) () ())

;Has correct annotation, because is not a defmacroS thing.
(defmacro showS (thing &optional (format "~%~S") (stream '*standard-output*))
    "Displays THING for debugging purposes."
  (let ((var (gensym "SHOW-")))
    `(let ((,var ,thing))
       (format ,stream ,format ,var)
       ,var)))

;------------------------------------------------------------------------ ;
;                Copyright (c) Richard C. Waters, 1988                    ;
;------------------------------------------------------------------------ ;
