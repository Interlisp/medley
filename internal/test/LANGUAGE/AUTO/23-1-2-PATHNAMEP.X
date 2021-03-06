;; Function To Be Tested: PATHNAMEP
;;
;; Source:        Steele's book    
;;                Section 23.1.2	PATHNAME Functions        
;;                Page: 416
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: October 31,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-1-2-PATHNAMEP.TEST
;;
;;
;; Syntax:        (PATHNAMEP object)
;;
;;      (PATHNAMEP object) is exactly equal to:
;;                (typep object 'pathname)
;;
;;
;; Function Description:
;;     This predicate is true if object is a pathname, nil otherwise
;; 
;; 
;; 
;; Argument(s):   object - can be anything 
;;
;; Returns:       T if the object is a pathname, nil otherwise
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "try a simple test"
	:before (progn (setq simple-list 
		  (23BUILD-LIST-OF-FILENAME-PATHNAMES 
			"dsk" 1 nil "lispfiles>tempdir")))
	:after (progn (23Delete-file-list simple-list))
  (eq T (PATHNAMEP (car simple-list))))



(do-test-group "test same type on different hosts"
	:before (progn

; this function is just for this test case.
(test-defun 23BUILD-PathNameP-Host-List (host usedevice InOneDir)
	"build the master list to drive past the checker"
  (append 
	; if don't need to stay in one directory, wander, not use directory
	(if (null InOneDir) (append 
	  (23BUILD-LIST-OF-FILENAME-PATHNAMES host 1)
	  (23BUILD-LIST-OF-FILENAME-PATHNAMES host 2 nil "aisbu.modem12")
	  (23BUILD-LIST-OF-FILENAME-PATHNAMES host 3 nil nil nil "temptype")
	  (23BUILD-LIST-OF-FILENAME-PATHNAMES host 
		2 nil "aisbu.modem" nil "temptype")
	  ))
	; if able to support devices on this host, test
	(if usedevice (append 
	  (23BUILD-LIST-OF-FILENAME-PATHNAMES host 3 "tempdevice")
	  (23BUILD-LIST-OF-FILENAME-PATHNAMES host 
		2 "tempdevice" "cmltest")
	  (23BUILD-LIST-OF-FILENAME-PATHNAMES host 
		2 "tempdevice" "cmltest" nil "temptype")
	  ))
	; general cases, for many file serves
	(23BUILD-LIST-OF-FILENAME-PATHNAMES host 2 nil "cmltest")
	(23BUILD-LIST-OF-FILENAME-PATHNAMES host 3 nil "cmltest>sub")
	(23BUILD-LIST-OF-FILENAME-PATHNAMES host 
		2 nil "cmltest>sub" nil "temptype")
  ))

(test-defun 23DRIVE-PATHNAMEP-HOST-LIST (host usedevice InOneDir)
	"push the same test across many hosts"
  (let* ((big-list (23BUILD-PathNameP-Host-List host usedevice InOneDir))
	   (result (cl:every #'(lambda (item) (eq T (pathnamep item))) big-list)))
	(23Delete-file-list big-list)
	result))

)	; end of local functions

(do-test "test lots of variations in {core}"
	(23DRIVE-PATHNAMEP-HOST-LIST "core" T nil))

(do-test "test lots of variations in {core}"
  (let* ((big-list (23BUILD-LIST-OF-FILENAME-PATHNAMES 
			"dsk" 2 nil "lispfiles>sub"))
	    (result (cl:every #'(lambda (item) (eq T (pathnamep item))) big-list)))
	(23Delete-file-list big-list)
	result))

(do-test "test lots of variations in {erinyes}"
	(23DRIVE-PATHNAMEP-HOST-LIST "erinyes" nil T))

)	; end of do-test-group
	

(do-test "test other types return nil"
   (and
	(NOT (PATHNAMEP T))
	(NOT (PATHNAMEP 54))
	(NOT (PATHNAMEP #\h))
	(NOT (PATHNAMEP "A string"))
	(NOT (PATHNAMEP 'symbol))
	(NOT (PATHNAMEP (list 'hi 'bye)))
	(NOT (PATHNAMEP (make-array '(2 3 4))))
	(NOT (PATHNAMEP (make-hash-table)))
	(NOT (PATHNAMEP (copy-readtable)))
	(NOT (PATHNAMEP (find-package 'Lisp)))
	(NOT (PATHNAMEP (make-broadcast-stream *terminal-io*)))
;	(NOT (PATHNAMEP (make-random-state)))
	))



STOP
