;; Function To Be Tested: PATHNAME-HOST & HOST-NAMESTRING
;;
;; Source:        Steele's book    
;;                Section 23.1.2	PATHNAME Functions        
;;                Page: 417
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 4,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-1-2-PATHNAME-HOST.TEST
;;
;;
;; Syntax:        (PATHNAME-HOST pathname)
;;                (HOST-NAMESTRING pathname)
;;
;;
;;
;; Function Description:
;;     returns the name of the host as a string or symbol
;;	  returns the name of the host as a string
;; 
;; 
;; 
;; Argument(s):   pathname - pointing to a file 
;;
;; Returns:       the host name
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test, PATHNAME-HOST, a simple case, dsk"
	:before (progn (setq simple-list 
		  (23BUILD-LIST-OF-FILENAME-PATHNAMES "dsk" 3 nil "lispfiles")))
	:after (progn (23Delete-file-list simple-list))
  (23TEST-PATHNAME-VALUE-list simple-list 'HOST "DSK"))


(do-test "test, HOST-NAMESTRING, a simple case, dsk"
	:before (progn (setq simple-list 
		  (23BUILD-LIST-OF-FILENAME-PATHNAMES "dsk" 3 nil "lispfiles")))
	:after (progn (23Delete-file-list simple-list))
  (23TEST-NAMESTRING-VALUE-LIST simple-list 'HOST "DSK"))



(do-test "test, PATHNAME-HOST, a simple case, pollux"
	:before (progn (setq simple-list 
		  (23BUILD-LIST-OF-FILENAME-PATHNAMES 
		"pollux:aisnorth:xerox" 3 nil "cmltest")))
	:after (progn (23Delete-file-list simple-list))
  (23TEST-PATHNAME-VALUE-list simple-list 'HOST "POLLUX:AISNORTH:XEROX"))


(do-test "test, HOST-NAMESTRING, a simple case, pollux"
	:before (progn (setq simple-list 
		  (23BUILD-LIST-OF-FILENAME-PATHNAMES 
		"pollux:aisnorth:xerox" 3 nil "cmltest")))
	:after (progn (23Delete-file-list simple-list))
  (23TEST-NAMESTRING-VALUE-LIST simple-list 'HOST "POLLUX:AISNORTH:XEROX"))




(do-test-group "test do same type of test on several hosts"
	:before (PROGN

; this function is just for this test case.
(test-defun 23BUILD-HOST-LIST (host usedevice InOneDir result-type)
	"build a list with which to test pathname-host"
    (append 
	; if don't need to stay in one directory, wander
	(if (not InOneDir) (append 
	  (23file-generator result-type host 2)
	  (23file-generator result-type host 2 nil "aisbu.modem12")
	  (23file-generator result-type host 2 
		nil "aisbu.modem32" nil "temptype")  
	  ))
	; if able to support devices on this host, test
	(if usedevice (append 
	  (23file-generator result-type host 2 "tempdevice")
	  (23file-generator result-type host 2 "tempdevice" "cmltest")
	  (23file-generator result-type host 2 
		"tempdevice" "cmlfiletest" nil "temptype")  
	  ))
	; general cases, for many file serves
	(23file-generator result-type host 2 nil "cmltest")
	(23file-generator result-type host 2 nil "cmltest>sub")
	(23file-generator result-type host 2 nil 
		"cmltest>sub" nil "temptype")
    ))

;Do each type
(test-defun 23BUILD-HOST-LIST-ALL (host usedevice InOneDir)
	"build the big master list"
  (append
	(23BUILD-HOST-LIST host usedevice InOneDir 'PATHNAME)
	(23BUILD-HOST-LIST host usedevice InOneDir 'STREAM)
	(23BUILD-HOST-LIST host usedevice InOneDir 'STRING)
	(23BUILD-HOST-LIST host usedevice InOneDir 'SYMBOL)
  ))

(test-defun 23DRIVE-HOST-LIST-PATHNAME 
	(host-create host-match usedevice InOneDir)
	"push the same test across many hosts"
  (let* ((big-list (23BUILD-HOST-LIST-ALL host-create usedevice InOneDir))
	    (result (23TEST-PATHNAME-VALUE-list big-list 'HOST host-match)))
	(23Delete-file-list big-list)
	result))

(test-defun 23DRIVE-HOST-LIST-NAMESTRING 
	(host-create host-match usedevice InOneDir)
	"push the same test across many hosts"
  (let* ((big-list (23BUILD-HOST-LIST-ALL host-create usedevice InOneDir))
	   (result (23TEST-NAMESTRING-VALUE-list big-list 'HOST host-match)))
	(23Delete-file-list big-list)
	result))


)	; End of defining functions for this test group.


(do-test "test (PATHNAME-HOST) lots of variations in {CORE}"
	(23DRIVE-HOST-LIST-PATHNAME "core" "CORE" T nil))	

;Ought to test around the problem with psuedo-dsk
;(do-test "test (PATHNAME-HOST) lots of variations in {DSK}"
;	(23DRIVE-HOST-LIST-PATHNAME "dsk" "DSK" T nil))	

(do-test "test (PATHNAME-HOST) lots of variations in {ERINYES}"
	(23DRIVE-HOST-LIST-PATHNAME "erinyes" "ERINYES" nil T))	



(do-test "test (HOST-NAMESTRING) lots of variations in {CORE}"
	(23DRIVE-HOST-LIST-NAMESTRING "core" "CORE" T nil))	

;Ought to test around the problem with psuedo-dsk
;(do-test "test (HOST-NAMESTRING) lots of variations in {DSK}"
;	(23DRIVE-HOST-LIST-NAMESTRING "dsk" "DSK" T nil))	

(do-test "test (HOST-NAMESTRING) lots of variations in {ERINYES}"
	(23DRIVE-HOST-LIST-NAMESTRING "erinyes" "ERINYES" nil T))	


   
)	; end of do-test-group
	

(do-test "test error conditions for PATHNAME-HOST"
   (flet ((handle-expect-errors (value) 
		  (xcl-test:expect-errors (cl:error) 
			(PATHNAME-HOST value))
		))
   (and
	(handle-expect-errors 54)
	(handle-expect-errors #\h)
	(handle-expect-errors (list 'hi 'bye))
	(handle-expect-errors (make-array '(2 3 4)))
	(handle-expect-errors (make-hash-table))
	(handle-expect-errors (copy-readtable))
	(handle-expect-errors (find-package 'Lisp))
;	(handle-expect-errors (make-random-state))
	(not (PATHNAME-HOST "DF"))
	(not (PATHNAME-HOST "OCT-6-65"))
	(not (PATHNAME-HOST 'hello))
	(not (PATHNAME-HOST 'bye))
	(not (PATHNAME-HOST (make-broadcast-stream *terminal-io*)))
   )))


(do-test "test error conditions for HOST-NAMESTRING"
   (flet ((handle-expect-errors (value) 
		  (xcl-test:expect-errors (cl:error) 
			(HOST-NAMESTRING value))
		))
   (and
	(handle-expect-errors 54)
	(handle-expect-errors #\h)
	(handle-expect-errors (list 'hi 'bye))
	(handle-expect-errors (make-array '(2 3 4)))
	(handle-expect-errors (make-hash-table))
	(handle-expect-errors (copy-readtable))
	(handle-expect-errors (find-package 'Lisp))
;	(handle-expect-errors (make-random-state))
	(not (HOST-NAMESTRING "DF"))
	(not (HOST-NAMESTRING "OCT-6-65"))
	(not (HOST-NAMESTRING 'hello))
	(not (HOST-NAMESTRING 'bye))
	(not (HOST-NAMESTRING (make-broadcast-stream *terminal-io*)))
   )))



STOP
