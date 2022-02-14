;; Function To Be Tested: MAKE-PATHNAME
;;
;; Source:        Steele's book    
;;                Section 23.1.2	PATHNAME Functions        
;;                Page: 416
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 12,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-1-2-MAKE-PATHNAME.TEST
;;
;;
;; Syntax:        (MAKE-PATHNAME &key :host :device :directory 
;;							  :name :type :version :defaults)
;;
;;
;;
;; Function Description:
;;     creates a pathname
;; 
;; 
;; 
;; Argument(s):   host - the name of the host
;;			   device - the name of the device
;;			   directory - the name of the directory
;;			   name - the name of the file
;;			   type - the type of file it is
;;			   version - the version of the file
;;			   defaults - the default values
;;
;; Returns:       a pathname 
;;


(do-test "load functions for chapter 23 tests"
(unless (fboundp '23check-parse-list)   (load "{eris}<lispcore>cml>test>23-functions.dfasl"))
  T)			; get here and functions were defined


(do-test "test a simple case"
  (let ((temp-pathname (make-pathname :host "core" :name "hello")))
  (and
	(pathnamep temp-pathname)
	(string-equal "{CORE}HELLO" (namestring temp-pathname))
  )))

(do-test "check defaulting works."
  (let ((temp-namestring (namestring *default-pathname-defaults*))
	   (t-host-namestring (host-namestring *default-pathname-defaults*)))
  (and
	(equal temp-namestring (namestring (make-pathname 
		:defaults *default-pathname-defaults*)))
	(equal (concatenate 'string "{" t-host-namestring "}")
		(namestring (make-pathname)))
  )))

;;; test do same type of test on several different HOSTS


(do-test "test a couple simple variations, core"
  (and
	(23DRIVE-MAKE-LIST "{CORE}TEMPDEVICE:<TEMPDIR>HELLO.TYPE;2"
		"core" "tempdevice" "tempdir" "hello" "type" 2)
	(23DRIVE-MAKE-LIST "{CORE}<TEMPDIR>HELLO.TYPE;2"
		"core" nil "tempdir" "hello" "type" 2)
	(23DRIVE-MAKE-LIST "{CORE}TEMPDEVICE:HELLO.TYPE;2"
		"core" "tempdevice" nil "hello" "type" 2)
	(23DRIVE-MAKE-LIST "{CORE}HELLO.TYPE;2"
		"core" nil nil "hello" "type" 2)
  ))

(do-test "test a couple simple variations, dsk"
  (23DRIVE-MAKE-LIST "{DSK}<LISPFILES>TEMPDIR>HELLO.TYPE;2"
		"dsk" NIL "lispfiles>tempdir" "hello" "type" 2))

(do-test "test a couple simple variations, erinyes"
  (23DRIVE-MAKE-LIST "{ERINYES}<CMLTEST>HELLO.TYPE;2"
		"erinyes" nil "CMLTEST" "hello" "type" 2))

(do-test "test a couple simple variations, pollux"
  (23DRIVE-MAKE-LIST "{POLLUX:AISNORTH:XEROX}<CMLTEST>HELLO.TYPE;2"
		"pollux:aisnorth:xerox" nil "CMLTEST" "hello" "type" 2))


	




STOP
