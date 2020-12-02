;: Test File for Function: oddp
;; Source:	 Steel's Book, Chapter 12, Section 2, page 196
;; Created by: John Park  ;; Creation Date: May 1, 86
;; Predicate: The oddp predicate is true if integer is odd and otherwise false.
;; Syntax Format:  (oddp integer)
;; Input: odd integer
;; Output: T or NIL

				 			
(do-test oddp-test
		(and (oddp 3)
			(oddp -7)
			(not (oddp 0))
			(not (oddp 4))
			(not (oddp 3.0))
			(not (oddp -3.0)))) 
		