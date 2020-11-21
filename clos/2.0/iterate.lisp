(DEFINE-FILE-INFO READTABLE "XCL" PACKAGE (CLIN-PACKAGE ITERATE USE (QUOTE (LISP WALKER))) 
BASE 10)
(IL:FILECREATED "19-Feb-91 13:55:29" 
IL:|{DSK}<usr>local>users>welch>lisp>clos>rev4>il-format>ITERATE.;2| 65656  

      IL:|changes| IL:|to:|  (IL:VARS IL:ITERATECOMS)

      IL:|previous| IL:|date:| " 6-Feb-91 11:00:58" 
IL:|{DSK}<usr>local>users>welch>lisp>clos>rev4>il-format>ITERATE.;1|)


; Copyright (c) 1991 by Venue.  All rights reserved.

(IL:PRETTYCOMPRINT IL:ITERATECOMS)

(IL:RPAQQ IL:ITERATECOMS 
          (

(IL:* IL:|;;;| "************************************************************************* Copyright (c) 1985, 1986, 1987, 1988, 1989, 1990 Xerox Corporation. All rights reserved. Use and copying of this software and preparation of derivative works based upon this software are permitted.  Any distribution of this software or derivative works must comply with all applicable United States export control laws. This software is made available AS IS, and Xerox Corporation makes no warranty about the software, its performance or its conformity to any specification. Any person obtaining a copy of this software is requested to send their name and post office or electronic mail address to: CommonLoops Coordinator Xerox PARC 3333 Coyote Hill Rd. Palo Alto, CA 94304 (or send Arpanet mail to CommonLoops-Coordinator.pa@Xerox.arpa) Suggestions, comments and requests for improvements are also welcome. ************************************************************************* Original source {pooh/n}<pooh>vanmelle>lisp>iterate;4 created 27-Sep-88 12:35:33 ")

           (IL:P (IN-PACKAGE :ITERATE :USE '(:LISP :WALKER))
                 (EXPORT '(ITERATE ITERATE* GATHERING GATHER WITH-GATHERING INTERVAL ELEMENTS 
                                 LIST-ELEMENTS LIST-TAILS PLIST-ELEMENTS EACHTIME WHILE UNTIL 
                                 COLLECTING JOINING MAXIMIZING MINIMIZING SUMMING *ITERATE-WARNINGS*)
                        ))
           (IL:VARIABLES *ITERATE-WARNINGS*)
           

(IL:* IL:|;;;| "ITERATE macro")

           (IL:FUNCTIONS ITERATE SIMPLE-EXPAND-ITERATE-FORM)
           (IL:VARIABLES *ITERATE-TEMP-VARS-LIST*)
           (IL:FUNCTIONS OPTIMIZE-ITERATE-FORM EXPAND-INTO-LET VARIABLES-FROM-LET 
                  ITERATE-TRANSFORM-BODY PARSE-DECLARATIONS EXTRACT-SPECIAL-BINDINGS 
                  FUNCTION-LAMBDA-P RENAME-LET-BINDINGS RENAME-VARIABLES MV-SETQ VARIABLE-SAME-P 
                  MAYBE-WARN)
           
           (IL:* IL:|;;| "Sample iterators")

           (IL:FUNCTIONS INTERVAL LIST-ELEMENTS LIST-TAILS ELEMENTS PLIST-ELEMENTS SEQUENCE-ACCESSOR)
           
           (IL:* IL:|;;| "These \"iterators\" may be withdrawn")

           (IL:FUNCTIONS EACHTIME WHILE UNTIL)
                                                             (IL:* IL:\; "GATHERING macro")
           (IL:FUNCTIONS GATHERING WITH-GATHERING SIMPLE-EXPAND-GATHERING-FORM)
           (IL:VARIABLES *ACTIVE-GATHERERS* *ANONYMOUS-GATHERING-SITE*)
           (IL:FUNCTIONS OPTIMIZE-GATHERING-FORM RENAME-AND-CAPTURE-VARIABLES WALK-GATHERING-BODY)
           
           (IL:* IL:|;;| "Sample gatherers")

           (IL:FUNCTIONS COLLECTING JOINING MAXIMIZING MINIMIZING SUMMING)
                                                             (IL:* IL:\; 
                                           "Easier to read expanded code if PROG1 gets left alone ")
           (XCL:FILE-ENVIRONMENTS "ITERATE")))



(IL:* IL:|;;;| 
"************************************************************************* Copyright (c) 1985, 1986, 1987, 1988, 1989, 1990 Xerox Corporation. All rights reserved. Use and copying of this software and preparation of derivative works based upon this software are permitted.  Any distribution of this software or derivative works must comply with all applicable United States export control laws. This software is made available AS IS, and Xerox Corporation makes no warranty about the software, its performance or its conformity to any specification. Any person obtaining a copy of this software is requested to send their name and post office or electronic mail address to: CommonLoops Coordinator Xerox PARC 3333 Coyote Hill Rd. Palo Alto, CA 94304 (or send Arpanet mail to CommonLoops-Coordinator.pa@Xerox.arpa) Suggestions, comments and requests for improvements are also welcome. ************************************************************************* Original source {pooh/n}<pooh>vanmelle>lisp>iterate;4 created 27-Sep-88 12:35:33 "
)


(IN-PACKAGE :ITERATE :USE '(:LISP :WALKER))

(EXPORT '(ITERATE ITERATE* GATHERING GATHER WITH-GATHERING INTERVAL ELEMENTS LIST-ELEMENTS 
                LIST-TAILS PLIST-ELEMENTS EACHTIME WHILE UNTIL COLLECTING JOINING MAXIMIZING 
                MINIMIZING SUMMING *ITERATE-WARNINGS*))

(DEFVAR *ITERATE-WARNINGS* :ANY "Controls whether warnings are issued for iterate/gather forms that aren't optimized.
NIL => never; :USER => those resulting from user code; T => always, even if it's the iteration macro that's suboptimal."
)



(IL:* IL:|;;;| "ITERATE macro")


(DEFMACRO ITERATE (CLAUSES &BODY BODY &ENVIRONMENT ENV)
   (OPTIMIZE-ITERATE-FORM CLAUSES BODY ENV))

(DEFUN SIMPLE-EXPAND-ITERATE-FORM (CLAUSES BODY)

   (IL:* IL:|;;| 
 "Expand ITERATE.  This is the \"formal semantics\" expansion, which we never use. ")

   (LET*
    ((BLOCK-NAME (GENSYM))
     (BOUND-VAR-LISTS (MAPCAR #'(LAMBDA (CLAUSE)
                                       (LET ((NAMES (FIRST CLAUSE)))
                                            (IF (LISTP NAMES)
                                                NAMES
                                                (LIST NAMES))))
                             CLAUSES))
     (GENERATOR-VARS (MAPCAR #'(LAMBDA (CLAUSE)
                                      (DECLARE (IGNORE CLAUSE))
                                      (GENSYM))
                            CLAUSES)))
    `(BLOCK ,BLOCK-NAME
         (LET*
          ,(MAPCAN #'(LAMBDA (GVAR CLAUSE VAR-LIST)          (IL:* IL:\; 
            "For each clause, bind a generator temp to the clause, then bind the specified var(s) ")
                            (CONS (LIST GVAR (SECOND CLAUSE))
                                  (COPY-LIST VAR-LIST)))
                  GENERATOR-VARS CLAUSES BOUND-VAR-LISTS)

          (IL:* IL:|;;| "Note bug in formal semantics: there can be declarations in the head of BODY; they go here, rather than inside loop ")

          (LOOP ,@(MAPCAR #'(LAMBDA (VAR-LIST GEN-VAR)       (IL:* IL:\; 
   "Set each bound variable (or set of vars) to the result of calling the corresponding generator ")
                                   `(MULTIPLE-VALUE-SETQ ,VAR-LIST
                                           (FUNCALL ,GEN-VAR #'(LAMBDA NIL (RETURN-FROM ,BLOCK-NAME))
                                                  )))
                         BOUND-VAR-LISTS GENERATOR-VARS)
                ,@BODY)))))

(DEFPARAMETER *ITERATE-TEMP-VARS-LIST* '(ITERATE-TEMP-1 ITERATE-TEMP-2 ITERATE-TEMP-3 
                                                   ITERATE-TEMP-4 ITERATE-TEMP-5 ITERATE-TEMP-6 
                                                   ITERATE-TEMP-7 ITERATE-TEMP-8)
                                           "Temp var names used by ITERATE expansions.")

(DEFUN OPTIMIZE-ITERATE-FORM (CLAUSES BODY ITERATE-ENV)
   (LET*
    ((TEMP-VARS *ITERATE-TEMP-VARS-LIST*)
     (BLOCK-NAME (GENSYM))
     (FINISH-FORM `(RETURN-FROM ,BLOCK-NAME))
     (BOUND-VARS (MAPCAN #'(LAMBDA (CLAUSE)
                                  (LET ((NAMES (FIRST CLAUSE)))
                                       (IF (LISTP NAMES)
                                           (COPY-LIST NAMES)
                                           (LIST NAMES))))
                        CLAUSES))
     ITERATE-DECLS GENERATOR-DECLS UPDATE-FORMS BINDINGS LEFTOVER-BODY)
    (DO ((TAIL BOUND-VARS (CDR TAIL)))
        ((NULL TAIL))                                        (IL:* IL:\; "Check for duplicates")
      (WHEN (MEMBER (CAR TAIL)
                   (CDR TAIL))
          (WARN "Variable appears more than once in ITERATE: ~S" (CAR TAIL))))
    (FLET
     ((GET-ITERATE-TEMP NIL 

             (IL:* IL:|;;| "Make temporary var.  Note that it is ok to re-use these symbols in each iterate, because they are not used within BODY. ")

             (OR (POP TEMP-VARS)
                 (GENSYM))))
     (DOLIST (CLAUSE CLAUSES)
         (COND
            ((OR (NOT (CONSP CLAUSE))
                 (NOT (CONSP (CDR CLAUSE))))
             (WARN "Bad syntax in ITERATE: clause not of form (var iterator): ~S" CLAUSE))
            (T
             (UNLESS (NULL (CDDR CLAUSE))
                    (WARN "Probable parenthesis error in ITERATE clause--more than 2 elements: ~S" 
                          CLAUSE))
             (MULTIPLE-VALUE-BIND (LET-BODY BINDING-TYPE LET-BINDINGS LOCALDECLS OTHERDECLS 
                                         EXTRA-BODY)
                 (EXPAND-INTO-LET (SECOND CLAUSE)
                        'ITERATE ITERATE-ENV)

               (IL:* IL:|;;| 
             "We have expanded the generator clause and parsed it into its LET pieces. ")

               (PROG* ((VARS (FIRST CLAUSE))
                       GEN-ARGS RENAMED-VARS)
                      (SETQ VARS (IF (LISTP VARS)
                                     (COPY-LIST VARS)
                                     (LIST VARS)))           (IL:* IL:\; 
                           "VARS is now a (fresh) list of all iteration vars bound in this clause ")
                      (COND
                         ((EQ LET-BODY :ABORT)               (IL:* IL:\; 
                                                    "Already issued a warning about malformedness ")
                          )
                         ((NULL (SETQ LET-BODY (FUNCTION-LAMBDA-P LET-BODY 1)))
                                                             (IL:* IL:\; "Not of the expected form")
                          (LET ((GENERATOR (SECOND CLAUSE)))
                               (COND
                                  ((AND (CONSP GENERATOR)
                                        (FBOUNDP (CAR GENERATOR)))
                                                             (IL:* IL:\; "It looks ok--a macro or function here--so the guy who wrote it just didn't do it in an optimizable way ")
                                   (MAYBE-WARN :DEFINITION "Could not optimize iterate clause ~S because generator not of form (LET[*] ... (FUNCTION (LAMBDA (finish) ...)))"
                                          GENERATOR))
                                  (T                         (IL:* IL:\; 
                                           "Perhaps it's just a misspelling?  Probably user error ")
                                     (MAYBE-WARN :USER 
                                            "Iterate operator in clause ~S is not fboundp." GENERATOR
                                            )))
                               (SETQ LET-BODY :ABORT)))
                         (T

                          (IL:* IL:|;;| "We have something of the form #'(LAMBDA (finisharg) ...), possibly with some LET bindings around it.  LET-BODY = ((finisharg) ...). ")

                          (SETQ LET-BODY (CDR LET-BODY))
                          (SETQ GEN-ARGS (POP LET-BODY))
                          (WHEN LET-BINDINGS

                              (IL:* IL:|;;| "The first transformation we want to perform is \"LET-eversion\": turn (let* ((generator (let (..bindings..) #'(lambda ...)))) ..body..) into (let* (..bindings.. (generator #'(lambda ...))) ..body..).  This transformation is valid if nothing in body refers to any of the bindings, something we can assure by alpha-converting the inner let (substituting new names for each var).  Of course, none of those vars can be special, but we already checked for that above. ")

                              (MULTIPLE-VALUE-SETQ (LET-BINDINGS RENAMED-VARS)
                                     (RENAME-LET-BINDINGS LET-BINDINGS BINDING-TYPE ITERATE-ENV 
                                            LEFTOVER-BODY #'GET-ITERATE-TEMP))
                              (SETQ LEFTOVER-BODY NIL)       (IL:* IL:\; 
                                     "If there was any leftover from previous, it is now consumed ")
                              )

                          (IL:* IL:|;;| "The second transformation is substituting the body of the generator (LAMBDA (finish-arg) . gen-body) for its appearance in the update form (funcall generator #'(lambda () finish-form)), then simplifying that form.  The requirement for this part is that the generator body not refer to any variables that are bound between the generator binding and the appearance in the loop body.  The only variables bound in that interval are generator temporaries, which have unique names so are no problem, and the iteration variables remaining for subsequent clauses.  We'll discover the story as we walk the body. ")

                          (MULTIPLE-VALUE-BIND (FINISHDECL OTHER REST)
                              (PARSE-DECLARATIONS LET-BODY GEN-ARGS)
                            (DECLARE (IGNORE FINISHDECL))(IL:* IL:\; "Pull out declares, if any, separating out the one(s) referring to the finish arg, which we will throw away ")
                            (WHEN OTHER                      (IL:* IL:\; 
                               "Combine remaining decls with decls extracted from the LET, if any ")
                                (SETQ OTHERDECLS (NCONC OTHERDECLS OTHER)))
                            (SETQ LET-BODY (COND
                                              (OTHERDECLS    (IL:* IL:\; 
                                 "There are interesting declarations, so have to keep it wrapped. ")
                                                     `(LET NIL (DECLARE ,@OTHERDECLS)
                                                           ,@REST))
                                              ((NULL (CDR REST))
                                                             (IL:* IL:\; "Only one form left")
                                               (FIRST REST))
                                              (T `(PROGN ,@REST)))))
                          (UNLESS (EQ (SETQ LET-BODY (ITERATE-TRANSFORM-BODY LET-BODY ITERATE-ENV
                                                            RENAMED-VARS (FIRST GEN-ARGS)
                                                            FINISH-FORM BOUND-VARS CLAUSE))
                                      :ABORT)

                              (IL:* IL:|;;| "Skip the rest if transformation failed.  Warning has already been issued. Note possible further optimization: if LET-BODY expanded into (prog1 oldvalue prepare-for-next-iteration), as so many do, then we could in most cases split the PROG1 into two pieces: do the (setq var oldvalue) here, and do the prepare-for-next-iteration at the bottom of the loop. This does a slight optimization of the PROG1 and also rearranges the code in a way that a reasonably clever compiler might detect how to get rid of redundant variables altogether (such as happens with INTERVAL and LIST-TAILS); that would make the whole thing closer to what you might have coded by hand.  However, to do this optimization, we need to assure that (a) the prepare-for-next-iteration refers freely to no vars other than the internal vars we have extracted from the LET, and (b) that the code has no side effects.  These are both true for all the iterators defined by this module, but how shall we represent side-effect info and/or tap into the compiler's knowledge of same? ")

                              (WHEN LOCALDECLS               (IL:* IL:\; "There were declarations for the generator locals--have to keep them for later, and rename the vars mentioned ")
                                  (SETQ
                                   GENERATOR-DECLS
                                   (NCONC
                                    GENERATOR-DECLS
                                    (MAPCAR
                                     #'(LAMBDA (DECL)
                                              (LET ((HEAD (CAR DECL)))
                                                   (CONS HEAD (IF (EQ HEAD 'TYPE)
                                                                  (CONS (SECOND DECL)
                                                                        (SUBLIS RENAMED-VARS
                                                                               (CDDR DECL)))
                                                                  (SUBLIS RENAMED-VARS (CDR DECL)))))
                                              )
                                     LOCALDECLS)))))))

                (IL:* IL:|;;| "Finished analyzing clause now.  LET-BODY is the form which, when evaluated, returns updated values for the iteration variable(s) VARS. ")

                      (WHEN (EQ LET-BODY :ABORT)

                          (IL:* IL:|;;| "Some punt case: go with the formal semantics: bind a var to the generator, then call it in the update section ")

                          (LET ((GVAR (GET-ITERATE-TEMP))
                                (GENERATOR (SECOND CLAUSE)))
                               (SETQ LET-BINDINGS
                                     (LIST (LIST GVAR
                                                 (COND
                                                    (LEFTOVER-BODY
                                                             (IL:* IL:\; "Have to use this up")
                                                     `(PROGN ,@(PROG1 LEFTOVER-BODY (SETQ 
                                                                                        LEFTOVER-BODY
                                                                                          NIL))
                                                             GENERATOR))
                                                    (T GENERATOR)))))
                               (SETQ LET-BODY `(FUNCALL ,GVAR #'(LAMBDA NIL ,FINISH-FORM)))))
                      (PUSH (MV-SETQ (COPY-LIST VARS)
                                   LET-BODY)
                            UPDATE-FORMS)
                      (DOLIST (V VARS)
                          (DECLARE (IGNORE V))           (IL:* IL:\; "Pop off the vars we have now bound from the list of vars to watch out for--we'll bind them right now ")
                          (POP BOUND-VARS))
                      (SETQ BINDINGS (NCONC BINDINGS LET-BINDINGS
                                            (COND
                                               (EXTRA-BODY   (IL:* IL:\; 
                          "There was some computation to do after the bindings--here's our chance ")
                                                      (CONS (LIST (FIRST VARS)
                                                                  `(PROGN ,@EXTRA-BODY NIL))
                                                            (REST VARS)))
                                               (T VARS))))))))))
    (DO ((TAIL BODY (CDR TAIL)))
        ((NOT (AND (CONSP TAIL)
                   (CONSP (CAR TAIL))
                   (EQ (CAAR TAIL)
                       'DECLARE)))

         (IL:* IL:|;;| "TAIL now points at first non-declaration.  If there were declarations, pop them off so they appear in the right place ")

         (UNLESS (EQ TAIL BODY)
             (SETQ ITERATE-DECLS (LDIFF BODY TAIL))
             (SETQ BODY TAIL))))
    `(BLOCK ,BLOCK-NAME
         (LET* ,BINDINGS ,@(AND GENERATOR-DECLS `((DECLARE ,@GENERATOR-DECLS)))
               ,@ITERATE-DECLS
               ,@LEFTOVER-BODY
               (LOOP ,@(NREVERSE UPDATE-FORMS)
                     ,@BODY)))))

(DEFUN EXPAND-INTO-LET (CLAUSE PARENT-NAME ENV)

   (IL:* IL:|;;| "Return values: Body, LET[*], bindings, localdecls, otherdecls, extra body, where BODY is a single form.  If multiple forms in a LET, the preceding forms are returned as extra body.  Returns :ABORT if it issued a punt warning. ")

   (PROG ((EXPANSION CLAUSE)
          EXPANDEDP BINDING-TYPE LET-BINDINGS LET-BODY)
     EXPAND
         (MULTIPLE-VALUE-SETQ (EXPANSION EXPANDEDP)
                (MACROEXPAND-1 EXPANSION ENV))
         (COND
            ((NOT (CONSP EXPANSION))                         (IL:* IL:\; "Shouldn't happen")
             )
            ((SYMBOLP (SETQ BINDING-TYPE (FIRST EXPANSION)))
             (CASE BINDING-TYPE
                 ((LET LET*) 
                    (SETQ LET-BINDINGS (SECOND EXPANSION))   (IL:* IL:\; 
                                                           "List of variable bindings")
                    (SETQ LET-BODY (CDDR EXPANSION))
                    (GO HANDLE-LET))))
            ((AND (CONSP BINDING-TYPE)
                  (EQ (CAR BINDING-TYPE)
                      'LAMBDA)
                  (NOT (FIND-IF #'(LAMBDA (X)
                                         (MEMBER X LAMBDA-LIST-KEYWORDS))
                              (SETQ LET-BINDINGS (SECOND BINDING-TYPE))))
                  (EQL (LENGTH (SECOND EXPANSION))
                       (LENGTH LET-BINDINGS))
                  (NULL (CDDR EXPANSION)))                   (IL:* IL:\; 
                                                      "A simple LAMBDA form can be treated as LET ")
             (SETQ LET-BODY (CDDR BINDING-TYPE))
             (SETQ LET-BINDINGS (MAPCAR #'LIST LET-BINDINGS (SECOND EXPANSION)))
             (SETQ BINDING-TYPE 'LET)
             (GO HANDLE-LET)))

    (IL:* IL:|;;| "Fall thru if not a LET")

         (COND
            (EXPANDEDP                                       (IL:* IL:\; "try expanding again")
                   (GO EXPAND))
            (T                                               (IL:* IL:\; 
                                                           "Boring--return form as the body ")
               (RETURN EXPANSION)))
     HANDLE-LET
         (RETURN (LET ((LOCALS (VARIABLES-FROM-LET LET-BINDINGS))
                       EXTRA-BODY SPECIALS)
                      (MULTIPLE-VALUE-BIND (LOCALDECLS OTHERDECLS LET-BODY)
                          (PARSE-DECLARATIONS LET-BODY LOCALS)
                        (COND
                           ((SETQ SPECIALS (EXTRACT-SPECIAL-BINDINGS LOCALS LOCALDECLS))
                            (MAYBE-WARN (COND
                                               ((FIND-IF #'VARIABLE-GLOBALLY-SPECIAL-P SPECIALS)
                                                             (IL:* IL:\; 
                                                  "This could be the fault of a user proclamation ")
                                                :USER)
                                               (T :DEFINITION))
                                   
                                "Couldn't optimize ~S because expansion of ~S binds specials ~(~S ~)"
                                   PARENT-NAME CLAUSE SPECIALS)
                            :ABORT)
                           (T (VALUES (COND
                                         ((NOT (CONSP LET-BODY))
                                                             (IL:* IL:\; 
                              "Null body of LET?  unlikely, but someone else will likely complain ")
                                          NIL)
                                         ((NULL (CDR LET-BODY))
                                                             (IL:* IL:\; 
                                    "A single expression, which we hope is (function (lambda...)) ")
                                          (FIRST LET-BODY))
                                         (T 

                                 (IL:* IL:|;;| "More than one expression.  These are forms to evaluate after the bindings but before the generator form is returned.  Save them to evaluate in the next convenient place.  Note that this is ok, as there is no construct that can cause a LET to return prematurely (without returning also from some surrounding construct). ")

                                            (SETQ EXTRA-BODY (BUTLAST LET-BODY))
                                            (CAR (LAST LET-BODY))))
                                     BINDING-TYPE LET-BINDINGS LOCALDECLS OTHERDECLS EXTRA-BODY))))))
    ))

(DEFUN VARIABLES-FROM-LET (BINDINGS)

   (IL:* IL:|;;| "Return a list of the variables bound in the first argument to LET[*].")

   (MAPCAR #'(LAMBDA (BINDING)
                    (IF (CONSP BINDING)
                        (FIRST BINDING)
                        BINDING))
          BINDINGS))

(DEFUN ITERATE-TRANSFORM-BODY (LET-BODY ITERATE-ENV RENAMED-VARS FINISH-ARG FINISH-FORM 
                                         BOUND-VARS CLAUSE)

(IL:* IL:|;;;| "This is the second major transformation for a single iterate clause. LET-BODY is the body of the iterator after we have extracted its local variables and declarations.  We have two main tasks: (1) Substitute internal temporaries for occurrences of the LET variables; the alist RENAMED-VARS specifies this transformation.  (2) Substitute evaluation of FINISH-FORM for any occurrence of (funcall FINISH-ARG).  Along the way, we check for forms that would invalidate these transformations: occurrence of FINISH-ARG outside of a funcall, and free reference to any element of BOUND-VARS.  CLAUSE & TYPE are the original ITERATE clause and its type (ITERATE or ITERATE*), for purpose of error messages.  On success, we return the transformed body; on failure, :ABORT. ")

   (WALK-FORM LET-BODY ITERATE-ENV #'(LAMBDA (FORM CONTEXT ENV)
                                            (DECLARE (IGNORE CONTEXT))

                                            (IL:* IL:|;;| 
      "Need to substitute RENAMED-VARS, as well as turn (FUNCALL finish-arg) into the finish form ")

                                            (COND
                                               ((SYMBOLP FORM)
                                                (LET (RENAMING)
                                                     (COND
                                                        ((AND (EQ FORM FINISH-ARG)
                                                              (VARIABLE-SAME-P FORM ENV 
                                                                     ITERATE-ENV))
                                                             (IL:* IL:\; 
                 "An occurrence of the finish arg outside of FUNCALL context--I can't handle this ")
                                                         (MAYBE-WARN :DEFINITION "Couldn't optimize iterate form because generator ~S does something with its FINISH arg besides FUNCALL it."
                                                                (SECOND CLAUSE))
                                                         (RETURN-FROM ITERATE-TRANSFORM-BODY :ABORT))
                                                        ((AND (SETQ RENAMING (ASSOC FORM RENAMED-VARS
                                                                                    ))
                                                              (VARIABLE-SAME-P FORM ENV 
                                                                     ITERATE-ENV))
                                                             (IL:* IL:\; 
                                                     "Reference to one of the vars we're renaming ")
                                                         (CDR RENAMING))
                                                        ((AND (MEMBER FORM BOUND-VARS)
                                                              (VARIABLE-SAME-P FORM ENV 
                                                                     ITERATE-ENV))
                                                             (IL:* IL:\; "FORM is a var that is bound in this same ITERATE, or bound later in this ITERATE*. This is a conflict. ")
                                                         (MAYBE-WARN :USER "Couldn't optimize iterate form because generator ~S is closed over ~S, in conflict with a subsequent iteration variable."
                                                                (SECOND CLAUSE)
                                                                FORM)
                                                         (RETURN-FROM ITERATE-TRANSFORM-BODY :ABORT))
                                                        (T FORM))))
                                               ((AND (CONSP FORM)
                                                     (EQ (FIRST FORM)
                                                         'FUNCALL)
                                                     (EQ (SECOND FORM)
                                                         FINISH-ARG)
                                                     (VARIABLE-SAME-P (SECOND FORM)
                                                            ENV ITERATE-ENV))
                                                             (IL:* IL:\; 
                                                           "(FUNCALL finish-arg) => finish-form ")
                                                (UNLESS (NULL (CDDR FORM))
                                                    (MAYBE-WARN :DEFINITION 
                              "Generator for ~S applied its finish arg to > 0 arguments ~S--ignored."
                                                           (SECOND CLAUSE)
                                                           (CDDR FORM)))
                                                FINISH-FORM)
                                               (T FORM)))))

(DEFUN PARSE-DECLARATIONS (TAIL LOCALS)

   (IL:* IL:|;;| "Extract the declarations from the head of TAIL and divide them into 2 classes: declares about variables in the list LOCALS, and all other declarations.  Returns 3 values: those 2 lists plus the remainder of TAIL. ")

   (LET
    (LOCALDECLS OTHERDECLS FORM)
    (LOOP
     (UNLESS (AND TAIL (CONSP (SETQ FORM (CAR TAIL)))
                  (EQ (CAR FORM)
                      'DECLARE))
         (RETURN (VALUES LOCALDECLS OTHERDECLS TAIL)))
     (MAPC
      #'(LAMBDA (DECL)
               (CASE (FIRST DECL)
                   ((INLINE NOTINLINE OPTIMIZE)              (IL:* IL:\; 
                                                           "These don't talk about vars")
                      (PUSH DECL OTHERDECLS))
                   (T                                        (IL:* IL:\; 
                                                           "Assume all other kinds are for vars ")
                      (LET* ((VARS (IF (EQ (FIRST DECL)
                                           'TYPE)
                                       (CDDR DECL)
                                       (CDR DECL)))
                             (L (INTERSECTION LOCALS VARS))
                             OTHER)
                            (COND
                               ((NULL L)                     (IL:* IL:\; "None talk about LOCALS")
                                (PUSH DECL OTHERDECLS))
                               ((NULL (SETQ OTHER (SET-DIFFERENCE VARS L)))
                                                             (IL:* IL:\; "All talk about LOCALS")
                                (PUSH DECL LOCALDECLS))
                               (T                            (IL:* IL:\; "Some of each")
                                  (LET ((HEAD (CONS 'TYPE (AND (EQ (FIRST DECL)
                                                                   'TYPE)
                                                               (LIST (SECOND DECL))))))
                                       (PUSH (APPEND HEAD OTHER)
                                             OTHERDECLS)
                                       (PUSH (APPEND HEAD L)
                                             LOCALDECLS))))))))
      (CDR FORM))
     (POP TAIL))))

(DEFUN EXTRACT-SPECIAL-BINDINGS (VARS DECLS)

   (IL:* IL:|;;| 
"Return the subset of VARS that are special, either globally or because of a declaration in DECLS ")

   (LET ((SPECIALS (REMOVE-IF-NOT #'VARIABLE-GLOBALLY-SPECIAL-P VARS)))
        (DOLIST (D DECLS)
            (WHEN (EQ (CAR D)
                      'SPECIAL)
                (SETQ SPECIALS (UNION SPECIALS (INTERSECTION VARS (CDR D))))))
        SPECIALS))

(DEFUN FUNCTION-LAMBDA-P (FORM &OPTIONAL NARGS)

   (IL:* IL:|;;| "If FORM is #'(LAMBDA bindings . body) and bindings is of length NARGS, return the lambda expression ")

   (LET (ARGS BODY)
        (AND (CONSP FORM)
             (EQ (CAR FORM)
                 'FUNCTION)
             (CONSP (SETQ FORM (CDR FORM)))
             (NULL (CDR FORM))
             (CONSP (SETQ FORM (CAR FORM)))
             (EQ (CAR FORM)
                 'LAMBDA)
             (CONSP (SETQ BODY (CDR FORM)))
             (LISTP (SETQ ARGS (CAR BODY)))
             (OR (NULL NARGS)
                 (EQL (LENGTH ARGS)
                      NARGS))
             FORM)))

(DEFUN RENAME-LET-BINDINGS (LET-BINDINGS BINDING-TYPE ENV LEFTOVER-BODY &OPTIONAL TEMPVARFN)

   (IL:* IL:|;;| "Perform the alpha conversion required for \"LET eversion\" of (LET[*] LET-BINDINGS . body)--rename each of the variables to an internal name. Returns 2 values: a new set of LET bindings and the alist of old var names to new (so caller can walk the body doing the rest of the renaming). BINDING-TYPE is one of LET or LET*.  LEFTOVER-BODY is optional list of forms that must be eval'ed before the first binding happens.  ENV is the macro expansion environment, in case we have to walk a LET*.  TEMPVARFN is a function of no args to return a temporary var; if omitted, we use GENSYM. ")

   (LET (RENAMED-VARS)
        (VALUES (MAPCAR #'(LAMBDA (BINDING)
                                 (LET ((VALUEFORM (COND
                                                     ((NOT (CONSP BINDING))
                                                             (IL:* IL:\; "No initial value")
                                                      NIL)
                                                     ((OR (EQ BINDING-TYPE 'LET)
                                                          (NULL RENAMED-VARS))
                                                             (IL:* IL:\; 
                                       "All bindings are in parallel, so none can refer to others ")
                                                      (SECOND BINDING))
                                                     (T      (IL:* IL:\; 
               "In a LET*, have to substitute vars in the 2nd and subsequent initialization forms ")
                                                        (RENAME-VARIABLES (SECOND BINDING)
                                                               RENAMED-VARS ENV))))
                                       (NEWVAR (IF TEMPVARFN
                                                   (FUNCALL TEMPVARFN)
                                                   (GENSYM))))
                                      (PUSH (CONS (IF (CONSP BINDING)
                                                      (FIRST BINDING)
                                                      BINDING)
                                                  NEWVAR)
                                            RENAMED-VARS)    (IL:* IL:\; 
                        "Add new variable to the list AFTER we have walked the initial value form ")
                                      (WHEN LEFTOVER-BODY

                                          (IL:* IL:|;;| "Previous clause had some computation to do after its bindings.  Here is the first opportunity to do it ")

                                          (SETQ VALUEFORM `(PROGN ,@LEFTOVER-BODY ,VALUEFORM))
                                          (SETQ LEFTOVER-BODY NIL))
                                      (LIST NEWVAR VALUEFORM)))
                       LET-BINDINGS)
               RENAMED-VARS)))

(DEFUN RENAME-VARIABLES (FORM ALIST ENV)

   (IL:* IL:|;;| "Walks FORM, renaming occurrences of the key variables in ALIST with their corresponding values.  ENV is FORM's environment, so we can make sure we are talking about the same variables. ")

   (WALK-FORM FORM ENV #'(LAMBDA (FORM CONTEXT SUBENV)
                                (DECLARE (IGNORE CONTEXT))
                                (LET (PAIR)
                                     (COND
                                        ((AND (SYMBOLP FORM)
                                              (SETQ PAIR (ASSOC FORM ALIST))
                                              (VARIABLE-SAME-P FORM SUBENV ENV))
                                         (CDR PAIR))
                                        (T FORM))))))

(DEFUN MV-SETQ (VARS EXPR)

   (IL:* IL:|;;| "Produces (MULTIPLE-VALUE-SETQ vars expr), except that I'll optimize some of the simple cases for benefit of compilers that don't, and I don't care what the value is, and I know that the variables need not be set in parallel, since they can't be used free in EXPR ")

   (COND
      ((NULL VARS)                                           (IL:* IL:\; "EXPR is a side-effect")
       EXPR)
      ((NOT (CONSP VARS))                                    (IL:* IL:\; 
                                    "This is an error, but I'll let MULTIPLE-VALUE-SETQ report it ")
       `(MULTIPLE-VALUE-SETQ ,VARS ,EXPR))
      ((AND (LISTP EXPR)
            (EQ (CAR EXPR)
                'VALUES))

       (IL:* IL:|;;| "(mv-setq (a b c) (values x y z)) can be reduced to a parallel setq (psetq returns nil, but I don't care about returned value).  Do this even for the single variable case so that we catch (mv-setq (a) (values x y)) ")

       (POP EXPR)                                            (IL:* IL:\; "VALUES")
       `(SETQ ,@(MAPCON #'(LAMBDA (TAIL)
                                 (LIST (CAR TAIL)
                                       (COND
                                          ((OR (CDR TAIL)
                                               (NULL (CDR EXPR)))
                                                             (IL:* IL:\; 
                                                           "One result expression for this var ")
                                           (POP EXPR))
                                          (T                 (IL:* IL:\; 
                            "More expressions than vars, so arrange to evaluate all the rest now. ")
                                             (CONS 'PROG1 EXPR)))))
                       VARS)))
      ((NULL (CDR VARS))                                     (IL:* IL:\; "Simple one variable case")
       `(SETQ ,(CAR VARS)
              ,EXPR))
      (T                                                     (IL:* IL:\; 
                                                           "General case--I know nothing")
         `(MULTIPLE-VALUE-SETQ ,VARS ,EXPR))))

(DEFUN VARIABLE-SAME-P (VAR ENV1 ENV2)
   (EQ (VARIABLE-LEXICAL-P VAR ENV1)
       (VARIABLE-LEXICAL-P VAR ENV2)))

(DEFUN MAYBE-WARN (TYPE &REST WARN-ARGS)

   (IL:* IL:|;;| "Issue a warning about not being able to optimize this thing.  TYPE is one of :DEFINITION, meaning the definition is at fault, and :USER, meaning the user's code is at fault. ")

   (WHEN (CASE *ITERATE-WARNINGS*
             ((NIL) NIL)
             ((:USER) (EQ TYPE :USER))
             (T T))
       (APPLY #'WARN WARN-ARGS)))



(IL:* IL:|;;| "Sample iterators")


(DEFMACRO INTERVAL (&WHOLE WHOLE &KEY FROM DOWNFROM TO DOWNTO ABOVE BELOW BY TYPE)
   (COND
      ((AND FROM DOWNFROM)
       (ERROR "Can't use both FROM and DOWNFROM in ~S" WHOLE))
      ((CDR (REMOVE NIL (LIST TO DOWNTO ABOVE BELOW)))
       (ERROR "Can't use more than one limit keyword in ~S" WHOLE))
      (T
       (LET*
        ((DOWN (OR DOWNFROM DOWNTO ABOVE))
         (LIMIT (OR TO DOWNTO ABOVE BELOW))
         (INC (COND
                 ((NULL BY)
                  1)
                 ((CONSTANTP BY)                             (IL:* IL:\; 
                                                           "Can inline this increment")
                  BY))))
        `(LET ((FROM ,(OR FROM DOWNFROM 0))
               ,@(AND LIMIT `((TO ,LIMIT)))
               ,@(AND (NULL INC)
                      `((BY ,BY))))
              ,@(AND TYPE `((DECLARE (TYPE ,TYPE FROM ,@(AND LIMIT '(TO))
                                               ,@(AND (NULL INC)
                                                      `(BY))))))
              #'(LAMBDA (FINISH)
                       ,@(COND
                            ((NULL LIMIT)                    (IL:* IL:\; 
                                                           "We won't use the FINISH arg")
                             '((DECLARE (IGNORE FINISH)))))
                       (PROG1 ,(COND
                                  (LIMIT                     (IL:* IL:\; 
                           "Test the limit.  If ok, return current value and increment, else quit ")
                                         `(IF (,(COND
                                                   (ABOVE '>)
                                                   (BELOW '<)
                                                   (DOWN '>=)
                                                   (T '<=))
                                               FROM TO)
                                              FROM
                                              (FUNCALL FINISH)))
                                  (T                         (IL:* IL:\; "No test")
                                     'FROM))
                           (SETQ FROM (,(IF DOWN
                                            '-
                                            '+)
                                       FROM
                                       ,(OR INC 'BY))))))))))

(DEFMACRO LIST-ELEMENTS (LIST &KEY (BY '#'CDR))
   `(LET ((TAIL ,LIST))
         #'(LAMBDA (FINISH)
                  (PROG1 (IF (ENDP TAIL)
                             (FUNCALL FINISH)
                             (FIRST TAIL))
                      (SETQ TAIL (FUNCALL ,BY TAIL))))))

(DEFMACRO LIST-TAILS (LIST &KEY (BY '#'CDR))
   `(LET ((TAIL ,LIST))
         #'(LAMBDA (FINISH)
                  (PROG1 (IF (ENDP TAIL)
                             (FUNCALL FINISH)
                             TAIL)
                      (SETQ TAIL (FUNCALL ,BY TAIL))))))

(DEFMACRO ELEMENTS (SEQUENCE)
   "Generates successive elements of SEQUENCE, with second value being the index.  Use (ELEMENTS (THE type arg)) if you care about the type."
   (LET* ((TYPE (AND (CONSP SEQUENCE)
                     (EQ (FIRST SEQUENCE)
                         'THE)
                     (SECOND SEQUENCE)))
          (ACCESSOR (IF TYPE
                        (SEQUENCE-ACCESSOR TYPE)
                        'ELT))
          (LISTP (EQ TYPE 'LIST)))

         (IL:* IL:|;;| "If type is given via THE, we may be able to generate a good accessor here for the benefit of implementations that aren't smart about (ELT (THE STRING FOO)).  I'm not bothering to keep the THE inside the body, however, since I assume any compiler that would understand (AREF (THE SIMPLE-ARRAY S)) would also understand that (AREF S) is the same when I bound S to (THE SIMPLE-ARRAY foo) and never modified it. If sequence is declared to be a list, it's better to cdr down it, so we have some extra cases here.  Normally folks would write LIST-ELEMENTS, but maybe they wanted to get the index for free... ")

         `(LET* ((INDEX 0)
                 (S ,SEQUENCE)
                 ,@(AND (NOT LISTP)
                        '((SIZE (LENGTH S)))))
                #'(LAMBDA (FINISH)
                         (VALUES (COND
                                    ,(IF LISTP
                                         '((NOT (ENDP S))
                                           (POP S))
                                         `((< INDEX SIZE)
                                           (,ACCESSOR S INDEX)))
                                    (T (FUNCALL FINISH)))
                                (PROG1 INDEX
                                    (SETQ INDEX (1+ INDEX))))))))

(DEFMACRO PLIST-ELEMENTS (PLIST)
   "Generates each time 2 items, the indicator and the value."
   `(LET ((TAIL ,PLIST))
         #'(LAMBDA (FINISH)
                  (VALUES (IF (ENDP TAIL)
                              (FUNCALL FINISH)
                              (FIRST TAIL))
                         (PROG1 (IF (ENDP (SETQ TAIL (CDR TAIL)))
                                    (FUNCALL FINISH)
                                    (FIRST TAIL))
                             (SETQ TAIL (CDR TAIL)))))))

(DEFUN SEQUENCE-ACCESSOR (TYPE)

   (IL:* IL:|;;| 
 "returns the function with which most efficiently to make accesses to a sequence of type TYPE. ")

   (CASE (IF (CONSP TYPE)                                    (IL:* IL:\; "e.g., (VECTOR FLOAT *)")
             (CAR TYPE)
             TYPE)
       ((ARRAY SIMPLE-ARRAY VECTOR) 'AREF)
       (SIMPLE-VECTOR 'SVREF)
       (STRING 'CHAR)
       (SIMPLE-STRING 'SCHAR)
       (BIT-VECTOR 'BIT)
       (SIMPLE-BIT-VECTOR 'SBIT)
       (T 'ELT)))



(IL:* IL:|;;| "These \"iterators\" may be withdrawn")


(DEFMACRO EACHTIME (EXPR)
   `#'(LAMBDA (FINISH)
             (DECLARE (IGNORE FINISH))
             ,EXPR))

(DEFMACRO WHILE (EXPR)
   `#'(LAMBDA (FINISH)
             (UNLESS ,EXPR (FUNCALL FINISH))))

(DEFMACRO UNTIL (EXPR)
   `#'(LAMBDA (FINISH)
             (WHEN ,EXPR (FUNCALL FINISH))))



(IL:* IL:\; "GATHERING macro")


(DEFMACRO GATHERING (CLAUSES &BODY BODY &ENVIRONMENT ENV)
   (OR (OPTIMIZE-GATHERING-FORM CLAUSES BODY ENV)
       (SIMPLE-EXPAND-GATHERING-FORM CLAUSES BODY ENV)))

(DEFMACRO WITH-GATHERING (CLAUSES GATHER-BODY &BODY USE-BODY)
   "Binds the variables specified in CLAUSES to the result of (GATHERING clauses gather-body) and evaluates the forms in USE-BODY inside that contour."

   (IL:* IL:|;;| "We may optimize this a little better later for those compilers that don't do a good job on (m-v-bind vars (... (values ...)) ...). ")

   `(MULTIPLE-VALUE-BIND ,(MAPCAR #'CAR CLAUSES)
        (GATHERING ,CLAUSES ,GATHER-BODY)
      ,@USE-BODY))

(DEFUN SIMPLE-EXPAND-GATHERING-FORM (CLAUSES BODY ENV)
   (DECLARE (IGNORE ENV))

   (IL:* IL:|;;| 
 "The \"formal semantics\" of GATHERING.  We use this only in cases that can't be optimized. ")

   (LET
    ((ACC-NAMES (MAPCAR #'FIRST (IF (SYMBOLP CLAUSES)        (IL:* IL:\; 
                                                        "Shorthand using anonymous gathering site ")
                                    (SETQ CLAUSES `((*ANONYMOUS-GATHERING-SITE* (,CLAUSES))))
                                    CLAUSES)))
     (REALIZER-NAMES (MAPCAR #'(LAMBDA (BINDING)
                                      (DECLARE (IGNORE BINDING))
                                      (GENSYM))
                            CLAUSES)))
    `(MULTIPLE-VALUE-CALL
      #'(LAMBDA ,(MAPCAN #'LIST ACC-NAMES REALIZER-NAMES)
               (FLET ((GATHER (VALUE &OPTIONAL (ACCUMULATOR *ANONYMOUS-GATHERING-SITE*))
                             (FUNCALL ACCUMULATOR VALUE)))
                     ,@BODY
                     (VALUES ,@(MAPCAR #'(LAMBDA (RNAME)
                                                `(FUNCALL ,RNAME))
                                      REALIZER-NAMES))))
      ,@(MAPCAR #'SECOND CLAUSES))))

(DEFVAR *ACTIVE-GATHERERS* NIL
   "List of GATHERING bindings currently active during macro expansion)")

(DEFVAR *ANONYMOUS-GATHERING-SITE* NIL
   "Variable used in formal expansion of an abbreviated GATHERING form (one with anonymous gathering site)."
)

(DEFUN OPTIMIZE-GATHERING-FORM (CLAUSES BODY GATHERING-ENV)
   (LET*
    (ACC-INFO LEFTOVER-BODY TOP-BINDINGS FINISH-FORMS TOP-DECLS)
    (DOLIST (CLAUSE (IF (SYMBOLP CLAUSES)                    (IL:* IL:\; "A shorthand")
                        `((*ANONYMOUS-GATHERING-SITE* (,CLAUSES)))
                        CLAUSES))
        (MULTIPLE-VALUE-BIND (LET-BODY BINDING-TYPE LET-BINDINGS LOCALDECLS OTHERDECLS EXTRA-BODY)
            (EXPAND-INTO-LET (SECOND CLAUSE)
                   'GATHERING GATHERING-ENV)
          (PROG* ((ACC-VAR (FIRST CLAUSE))
                  RENAMED-VARS ACCUMULATOR REALIZER)
                 (WHEN (AND (CONSP LET-BODY)
                            (EQ (CAR LET-BODY)
                                'VALUES)
                            (CONSP (SETQ LET-BODY (CDR LET-BODY)))
                            (SETQ ACCUMULATOR (FUNCTION-LAMBDA-P (CAR LET-BODY)))
                            (CONSP (SETQ LET-BODY (CDR LET-BODY)))
                            (SETQ REALIZER (FUNCTION-LAMBDA-P (CAR LET-BODY)
                                                  0))
                            (NULL (CDR LET-BODY)))

                     (IL:* IL:|;;| "Macro returned something of the form (VALUES #'(lambda (value)")

                     (IL:* IL:|;;| 
   "..) #'(lambda () ...)), a function to accumulate values and a function to realize the result. ")

                     (WHEN BINDING-TYPE

                         (IL:* IL:|;;| "Gatherer expanded into a LET")

                         (COND
                            (OTHERDECLS (MAYBE-WARN :DEFINITION "Couldn't optimize GATHERING clause ~S because its expansion carries declarations about more than the bound variables: ~S"
                                               (SECOND CLAUSE)
                                               `(DECLARE ,@OTHERDECLS))
                                   (GO PUNT)))
                         (WHEN LET-BINDINGS

                             (IL:* IL:|;;| "The first transformation we want to perform is a variant of \"LET-eversion\": turn (mv-bind (acc real) (let (..bindings..) (values #'(lambda ...) #'(lambda ")

                             (IL:* IL:|;;| "..))) ..body..) into (let* (..bindings.. (acc #'(lambda ...)) (real #'(lambda ...))) ..body..).  This transformation is valid if nothing in body refers to any of the bindings, something we can assure by alpha-converting the inner let (substituting new names for each var).  Of course, none of those vars can be special, but we already checked for that above. ")

                             (MULTIPLE-VALUE-SETQ (LET-BINDINGS RENAMED-VARS)
                                    (RENAME-LET-BINDINGS LET-BINDINGS BINDING-TYPE GATHERING-ENV
                                           LEFTOVER-BODY))
                             (SETQ TOP-BINDINGS (NCONC TOP-BINDINGS LET-BINDINGS))
                             (SETQ LEFTOVER-BODY NIL)        (IL:* IL:\; 
                                     "If there was any leftover from previous, it is now consumed ")
                             ))
                     (SETQ LEFTOVER-BODY (NCONC LEFTOVER-BODY EXTRA-BODY))
                                                             (IL:* IL:\; 
                                                          "Computation to do after these bindings ")
                     (PUSH (CONS ACC-VAR (RENAME-AND-CAPTURE-VARIABLES ACCUMULATOR RENAMED-VARS 
                                                GATHERING-ENV))
                           ACC-INFO)
                     (SETQ REALIZER (RENAME-VARIABLES REALIZER RENAMED-VARS GATHERING-ENV))
                     (PUSH (COND
                              ((NULL (CDDDR REALIZER))       (IL:* IL:\; 
                                                           "Simple (LAMBDA () expr) => expr ")
                               (THIRD REALIZER))
                              (T                             (IL:* IL:\; 
                                     "There could be declarations or something, so leave as a LET ")
                                 (CONS 'LET (CDR REALIZER))))
                           FINISH-FORMS)
                     (UNLESS (NULL LOCALDECLS)               (IL:* IL:\; 
                                   "Declarations about the LET variables also has to percolate up ")
                         (SETQ TOP-DECLS (NCONC TOP-DECLS (SUBLIS RENAMED-VARS LOCALDECLS))))
                     (RETURN))
                 (MAYBE-WARN :DEFINITION "Couldn't optimize GATHERING clause ~S because its expansion is not of the form (VALUES #'(LAMBDA ...) #'(LAMBDA () ...))"
                        (SECOND CLAUSE))
             PUNT
                 (LET ((GS (GENSYM))
                       (EXPANSION `(MULTIPLE-VALUE-LIST ,(SECOND CLAUSE))))
                                                             (IL:* IL:\; 
                "Slow way--bind gensym to the macro expansion, and we will funcall it in the body ")
                      (PUSH (LIST ACC-VAR GS)
                            ACC-INFO)
                      (PUSH `(FUNCALL (CADR ,GS))
                            FINISH-FORMS)
                      (SETQ TOP-BINDINGS
                            (NCONC TOP-BINDINGS
                                   (LIST (LIST GS
                                               (COND
                                                  (LEFTOVER-BODY
                                                   `(PROGN ,@(PROG1 LEFTOVER-BODY (SETQ LEFTOVER-BODY
                                                                                        NIL))
                                                           ,EXPANSION))
                                                  (T EXPANSION))))))))))
    (SETQ BODY (WALK-GATHERING-BODY BODY GATHERING-ENV ACC-INFO))
    (COND
       ((EQ BODY :ABORT)                                     (IL:* IL:\; 
                                                           "Couldn't finish expansion")
        NIL)
       (T `(LET* ,TOP-BINDINGS ,@(AND TOP-DECLS `((DECLARE ,@TOP-DECLS)))
                 ,BODY
                 ,(COND
                     ((NULL (CDR FINISH-FORMS))              (IL:* IL:\; "just a single value")
                      (CAR FINISH-FORMS))
                     (T `(VALUES ,@(REVERSE FINISH-FORMS)))))))))

(DEFUN RENAME-AND-CAPTURE-VARIABLES (FORM ALIST ENV)

   (IL:* IL:|;;| "Walks FORM, renaming occurrences of the key variables in ALIST with their corresponding values, and capturing any other free variables. Returns a list of the new form and the list of other closed-over vars.  ENV is FORM's environment, so we can make sure we are talking about the same variables. ")

   (LET (CLOSED)
        (LIST (WALK-FORM FORM ENV #'(LAMBDA (FORM CONTEXT SUBENV)
                                           (DECLARE (IGNORE CONTEXT))
                                           (LET (PAIR)
                                                (COND
                                                   ((OR (NOT (SYMBOLP FORM))
                                                        (NOT (VARIABLE-SAME-P FORM SUBENV ENV)))
                                                             (IL:* IL:\; 
                                                       "non-variable or one that has been rebound ")
                                                    FORM)
                                                   ((SETQ PAIR (ASSOC FORM ALIST))
                                                             (IL:* IL:\; "One to rename")
                                                    (CDR PAIR))
                                                   (T        (IL:* IL:\; "var is free")
                                                      (PUSHNEW FORM CLOSED)
                                                      FORM)))))
              CLOSED)))

(DEFUN WALK-GATHERING-BODY (BODY GATHERING-ENV ACC-INFO)

   (IL:* IL:|;;| "Walk the body of (GATHERING (...) . BODY) in environment GATHERING-ENV. ACC-INFO is a list of information about each of the gathering \"bindings\" in the form, in the form (var gatheringfn freevars env) ")

   (LET ((*ACTIVE-GATHERERS* (NCONC (MAPCAR #'CAR ACC-INFO)
                                    *ACTIVE-GATHERERS*)))

        (IL:* IL:|;;| "*ACTIVE-GATHERERS* tells us what vars are currently legal as GATHER targets.  This is so that when we encounter a GATHER not belonging to us we can know whether to warn about it. ")

        (WALK-FORM
         (CONS 'PROGN BODY)
         GATHERING-ENV
         #'(LAMBDA (FORM CONTEXT ENV)
                  (DECLARE (IGNORE CONTEXT))
                  (LET (INFO SITE)
                       (COND
                          ((CONSP FORM)
                           (COND
                              ((NOT (EQ (CAR FORM)
                                        'GATHER))            (IL:* IL:\; 
                                                           "We only care about GATHER")
                               (WHEN (AND (EQ (CAR FORM)
                                              'FUNCTION)
                                          (EQ (CADR FORM)
                                              'GATHER))      (IL:* IL:\; 
                                                         "Passed as functional--can't macroexpand ")
                                   (MAYBE-WARN :USER 
                                         "Can't optimize GATHERING because of reference to #'GATHER."
                                          )
                                   (RETURN-FROM WALK-GATHERING-BODY :ABORT))
                               FORM)
                              ((SETQ INFO (ASSOC (SETQ SITE (IF (NULL (CDDR FORM))
                                                                '*ANONYMOUS-GATHERING-SITE*
                                                                (THIRD FORM)))
                                                 ACC-INFO))  (IL:* IL:\; 
                  "One of ours--expand (GATHER value var).  INFO = (var gatheringfn freevars env) ")
                               (UNLESS (NULL (CDDDR FORM))
                                      (WARN "Extra arguments (> 2) in ~S discarded." FORM))
                               (LET ((FN (SECOND INFO)))
                                    (COND
                                       ((SYMBOLP FN)         (IL:* IL:\; "Unoptimized case--just call the gatherer.  FN is the gensym that we bound to the list of two values returned from the gatherer. ")
                                        `(FUNCALL (CAR ,FN)
                                                ,(SECOND FORM)))
                                       (T                    (IL:* IL:\; 
                                                           "FN = (lambda (value) ...)")
                                          (DOLIST (S (THIRD INFO))
                                              (UNLESS (OR (VARIABLE-SAME-P S ENV GATHERING-ENV)
                                                          (AND (VARIABLE-SPECIAL-P S ENV)
                                                               (VARIABLE-SPECIAL-P S GATHERING-ENV)))

                                 (IL:* IL:|;;| "Some var used free in the LAMBDA form has been rebound between here and the parent GATHERING form, so can't substitute the lambda.  Ok if it's a special reference both here and in the LAMBDA, because then it's not closed over. ")

                                                  (MAYBE-WARN :USER "Can't optimize GATHERING because the expansion closes over the variable ~S, which is rebound around a GATHER for it."
                                                         S)
                                                  (RETURN-FROM WALK-GATHERING-BODY :ABORT)))

                                 (IL:* IL:|;;| "Return ((lambda (value) ...) actual-value).  In many cases we could simplify this further by substitution, but we'd have to be careful (for example, we would need to alpha-convert any LET we found inside).  Any decent compiler will do it for us. ")

                                          (LIST FN (SECOND FORM))))))
                              ((AND (SETQ INFO (MEMBER SITE *ACTIVE-GATHERERS*))
                                    (OR (EQ SITE '*ANONYMOUS-GATHERING-SITE*)
                                        (VARIABLE-SAME-P SITE ENV (FOURTH INFO))))
                                                             (IL:* IL:\; "Some other GATHERING will take care of this form, so pass it up for now. Environment check is to make sure nobody shadowed it between here and there ")
                               FORM)
                              (T                             (IL:* IL:\; 
                                                           "Nobody's going to handle it")
                                 (IF (EQ SITE '*ANONYMOUS-GATHERING-SITE*)
                                                             (IL:* IL:\; 
    "More likely that she forgot to mention the site than forget to write an anonymous gathering. ")
                                     (WARN "There is no gathering site specified in ~S." FORM)
                                     (WARN 
                                   "The site ~S in ~S is not defined in an enclosing GATHERING form."
                                           SITE FORM))       (IL:* IL:\; 
                           "Turn it into something else so we don't warn twice in the nested case ")
                                 `(%ORPHANED-GATHER ,@(CDR FORM)))))
                          ((AND (SYMBOLP FORM)
                                (SETQ INFO (ASSOC FORM ACC-INFO))
                                (VARIABLE-SAME-P FORM ENV GATHERING-ENV))
                                                             (IL:* IL:\; 
                                   "A variable reference to a gather binding from environment TEM ")
                           (MAYBE-WARN :USER 
                "Can't optimize GATHERING because site variable ~S is used outside of a GATHER form."
                                  FORM)
                           (RETURN-FROM WALK-GATHERING-BODY :ABORT))
                          (T FORM)))))))



(IL:* IL:|;;| "Sample gatherers")


(DEFMACRO COLLECTING (&KEY INITIAL-VALUE)
   `(LET* ((HEAD ,INITIAL-VALUE)
           (TAIL ,(AND INITIAL-VALUE `(LAST HEAD))))
          (VALUES #'(LAMBDA (VALUE)
                           (IF (NULL HEAD)
                               (SETQ HEAD (SETQ TAIL (LIST VALUE)))
                               (SETQ TAIL (CDR (RPLACD TAIL (LIST VALUE))))))
                 #'(LAMBDA NIL HEAD))))

(DEFMACRO JOINING (&KEY INITIAL-VALUE)
   `(LET ((RESULT ,INITIAL-VALUE))
         (VALUES #'(LAMBDA (VALUE)
                          (SETQ RESULT (NCONC RESULT VALUE)))
                #'(LAMBDA NIL RESULT))))

(DEFMACRO MAXIMIZING (&KEY INITIAL-VALUE)
   `(LET ((RESULT ,INITIAL-VALUE))
         (VALUES #'(LAMBDA (VALUE)
                          (WHEN ,(COND
                                    ((AND (CONSTANTP INITIAL-VALUE)
                                          (NOT (NULL (EVAL INITIAL-VALUE))))
                                                             (IL:* IL:\; 
                    "Initial value is given and we know it's not NIL, so leave out the null check ")
                                     '(> VALUE RESULT))
                                    (T '(OR (NULL RESULT)
                                            (> VALUE RESULT))))
                                (SETQ RESULT VALUE)))
                #'(LAMBDA NIL RESULT))))

(DEFMACRO MINIMIZING (&KEY INITIAL-VALUE)
   `(LET ((RESULT ,INITIAL-VALUE))
         (VALUES #'(LAMBDA (VALUE)
                          (WHEN ,(COND
                                    ((AND (CONSTANTP INITIAL-VALUE)
                                          (NOT (NULL (EVAL INITIAL-VALUE))))
                                                             (IL:* IL:\; 
                    "Initial value is given and we know it's not NIL, so leave out the null check ")
                                     '(< VALUE RESULT))
                                    (T '(OR (NULL RESULT)
                                            (< VALUE RESULT))))
                                (SETQ RESULT VALUE)))
                #'(LAMBDA NIL RESULT))))

(DEFMACRO SUMMING (&KEY (INITIAL-VALUE 0))
   `(LET ((SUM ,INITIAL-VALUE))
         (VALUES #'(LAMBDA (VALUE)
                          (SETQ SUM (+ SUM VALUE)))
                #'(LAMBDA NIL SUM))))



(IL:* IL:\; "Easier to read expanded code if PROG1 gets left alone ")


(XCL:DEFINE-FILE-ENVIRONMENT "ITERATE" :PACKAGE (IN-PACKAGE :ITERATE :USE '(:LISP :WALKER))
   :READTABLE "XCL"
   :BASE 10
   :COMPILER :COMPILE-FILE)
(IL:PUTPROPS IL:ITERATE IL:COPYRIGHT ("Venue" 1991))
(IL:DECLARE\: IL:DONTCOPY
  (IL:FILEMAP (NIL)))
IL:STOP
