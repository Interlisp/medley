(DEFINE-FILE-INFO READTABLE "XCL" PACKAGE (CLIN-PACKAGE "XCL-USER") BASE 10)
(IL:FILECREATED "19-Feb-91 14:09:19" 
IL:|{DSK}<usr>local>users>welch>lisp>clos>rev4>il-format>XEROX-PATCHES.;2| 9876   

      IL:|changes| IL:|to:|  (IL:VARS IL:XEROX-PATCHESCOMS)

      IL:|previous| IL:|date:| " 6-Feb-91 10:55:16" 
IL:|{DSK}<usr>local>users>welch>lisp>clos>rev4>il-format>XEROX-PATCHES.;1|)


; Copyright (c) 1991 by Venue.  All rights reserved.

(IL:PRETTYCOMPRINT IL:XEROX-PATCHESCOMS)

(IL:RPAQQ IL:XEROX-PATCHESCOMS (


                                    (IL:FUNCTIONS OPTIMIZE-LOGICAL-OP-1-ARG)
                                    (OPTIMIZERS (LOGIOR :OPTIMIZED-BY OPTIMIZE-LOGICAL-OP-1-ARG)
                                           (LOGXOR :OPTIMIZED-BY OPTIMIZE-LOGICAL-OP-1-ARG)
                                           (LOGAND :OPTIMIZED-BY OPTIMIZE-LOGICAL-OP-1-ARG)
                                           (LOGEQV :OPTIMIZED-BY OPTIMIZE-LOGICAL-OP-1-ARG))
                                    
                                    (IL:* IL:|;;| "A bug compiling LABELS")

                                    (IL:FUNCTIONS COMPILER::META-CALL-LABELS)
                                    (FILE-ENVIRONMENTS "XEROX-PATCHES")))






(IL:* IL:|;;;| 
"Declare side-effects (actually, lack of side-effects) info for some internal arithmetic functions.  These are needed because the compiler runs the optimizers before checking the side-effects, so side-effect declarations on the \"real\" functions are oft times ignored. Fix a nit in the compiler While no person would generate code like (logor x), macro can (and do). "
)


(DEFUN OPTIMIZE-LOGICAL-OP-1-ARG (FORM ENV CTXT)
   (DECLARE (IGNORE ENV CTXT))
   (IF (= 2 (LENGTH FORM))
       (SECOND FORM)
       'COMPILER:PASS))

(DEFOPTIMIZER LOGIOR OPTIMIZE-LOGICAL-OP-1-ARG)

(DEFOPTIMIZER LOGXOR OPTIMIZE-LOGICAL-OP-1-ARG)

(DEFOPTIMIZER LOGAND OPTIMIZE-LOGICAL-OP-1-ARG)

(DEFOPTIMIZER LOGEQV OPTIMIZE-LOGICAL-OP-1-ARG)



(IL:* IL:|;;| "A bug compiling LABELS")


(DEFUN COMPILER::META-CALL-LABELS (COMPILER::NODE COMPILER:CONTEXT)

   (IL:* IL:|;;| "This is similar to META-CALL-LAMBDA, but we have some extra information. There are only required arguments, and we have the correct number of them. ")

   (LET ((COMPILER::*MADE-CHANGES* NIL))

        (IL:* IL:|;;| "First, substitute the functions wherever possible.")

        (DOLIST (COMPILER::FN-PAIR (COMPILER::LABELS-FUNS COMPILER::NODE)
                       (WHEN (NULL (COMPILER::NODE-META-P (COMPILER::LABELS-BODY COMPILER::NODE)))
                           (SETF (COMPILER::NODE-META-P COMPILER::NODE)
                                 NIL)
                           (SETQ COMPILER::*MADE-CHANGES* T)))
            (WHEN (COMPILER::SUBSTITUTABLE-P (CDR COMPILER::FN-PAIR)
                         (CAR COMPILER::FN-PAIR))
                (LET ((COMPILER::*SUBST-OCCURRED* NIL))

                     (IL:* IL:|;;| "First try substituting into the body.")

                     (SETF (COMPILER::LABELS-BODY COMPILER::NODE)
                           (COMPILER::META-SUBSTITUTE (CDR COMPILER::FN-PAIR)
                                  (CAR COMPILER::FN-PAIR)
                                  (COMPILER::LABELS-BODY COMPILER::NODE)))
                     (WHEN (NOT COMPILER::*SUBST-OCCURRED*)

                         (IL:* IL:|;;| "Wasn't in the body - try the other functions.")

                         (DOLIST (COMPILER::TARGET-PAIR (COMPILER::LABELS-FUNS COMPILER::NODE))
                             (UNLESS (EQ COMPILER::TARGET-PAIR COMPILER::FN-PAIR)
                                 (SETF (CDR COMPILER::TARGET-PAIR)
                                       (COMPILER::META-SUBSTITUTE (CDR COMPILER::FN-PAIR)
                                              (CAR COMPILER::FN-PAIR)
                                              (CDR COMPILER::TARGET-PAIR)))
                                 (WHEN COMPILER::*SUBST-OCCURRED*
                                                             (IL:* IL:\; 
                                                           "Found it, we can stop now.")
                                     (SETF (COMPILER::NODE-META-P COMPILER::NODE)
                                           NIL)
                                     (SETQ COMPILER::*MADE-CHANGES* T)
                                     (RETURN)))))

                     (IL:* IL:|;;| "May need to reanalyze the node, since things might have changed. Note that reanalyzing the parts of the node this way means the the state in the enclosing loop is not lost. ")

                     (DOLIST (COMPILER::FNS (COMPILER::LABELS-FUNS COMPILER::NODE))
                         (COMPILER::MEVAL (CDR COMPILER::FNS)
                                :ARGUMENT))
                     (COMPILER::MEVAL (COMPILER::LABELS-BODY COMPILER::NODE)
                            :RETURN))))

        (IL:* IL:|;;| "Now remove any functions that aren't referenced.")

        (DOLIST (COMPILER::FN-PAIR (PROG1 (COMPILER::LABELS-FUNS COMPILER::NODE)
                                       (SETF (COMPILER::LABELS-FUNS COMPILER::NODE)
                                             NIL)))
            (COND
               ((NULL (COMPILER::VARIABLE-READ-REFS (CAR COMPILER::FN-PAIR)))
                (COMPILER::RELEASE-TREE (CDR COMPILER::FN-PAIR))
                (SETQ COMPILER::*MADE-CHANGES* T))
               (T (PUSH COMPILER::FN-PAIR (COMPILER::LABELS-FUNS COMPILER::NODE)))))

        (IL:* IL:|;;| "If there aren't any functions left, replace the node with its body.")

        (WHEN (NULL (COMPILER::LABELS-FUNS COMPILER::NODE))
            (LET ((COMPILER::BODY (COMPILER::LABELS-BODY COMPILER::NODE)))
                 (SETF (COMPILER::LABELS-BODY COMPILER::NODE)
                       NIL)
                 (COMPILER::RELEASE-TREE COMPILER::NODE)
                 (SETQ COMPILER::NODE COMPILER::BODY COMPILER::*MADE-CHANGES* T)))

        (IL:* IL:|;;| "Finally, set the meta-p flag if everythings OK.")

        (IF (NULL COMPILER::*MADE-CHANGES*)
            (SETF (COMPILER::NODE-META-P COMPILER::NODE)
                  COMPILER:CONTEXT)
            (SETF (COMPILER::NODE-META-P COMPILER::NODE)
                  NIL)))
   COMPILER::NODE)

(DEFINE-FILE-ENVIRONMENT "XEROX-PATCHES" :PACKAGE (IN-PACKAGE "XCL-USER")
   :READTABLE "XCL"
   :BASE 10
   :COMPILER :COMPILE-FILE)
(IL:PUTPROPS IL:XEROX-PATCHES IL:COPYRIGHT ("Venue" 1991))
(IL:DECLARE\: IL:DONTCOPY
  (IL:FILEMAP (NIL)))
IL:STOP
