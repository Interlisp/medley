;; Source:	 Steel's Book, Chapter 12, Section 2, page 196
;; Created by: John Park  ;; Creation Date: May 1, 86
;; Predicate: The evenp predicate is true if integer is even and is false otherwise.
;; Syntax Format:  (evenp integer)
;; Input: integer
;; Output: T or NIL

(do-test   evenp-test
		(and (evenp 2)
			(evenp -4)
			(not (evenp 3))
			(not (evenp 0))
			(not (evenp 10.0))))
				 			