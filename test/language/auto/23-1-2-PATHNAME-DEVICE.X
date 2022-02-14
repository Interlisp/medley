;; Function To Be Tested: PATHNAME-DEVICE
;;
;; Source:        Steele's book    
;;                Section 23.1.2	PATHNAME Functions        
;;                Page: 417
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 5,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-1-2-PATHNAME-DEVICE.TEST
;;
;;
;; Syntax:        (PATHNAME-DEVICE pathname)
;;
;;
;;
;; Function Description:
;;     returns the name of the device as a string or symbol
;; 
;; 
;; 
;; Argument(s):   pathname - pointing to a file 
;;
;; Returns:       the device name
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.def"))
  T)			; get here and functions were defined


(do-test "test a simple case"
	:before (progn (setq simple-list 
		  (23BUILD-LIST-OF-FILENAME-PATHNAMES "core" 3 "tempdevice")))
	:after (progn (23Delete-file-list simple-list))
	(23TEST-PATHNAME-VALUE-list simple-list 'DEVICE "TEMPDEVICE"))

;;; test do same type of test on several different HOSTS




(do-test "test lots of variations in {CORE}"
  (and
	(23DRIVE-DEVICE-LIST "core" "tempdevice" "TEMPDEVICE")
	(23DRIVE-DEVICE-LIST "core" "tempdevice12-32" "TEMPDEVICE12-32")
  ))


	

(do-test "test error conditions"
   (flet ((handle-expect-errors (value) 
		  (xcl-test:expect-errors (cl:error) 
			(PATHNAME-DEVICE value))
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
	(not (PATHNAME-DEVICE "DF"))
	(not (PATHNAME-DEVICE "OCT-6-65"))
	(not (PATHNAME-DEVICE 'hello))
	(not (PATHNAME-DEVICE 'bye))
	(not (PATHNAME-DEVICE (make-broadcast-stream *terminal-io*)))
   )))



STOP
