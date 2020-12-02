;; Function To Be Tested: FILE-WRITE-DATE
;;
;; Source:        Steele's book    
;;                Section 23.3	        
;;                Page: 424
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 19,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-3-FILE-WRITE-DATE.TEST
;;
;;
;; Syntax:        (FILE-WRITE-DATE file)
;;
;;
;;
;; Function Description:
;;      returns the date the file was created, or last written to
;; 
;; 
;; 
;; Argument(s):   file - an existing file
;;
;; Returns:       the time in universal time format
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
  (let* ((before-time (get-universal-time))
	    (temp-name (string (gensym)))
	    (simple-file (car 
		  (23BUILD-LIST-OF-FILENAME-PATHNAMES "DSK" 1 nil "lispfiles")))
	    (after-time (get-universal-time))
	    (time-create (file-write-date simple-file))
	    (result (<= before-time time-create after-time)))
	(Delete-file simple-file) 
	result))


(do-test-group "test do same type of test on several different HOSTS"
	:before (PROGN

(test-defun 23Test-Date (temp-pathname before-time after-time)
	"check the date of a file is nicely bound"
  (let ((time-create (cl:file-write-date temp-pathname)))
    (<= before-time time-create after-time)
  ))

(test-defun 23Test-Date-list (big-list before-time after-time)
	"check the date of a set of files are nicely bound"
  (cl:every #'(lambda (item) (23Test-Date item before-time after-time))
		big-list))

(test-defun 23Build-Date (host)
  (append
	(23BUILD-LIST-OF-FILENAME-PATHNAMES host 2)
	(23BUILD-LIST-OF-STREAM host 2)
;	(23BUILD-LIST-OF-FILENAME-STRING host 2)
	(23BUILD-LIST-OF-FILENAME-SYMBOL host 2)
  ))

(test-defun 23DRIVE-Date (host)
	"build a set of files and check date works"
  (let* ((before-time (get-universal-time))
	    (big-list (23BUILD-date host))
	    (toss-away (sleep 5))
	    (after-time (get-universal-time))
	    (result (23Test-Date-list big-list before-time after-time)))
	(23Delete-file-list big-list)
	result))

)	; End of defining functions for this test group.

(do-test "test the date with lots of variations in {core}"
  (23DRIVE-Date "core"))

;(do-test "test the date with lots of variations in {dsk}"
;  (23DRIVE-Date "dsk"))

;(do-test "test the date with lots of variations in {erinyes}"
;  (23DRIVE-Date "erinyes"))



)	; end of do-test-group


(do-test "test error conditions"
   (and
	(not (file-write-date 54))
	(not (file-write-date #\h))
	(not (file-write-date (list 'hi 'bye)))
	(not (file-write-date (make-array '(2 3 4))))
	(not (file-write-date (make-hash-table)))
	(not (file-write-date (copy-readtable)))
	(not (file-write-date (find-package 'Lisp)))
;	(not (file-write-date (make-random-state)))
	(not (file-write-date "DF"))
	(not (file-write-date "OCT-6-65"))
	(not (file-write-date 'hello))
	(not (file-write-date 'bye))
   ))



STOP
