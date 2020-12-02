;; Function To Be Tested: PARSE-NAMESTRING
;;
;; Source:        Steele's book    
;;                Section 23.1.2	PATHNAME Functions        
;;                Page: 414
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 21,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-1-2-PARSE-NAMESTRING.TEST
;;
;;
;; Syntax:        (PARSE-NAMESTRING thing &optional host defaults
;;								 &key :start :end :junk-allowed)
;;
;;
;;
;; Function Description:
;;     Turns thing into a pathname
;; 
;; 
;; 
;; Argument(s):   thing - a string, or symbol, or pathname, or stream
;;			   host - where ought to be
;;			   defaults - the default values
;;			   start - where start in the string
;;			   end - where end in the string
;;			   junk-allowed - could there be junk in the string?
;;
;; Returns:       a pathname 
;;
;; comment:		For most tests don't need to worry about host 
;;				and default for the file system doesn't need 
;;				the information.  See page 414.


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
  (let* ((temp-name "{core}<cmltest>any-name.type")
	    (temp-pathname (parse-namestring temp-name)))
  (and
	(pathnamep temp-pathname)
	(string-equal temp-name (namestring temp-pathname))
  )))


(do-test-group "test do same type of test on several different HOSTS"
	:before (PROGN

(test-defun 23Parse-Basic (host)
  (let* ((temp-name (concatenate 'string "{" host "}<cmltest>any-name.type"))
	    (temp-pathname (parse-namestring temp-name)))
  (and
	(pathnamep temp-pathname)
	(string-equal temp-name (namestring temp-pathname))
  )))

(test-defun 23Parse-Variable-Type (host)
  (let* ((temp-pathname (23BUILD-PATHNAME host))
	    (temp-stream (open temp-pathname :direction :io))
	    (toss-away (close temp-stream))
	    (expect (namestring temp-stream))
	    (temp-list (23Multiply-stream (list temp-stream)))
	    (result (23check-parse-list expect temp-list)))
	(delete-file temp-stream)
	result))

(test-defun 23Parse-Junk (host)
  (let* ((temp-name (concatenate 'string " uh {" host "}<cmltest>any-name.type"))
	    (temp-pathname (parse-namestring temp-name :junk-allowed T)))
  (and
	(pathnamep temp-pathname)
	(string-equal temp-name (namestring temp-pathname))
  )))

(test-defun 23Parse-Start (host)
  (let* ((temp-name (concatenate 'string " uh {" host "}<cmltest>any-name.type"))
	    (temp-pathname (parse-namestring temp-name :start 5)))
  (and
	(pathnamep temp-pathname)
	(string-equal temp-name (namestring temp-pathname))
  )))

(test-defun 23Parse-End (host)
  (let* ((temp-name (concatenate 'string "{" host "}<cmltest>any-name.type uh"))
	    (string-length (length temp-name))
	    (temp-pathname (parse-namestring temp-name :end (- string-length 3))))
  (and
	(pathnamep temp-pathname)
	(string-equal temp-name (namestring temp-pathname))
  )))


(test-defun 23DRIVE-parse (host)
	"run a set of tests across several hosts"
  (and
	(23Parse-Basic host)
	(23Parse-Variable-Type host)
	(23Parse-Junk host)
	(23Parse-Start host)
	(23Parse-End host)
  ))

)	; End of defining functions for this test group.

(do-test "test with lots of variations in {core}"
  (23DRIVE-parse "core"))

; problem with dsk vs pseudo-dsk
;(do-test "test with lots of variations in {dsk}"
;  (23DRIVE-parse "dsk"))

(do-test "test with lots of variations in {erinyes}"
  (23DRIVE-parse "erinyes"))


)	; End of defining functions for this test group.


	

(do-test "test error conditions"
   (flet ((handle-expect-errors (value) 
		  (xcl-test:expect-errors (cl:error) 
			(parse-PATHNAMES value))
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
	T		; get ride of some stuff, what's the better way?
   )))



STOP
