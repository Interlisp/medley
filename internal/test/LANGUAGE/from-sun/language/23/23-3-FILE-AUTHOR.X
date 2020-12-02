;; Function To Be Tested: FILE-AUTHOR
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
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-3-FILE-WRITE-DATEAUTHOR.TEST
;;
;;
;; Syntax:        (FILE-WRITE-DATEAUTHOR file)
;;
;;
;;
;; Function Description:
;;      returns the author of a file 
;; 
;; 
;; 
;; Argument(s):   file - an existing file
;;
;; Returns:       the author of a file
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
  (let* ((simple-file (car (23BUILD-LIST-OF-FILENAME-PATHNAMES "erinyes" 1)))
	    (author-create (file-author simple-file)))
	(Delete-file simple-file) 
	author-create))


(do-test-group "test do same type of test on several different HOSTS"
	:before (PROGN

(test-defun 23Test-AUTHOR (temp-pathname expectvalue)
	"check the author is who we expect"
  (string-equal expectvalue (file-author temp-pathname)))

(test-defun 23Test-AUTHOR-list (big-list expectvalue)
	"check the author is correct for  bunch of files"
  (cl:every #'(lambda (item) (23Test-AUTHOR item expectvalue))
		big-list))

(test-defun 23Build-AUTHOR (host)
  (append
	(23BUILD-LIST-OF-FILENAME-PATHNAMES host 2)
;	(23BUILD-LIST-OF-STREAM host 2)
;	(23BUILD-LIST-OF-FILENAME-STRING host 2)
	(23BUILD-LIST-OF-FILENAME-SYMBOL host 2)
  ))

(test-defun 23DRIVE-AUTHOR (host expectvalue)
	"build a set of files and check author works"
  (let* ((big-list (23BUILD-author host))
	    (result (23Test-author-list big-list expectvalue)))
	(23Delete-file-list big-list)
	result))

)	; End of defining functions for this test group.

(do-test "test the date with lots of variations in {core}"
  (23DRIVE-author "core" nil))

(do-test "test the date with lots of variations in {erinyes}"
  (let ((expectvalue (concatenate 'string (IL:username) ".pa")))
    (23DRIVE-author "erinyes" expectvalue)))



)	; end of do-test-group





STOP
