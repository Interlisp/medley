;; Function To Be Tested: DELETE-FILE
;;
;; Source:        Steele's book    
;;                Section 23.3		        
;;                Page: 424
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 13,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-3-DELETE-FILE.TEST
;;
;;
;; Syntax:        (DELETE-FILE pathname)
;;
;;
;;
;; Function Description:
;;     deletes the file
;; 
;; 
;; 
;; Argument(s):   pathname - pointing to a file 
;;
;; Returns:       T if succeeds
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
  (let* ((temp-name (string (gensym)))
	    (temp-pathname (car (23BUILD-LIST-OF-FILENAME-PATHNAMES 
		  "dsk" 1 nil "lispfiles>temp" temp-name))))
  (and
	(Delete-file temp-pathname) 
	(not (probe-file temp-pathname))
  )))


(do-test-group "test do same type of test on several different HOSTS"
	:before (PROGN

(test-defun 23TEST-DELETE-FILE (temp-pathname)
	"check return T and file really gone"
  (and
	(eq T (Delete-file temp-pathname))
	(not (probe-file temp-pathname))
  ))

(test-defun 23TEST-DELETE-FILE-LIST (delete-list)
	"check that each item in the list exists, and give the right pathname"
  (cl:every #'(lambda (item) (23TEST-DELETE-FILE item)) delete-list))

(defun 23DRIVE-DELETE-FILE-LIST (host device directory name)
	"build the list and check able to delete the files"
  (let* ((delete-list (append 
		(23BUILD-LIST-OF-FILENAME-PATHNAMES 
			host 1 device directory name "typea")
		(23BUILD-LIST-OF-STREAM host 1 device directory name "typeB")
;		(23BUILD-LIST-OF-FILENAME-STRING 
;			host 1 device directory name "typeC")
		(23BUILD-LIST-OF-FILENAME-SYMBOL 
			host 1 device directory name "typeD"))))
	(23TEST-DELETE-FILE-LIST delete-list)
  ))

)	; End of defining functions for this test group.


(do-test "test lots of variations in {CORE}"
  (and
	(23DRIVE-DELETE-FILE-LIST "CORE" NIL NIL NIL)
	(23DRIVE-DELETE-FILE-LIST "CORE" "tempdevice-12" NIL NIL)
	(23DRIVE-DELETE-FILE-LIST "CORE" NIL "cmltest>sub12" NIL)
	(23DRIVE-DELETE-FILE-LIST "CORE" "tempdevice-12" "cmltest>sub12" "hi-23")
  ))

(do-test "test lots of variations in {DSK}"
  (23DRIVE-DELETE-FILE-LIST "DSK" NIL "lispfiles>cmltest>sub12" NIL))

(do-test "test lots of variations in {ERINYES}"
  (23DRIVE-DELETE-FILE-LIST "ERINYES" NIL "cmltest" NIL))

)	; end of do-test-group
	

(do-test "test error conditions"
   (flet ((handle-expect-errors (value) 
		  (xcl-test:expect-errors (cl:error) 
			(cl:DELETE-FILE value))
		))
   (and
	(handle-expect-errors #\h)
	(handle-expect-errors (list 'hi 'bye))
	(handle-expect-errors (make-array '(2 3 4)))
	(handle-expect-errors (make-hash-table))
	(handle-expect-errors (copy-readtable))
	(handle-expect-errors (find-package 'Lisp))
;	(handle-expect-errors (make-random-state))
	(handle-expect-errors "DF")
	(handle-expect-errors "OCT-6-65")
	(handle-expect-errors 'hello)
	(handle-expect-errors 'bye)
	(handle-expect-errors (make-broadcast-stream *terminal-io*))
 	T
   )))



STOP
