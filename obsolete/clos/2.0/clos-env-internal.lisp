(DEFINE-FILE-INFO PACKAGE "XCL" READTABLE "XCL")
(il:filecreated "28-Aug-87 18:42:36" il:{phylum}<clos>clos-env-internal.\;1 8356   

      il:|changes| il:|to:|  (il:vars il:clos-env-internalcoms)
                             (il:props (il:clos-env-internal il:makefile-environment))
                             (il:functions stack-eql stack-pointer-frame stack-frame-valid-p 
                                    stack-frame-fn-header stack-frame-pc fnheader-debugging-info 
                                    stack-frame-name compiled-closure-fnheader compiled-closure-env)
)


; Copyright (c) 1987 by Xerox Corporation.  All rights reserved.

(il:prettycomprint il:clos-env-internalcoms)

(il:rpaqq il:clos-env-internalcoms (

(il:* il:|;;;| "***************************************")

                                   

(il:* il:|;;;| " Copyright (c) 1987 Xerox Corporation.  All rights reserved.")

                                   

(il:* il:|;;;| "")

                                   

(il:* il:|;;;| "Use and copying of this software and preparation of derivative works based upon this software are permitted.  Any distribution of this software or derivative works must comply with all applicable United States export control laws.")

                                   

(il:* il:|;;;| " ")

                                   

(il:* il:|;;;| "This software is made available AS IS, and Xerox Corporation makes no  warranty about the software, its performance or its conformity to any  specification.")

                                   

(il:* il:|;;;| " ")

                                   

(il:* il:|;;;| "Any person obtaining a copy of this software is requested to send their name and post office or electronic mail address to:")

                                   

(il:* il:|;;;| "   CommonLoops Coordinator")

                                   

(il:* il:|;;;| "   Xerox Artifical Intelligence Systems")

                                   

(il:* il:|;;;| "   2400 Hanover St.")

                                   

(il:* il:|;;;| "   Palo Alto, CA 94303")

                                   

(il:* il:|;;;| "(or send Arpanet mail to CommonLoops-Coordinator.pa@Xerox.arpa)")

                                   

(il:* il:|;;;| "")

                                   

(il:* il:|;;;| " Suggestions, comments and requests for improvements are also welcome.")

                                   

(il:* il:|;;;| " *************************************************************************")

                                   

(il:* il:|;;;| "")

                                   (il:declare\: il:dontcopy (il:prop il:makefile-environment 
                                                                    il:clos-env-internal))
                                                             (il:* il:\; 
                                                             "We're off to hack the system...")

                                   (il:declare\: il:eval@compile il:dontcopy (il:files clos::abc)
                                          
          
          (il:* il:|;;| "The Deltas and The East and The Freeze")
)
                                   (il:functions stack-eql stack-pointer-frame stack-frame-valid-p 
                                          stack-frame-fn-header stack-frame-pc 
                                          fnheader-debugging-info stack-frame-name 
                                          compiled-closure-fnheader compiled-closure-env)))



(il:* il:|;;;| "***************************************")




(il:* il:|;;;| " Copyright (c) 1987 Xerox Corporation.  All rights reserved.")




(il:* il:|;;;| "")




(il:* il:|;;;| 
"Use and copying of this software and preparation of derivative works based upon this software are permitted.  Any distribution of this software or derivative works must comply with all applicable United States export control laws."
)




(il:* il:|;;;| " ")




(il:* il:|;;;| 
"This software is made available AS IS, and Xerox Corporation makes no  warranty about the software, its performance or its conformity to any  specification."
)




(il:* il:|;;;| " ")




(il:* il:|;;;| 
"Any person obtaining a copy of this software is requested to send their name and post office or electronic mail address to:"
)




(il:* il:|;;;| "   CommonLoops Coordinator")




(il:* il:|;;;| "   Xerox Artifical Intelligence Systems")




(il:* il:|;;;| "   2400 Hanover St.")




(il:* il:|;;;| "   Palo Alto, CA 94303")




(il:* il:|;;;| "(or send Arpanet mail to CommonLoops-Coordinator.pa@Xerox.arpa)")




(il:* il:|;;;| "")




(il:* il:|;;;| " Suggestions, comments and requests for improvements are also welcome.")




(il:* il:|;;;| " *************************************************************************")




(il:* il:|;;;| "")

(il:declare\: il:dontcopy 

(il:putprops il:clos-env-internal il:makefile-environment (:package "XCL" :readtable "XCL"))
)



(il:* il:\; "We're off to hack the system...")

(il:declare\: il:eval@compile il:dontcopy 
(il:filesload clos::abc)
)

(defun stack-eql (x y) "Test two stack pointers for equality" (and (il:stackp x)
                                                                   (il:stackp y)
                                                                   (eql (il:fetch (il:stackp il:edfxp
                                                                                         )
                                                                           il:of x)
                                                                        (il:fetch (il:stackp il:edfxp
                                                                                         )
                                                                           il:of y))))


(defun stack-pointer-frame (stack-pointer) (il:|fetch| (il:stackp il:edfxp) il:|of| stack-pointer))


(defun stack-frame-valid-p (frame) (not (il:|fetch| (il:fx il:invalidp) il:|of| frame)))


(defun stack-frame-fn-header (frame) (il:|fetch| (il:fx il:fnheader) il:|of| frame))


(defun stack-frame-pc (frame) (il:|fetch| (il:fx il:pc) il:|of| frame))


(defun fnheader-debugging-info (fnheader) (let* ((start-pc (il:fetch (il:fnheader il:startpc)
                                                              il:of fnheader))
                                                 (name-table-words
                                                  (let ((size (il:fetch (il:fnheader il:ntsize)
                                                                 il:of fnheader)))
                                                       (if (zerop size)
                                                           il:wordsperquad
                                                           (* size 2))))
                                                 (past-name-table-in-words (+ (il:fetch (il:fnheader
                                                                                         
                                                                                     il:overheadwords
                                                                                         )
                                                                                 il:of fnheader)
                                                                              name-table-words)))
                                                (and (= (- start-pc (* il:bytesperword 
                                                                       past-name-table-in-words))
                                                        il:bytespercell)
          
          (il:* il:|;;| "It's got a debugging-info list.")

                                                     (il:\\getbaseptr fnheader 
                                                            past-name-table-in-words))))


(defun stack-frame-name (frame) (il:|fetch| (il:fx il:framename) il:|of| frame))


(defun compiled-closure-fnheader (closure) (il:|fetch| (il:compiled-closure il:fnheader) il:|of|
                                                                                         closure))


(defun compiled-closure-env (closure) (il:fetch (il:compiled-closure il:environment) il:of closure))

(il:putprops il:clos-env-internal il:copyright ("Xerox Corporation" 1987))
(il:declare\: il:dontcopy
  (il:filemap (nil)))
il:stop
