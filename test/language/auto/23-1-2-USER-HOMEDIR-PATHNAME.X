;; Function To Be Tested: USER-HOMEDIR-PATHNAME
;;
;; Source:        Steele's book    
;;                Section 23.1.2	PATHNAME Functions        
;;                Page: 418
;;
;; Created By:    Henry Cate III
;;
;; Creation Date: November 10,1986
;;
;; Last Update:    
;;
;; Filed As:      {ERIS}<LISPCORE>CML>TEST>23-1-2-USER-HOMEDIR-PATHNAME.TEST
;;
;;
;; Syntax:        (USER-HOMEDIR-PATHNAME &optional host)
;;
;;
;;
;; Function Description:
;;     returns a pathname for the user's "home directory"
;; 
;; 
;; 
;; Argument(s):   host - the name of a host 
;;
;; Returns:       a pathname for the user's "home directory"
;;




(do-test "test a simple case"
	(pathnamep (USER-HOMEDIR-PATHNAME)))


STOP
