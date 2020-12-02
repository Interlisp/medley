;; Function To Be Tested: truename
;;
;; Source:        CLtL p. 413 
;; Chapter 23: File System Interface		Section 23-1-2: Pathname Functions
;;
;; Created By:    Herb Jellinek
;;
;; Creation Date:  8 August 86
;;
;; Last Update:   October 7, 1986 
;;
;; Filed As:      {eris}<lispcore>cml>test>23-1-2-truename.test
;;
;;
;; Syntax: truename pathname               
;;
;; Function Description: if pathname is an open stream, returns the pathname of
;; file.  Otherwise looks to see if pathname names an extant file; is so,
;; returns its pathname, if not, signals an error.
;;
;; Argument(s):  pathname - a pathname, string, symbol or stream        	
;;
;; Returns: a pathname             
;;

 ;;
;;;; Watch out for implementation-dependent filenames below
 ;;

(do-test-group (truename-group
	:before (progn
			(test-setq astream (make-broadcast-stream *terminal-io*))
			(test-setq bstream (open "{core}<aisbu.modem>imaginary"
						:direction :output))
			(test-setq cstream (make-broadcast-stream))
			(close (test-setq dstream (open "{dsk}emptyfile.;1"
							  :direction :output
							  :if-does-not-exist :create)))
			(delete-file "{dsk}emptyfile.;1")
			(test-setq estream
				(open "{core}<aisbu.modem>JUNK" :direction :output))
			(test-setq file-streams (list bstream estream))
			(test-setq extant-streams (list astream bstream cstream estream))
			(test-setq all-streams (cons dstream extant-streams))
			(test-setq symbol 'five))
	:after (progn
			(mapcar #'close file-streams)
			(mapcar #'delete-file file-streams))
	(do-test truename-test
		(and
			(every #'(lambda (x) x) (mapcar #'truename file-streams))
			(expect-errors (simple-error) (truename "{core}non-existent.;1"))
			(expect-errors (simple-error) (truename dstream))
			(expect-errors (simple-error) (truename astream))
			(every #'(lambda (x) x)
				(mapcar #'truename (mapcar #'pathname extant-streams)))
		)
	)
))


STOP
