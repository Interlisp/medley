;: Test File for Function: plusp
;; Source:	 Steel's Book, Chapter 12, Section 2, page 196
;; Created by: John Park  ;; Creation Date: May 1, 86
;; Predicate: The minus predicate is true if number is less than zero and false otherwise.
;; Syntax Format:  (minusp number)
;; Input: number (negative number or non-complex number)
;; Output: T or NIL

(do-test   minusp-test
		(and (minusp -1)
			(minusp -4.0)
			(minusp  -79)
			(not (minusp -0.0))
			(not (minusp 1000))))
				 			