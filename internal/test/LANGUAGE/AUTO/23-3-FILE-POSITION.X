;; Function To Be Tested: FILE-POSITION
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
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-3-FILE-POSITION.TEST
;;
;;
;; Syntax:        (FILE-POSITION file-stream &optional position)
;;
;;
;;
;; Function Description:
;;      either returns the current postion, or sets current position
;; 
;; 
;; 
;; Argument(s):   file-stream - a stream which is open
;;			   position - where want to go to
;;
;; Returns:       the current position
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
  (let* ((temp-stream (cl:open 
		(23BUILD-PATHNAME "DSK" NIL "LISPFILES")
		:direction :output :element-type 'string-char))
	    (result (eq 0 (file-position temp-stream))))
	(23File-CleanUP temp-stream)
	result))


(do-test-group "test do same type of test on several different HOSTS"
	:before (PROGN

(test-defun 23Position-Empty (host)
  (let* ((temp-stream (23Length-SetUP host))
	    (result (eq 0 (file-position temp-stream))))
	(23File-CleanUP temp-stream)
	result))

(test-defun 23Position-String-Char (host)
  (let* ((temp-stream (23Length-SetUP host))
	    (toss-away (prin1 'hello temp-stream))
	    (result (eq 5 (file-position temp-stream))))
	(23File-CleanUP temp-stream)
	result))

(test-defun 23Position-Unsigned-byte (host)
  (let* ((temp-stream (23Length-SetUP host 'unsigned-byte))
	    (toss-away (write-byte 8 temp-stream))
	    (result (eq 1 (file-position temp-stream))))
	(23File-CleanUP temp-stream)
	result))

(test-defun 23Position-String-Char-Complex (host)
  (let* ((temp-stream (23Length-SetUP host))
	    (toss-away (prin1 'hello temp-stream))
	    (first-position (file-position temp-stream))
	    (toss-away-2 (prin1 'hello temp-stream))
	    (second-position (file-position temp-stream))
	    (result-set-position (file-position temp-stream 0))
	    (result-read-char (read-char temp-stream)))
	(23File-CleanUP temp-stream)
	(and
	  (eq first-position 5)
	  (eq second-position 10)
	  (eq result-set-position T)
	  (eq result-read-char #\H)
	)))

(test-defun 23DRIVE-Position (host)
	"run a set of tests across several hosts"
  (and
	(23Position-Empty host)
	(23Position-String-Char host)
	(23Position-Unsigned-byte host)
	(23Position-String-Char-Complex host)
  ))

)	; End of defining functions for this test group.

(do-test "test the length with lots of variations in {core}"
  (23DRIVE-Position "core"))

(do-test "test the length with lots of variations in {erinyes}"
  (23DRIVE-Position "erinyes"))



)	; end of do-test-group





STOP
