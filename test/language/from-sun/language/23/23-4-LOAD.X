;; Function To Be Tested: LOAD
;;
;; Source:        Steele's book    
;;                Section 23.4	        
;;                Page: 426
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 13,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-4-load.TEST
;;
;;
;; Syntax:        (LOAD filename &key  :verbose :print :if-does-not-exist)
;;
;;
;;
;; Function Description:
;;     renames a file
;; 
;; 
;; 
;; Argument(s):   file - an existing file
;;			   new-name - the new name
;;
;; Returns:       three values 
;;				a) the new name filled in 
;;				b) the truename of file before renamed
;;				c) truename after renamed
;;


(do-test "simple case, try loading the functions file"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.DFASL"))	
	t)

(do-test "building a file in core, make sure can load"
	; open a file, write to it, use evaluate to load file
	T)

(do-test "test for files which do not exist"
	T)

(do-test "test error conditions"
   (flet ((handle-expect-errors (value) 
		  (xcl-test:expect-errors (cl:error) 
			(cl:load value))
		))
   (and
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
