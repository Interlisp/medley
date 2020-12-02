;; Function To Be Tested: FILE-LENGTH
;;
;; Source:        Steele's book    
;;                Section 23.3	        
;;                Page: 425
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 20,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-3-FILE-LENGTH.TEST
;;
;;
;; Syntax:        (FILE-LENGTH file-stream)
;;
;;
;;
;; Function Description:
;;      returns the length of a file
;; 
;; 
;; 
;; Argument(s):   file - a stream which is open
;;
;; Returns:       the length of the file
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
  (let* ((temp-stream (cl:open 
		(23BUILD-PATHNAME "DSK" NIL "LISPFILES")
		:direction :output :element-type 'string-char))
	    (result (eq 0 (file-length temp-stream))))
	(23File-CleanUP temp-stream)
	result))


(do-test-group "test do same type of test on several different HOSTS"
	:before (PROGN

(test-defun 23Length-Empty (host)
  (let* ((temp-stream (23File-SetUP host))
	    (result (eq 0 (file-length temp-stream))))
	(23File-CleanUP temp-stream)
	result))

(test-defun 23Length-String-Char (host)
  (let* ((temp-stream (23File-SetUP host))
	    (toss-away (prin1 'hello temp-stream))
	    (result (eq 5 (file-length temp-stream))))
	(23File-CleanUP temp-stream)
	result))

(test-defun 23Length-Unsigned-byte (host)
  (let* ((temp-stream (23File-SetUP host 'unsigned-byte))
	    (toss-away (write-byte 8 temp-stream))
	    (result (eq 1 (file-length temp-stream))))
	(23File-CleanUP temp-stream)
	result))

(test-defun 23DRIVE-Length (host)
	"run a set of tests across several hosts"
  (and
	(23Length-Empty host)
	(23Length-String-Char host)
	(23Length-Unsigned-byte host)
  ))

)	; End of defining functions for this test group.

(do-test "test the length with lots of variations in {core}"
  (23DRIVE-Length "core"))

(do-test "test the length with lots of variations in {erinyes}"
  (23DRIVE-Length "erinyes"))



)	; end of do-test-group


(do-test "test error conditions"
   (and
	(not (file-length 54))
	(not (file-length #\h))
	(not (file-length (list 'hi 'bye)))
	(not (file-length (make-array '(2 3 4))))
	(not (file-length (make-hash-table)))
	(not (file-length (copy-readtable)))
	(not (file-length (find-package 'Lisp)))
;	(not (file-length (make-random-state)))
	(not (file-length "DF"))
	(not (file-length "OCT-6-65"))
	(not (file-length 'hello))
	(not (file-length 'bye))
   ))



STOP
