;; Function To Be Tested: PATHNAME-VERSION
;;
;; Source:        Steele's book    
;;                Section 23.1.2	PATHNAME Functions        
;;                Page: 417
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 18,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-1-2-PATHNAME-VERSION.TEST
;;
;;
;; Syntax:        (PATHNAME-VERSION pathname)
;;
;;
;;
;; Function Description:
;;     returns the type of the fil as a string or symbol
;; 
;; 
;; 
;; Argument(s):   pathname - pointing to a file 
;;
;; Returns:       the version of the file 
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
	:before (progn (setq simple-list (23BUILD-LIST-OF-STREAM 
			"dsk" 3 nil "lispfiles>tempdir" nil "hello")))
	:after (progn (23Delete-file-list simple-list))
	(23TEST-PATHNAME-VALUE-list simple-list 'version 1))

(do-test-group "test do same type of test on several different HOSTS"
	:before (PROGN

; this function is just for this test case.
(test-defun 23BUILD-VERSION-LIST (host result-type)
    (append 
	(23file-generator result-type host 2 nil "cmltest")
	(23file-generator result-type host 2 nil "cmltest>sub")
    ))

;Do each type
(test-defun 23BUILD-VERSION-LIST-ALL (host)
  (append
	(23BUILD-VERSION-LIST host 'STREAM)
;	(23BUILD-VERSION-LIST host 'STRING)
;	(23BUILD-VERSION-LIST host 'SYMBOL)
  ))

(test-defun 23DRIVE-VERSION-LIST (host)
  (let* ((big-list (23BUILD-VERSION-LIST-ALL host))
	    (result (23TEST-PATHNAME-VALUE-list big-list 'version 1)))
	(23Delete-file-list big-list)
	result))

)	; End of defining functions for this test group.


(do-test "test lots of variations in {CORE}"
  (23DRIVE-VERSION-LIST "core"))

(do-test "test lots of variations in {dsk}"
  (let* ((big-list (23file-generator 
			'STREAM "dsk" 2 nil "lispfiles>sub" nil nil))
	    (result (23TEST-PATHNAME-VALUE-list 
			big-list 'version 1)))
	(23Delete-file-list big-list)
	result))

(do-test "test lots of variations in {erinyes}"
  (23DRIVE-VERSION-LIST "erinyes"))

)	; end of do-test-group
	

(do-test "test error conditions"
   (flet ((handle-expect-errors (value) 
		  (xcl-test:expect-errors (cl:error) 
			(PATHNAME-VERSION value))
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
	T
   )))



STOP
