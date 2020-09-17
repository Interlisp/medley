;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-PPCRE; Base: 10 -*-
;;; $Header: /usr/local/cvsrep/cl-ppcre/regex-class.lisp,v 1.1.1.1 2002/12/20 10:10:44 edi Exp $

;;; This file defines the REGEX class and some utility methods for
;;; this class. REGEX objects are used to represent the (transformed)
;;; parse trees internally

;;; Copyright (c) 2002, Dr. Edmund Weitz. All rights reserved.

;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:

;;;   * Redistributions of source code must retain the above copyright
;;;     notice, this list of conditions and the following disclaimer.

;;;   * Redistributions in binary form must reproduce the above
;;;     copyright notice, this list of conditions and the following
;;;     disclaimer in the documentation and/or other materials
;;;     provided with the distribution.

;;; THIS SOFTWARE IS PROVIDED BY THE AUTHOR 'AS IS' AND ANY EXPRESSED
;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
;;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

(in-package "CL-PPCRE")

(defclass regex ()
  ()
  (:documentation "The REGEX base class. All other classes inherit from this one."))


(defclass seq (regex)
  ((elements :initarg :elements
             :accessor elements
             :type cons
             :documentation "A list of REGEX objects."))
  (:documentation "SEQ objects represents sequences of regexes.
(Like \"ab\" is the sequence of \"a\" and \"b\".)"))

(defclass alternation (regex)
  ((choices :initarg :choices
            :accessor choices
            :type cons
            :documentation "A list of REGEX objects"))
  (:documentation "ALTERNATION objects represent alternations of regexes.
(Like \"a|b\" ist the alternation of \"a\" or \"b\".)"))

(defclass lookahead (regex)
  ((regex :initarg :regex
          :accessor regex
          :documentation "The REGEX object we're checking.")
   (positivep :initarg :positivep
              :reader positivep
              :documentation "Whether this assertion is positive."))
  (:documentation "LOOKAHEAD objects represent look-ahead assertions."))

(defclass lookbehind (regex)
  ((regex :initarg :regex
          :accessor regex
          :documentation "The REGEX object we're checking.")
   (positivep :initarg :positivep
              :reader positivep
              :documentation "Whether this assertion is positive.")
   (len :initarg :len
        :accessor len
        :type fixnum
        :documentation "The (fixed) length of the enclosed regex."))
  (:documentation "LOOKBEHIND objects represent look-behind assertions."))

(defclass repetition (regex)
  ((regex :initarg :regex
          :accessor regex
          :documentation "The REGEX that's repeated.")
   (greedyp :initarg :greedyp
            :reader greedyp
            :documentation "Whether the repetition is greedy.")
   (minimum :initarg :minimum
            :accessor minimum
            :type fixnum
            :documentation "The minimal number of repetitions.")
   (maximum :initarg :maximum
            :accessor maximum
            :documentation "The maximal number of repetitions.
Can be NIL for unbounded.")
   (min-len :initarg :min-len
            :reader min-len
            :documentation "The minimal length of the enclosed regex.")
   (len :initarg :len
        :reader len
        :documentation "The length of the enclosed regex. NIL if unknown.")
   (min-rest :initform 0
             :accessor min-rest
             :type fixnum
             :documentation "The minimal number of characters which must
appear after this repetition.")
   (contains-register-p :initarg :contains-register-p
                        :reader contains-register-p
                        :documentation "If the regex contains a register."))
  (:documentation "REPETITION objects represent repetitions of regexes."))

(defclass register (regex)
  ((regex :initarg :regex
          :accessor regex
          :documentation "The inner regex.")
   (num :initarg :num
        :reader num
        :type fixnum
        :documentation "The number of this register, starting from 0.
This is the index into *REGS-START* and *REGS-END*."))
  (:documentation "REGISTER objects represent register groups."))

(defclass standalone (regex)
  ((regex :initarg :regex
          :accessor regex
          :documentation "The inner regex."))
  (:documentation "A standalone regular expression."))

(defclass back-reference (regex)
  ((num :initarg :num
        :reader num
        :type fixnum
        :documentation "The number of the register this reference refers to.")
   (case-insensitive-p :initarg :case-insensitive-p
                       :reader case-insensitive-p
                       :documentation "Whether we check case-insensitively."))
  (:documentation "BACK-REFERENCE objects represent backreferences."))

(defclass char-class (regex)
  ((hash :initarg :hash
         :reader hash
         :type hash-table
         :documentation "A hash table the keys of which are the characters;
the values are always T.")
   (case-insensitive-p :initarg :case-insensitive-p
                       :reader case-insensitive-p
                       :documentation "If the char class case-insensitive.")
   (invertedp :initarg :invertedp
              :reader invertedp
              :documentation "Whether we mean the inverse of the char class.")
   (word-char-class-p :initarg :word-char-class-p
                      :reader word-char-class-p
                      :documentation "Whether this CHAR CLASS
represents the special class WORD-CHAR-CLASS."))
  (:documentation "CHAR-CLASS objects represent character classes."))

(defclass str (regex)
  ((str :initarg :str
        :accessor str
        :type string
        :documentation "The actual string.")
   (len :initform 0
        :accessor len
        :type fixnum
        :documentation "The length of the string.")
   (case-insensitive-p :initarg :case-insensitive-p
                       :reader case-insensitive-p
                       :documentation "If we match case-insensitively.")
   (offset :initform nil
           :accessor offset
           :documentation "Offset from the left of the whole parse tree.
The first regex has offset 0.
NIL if unknown, i.e. behind a variable-length regex.")
   (skip :initform nil
         :initarg :skip
         :accessor skip
         :documentation "If we can avoid testing for this string
because the SCAN function has done this already.")
   (start-of-end-string-p :initform nil
                          :accessor start-of-end-string-p
                          :documentation "If this is the unique STR which
starts END-STRING (a slot of MATCHER)."))
  (:documentation "STR objects represent string."))

(defmethod initialize-instance :after ((str str) &rest init-args)
  (declare (optimize speed space))
  (declare (ignore init-args))
  "Automatically computes the length of a STR after initialization."
  (setf (len str) (length (str str))))

(defclass anchor (regex)
  ((startp :initarg :startp
           :reader startp
           :documentation "Whether this is a \"start anchor\".")
   (multi-line-p :initarg :multi-line-p
                 :reader multi-line-p
                 :documentation "Whether we're in multi-line mode,
i.e. whether each #\Newline is surrounded by anchors.")
   (no-newline-p :initarg :no-newline-p
                 :reader no-newline-p
                 :documentation "Whether we ignore #\Newline at the end."))
  (:documentation "ANCHOR objects represent anchors like \"^\" or \"$\"."))

(defclass everything (regex)
  ((single-line-p :initarg :single-line-p
                  :reader single-line-p
                  :documentation "Whether we're in single-line mode,
i.e. whether we also match #\Newline."))
  (:documentation "EVERYTHING objects represent regexes matching
\"everything\", i.e. dots."))

(defclass word-boundary (regex)
  ((negatedp :initarg :negatedp
             :reader negatedp
             :documentation "Whether we mean the opposite,
i.e. no word-boundary."))
  (:documentation "WORD-BOUNDARY objects represent word-boundary assertions."))

(defclass branch (regex)
  ((test :initarg :test
         :reader test
         :documentation "The test of this branch, one of LOOKAHEAD,
LOOKBEHIND, or a number.")
   (then-regex :initarg :then-regex
               :reader then-regex
               :documentation "The regex that's to be matched if the
test succeeds.")
   (else-regex :initarg :else-regex
               :initform (make-instance 'void)
               :reader else-regex
               :documentation "The regex that's to be matched if the
test fails."))
  (:documentation "BRANCH objects represent Perl's conditional regular
expressions."))

(defclass void (regex)
  ()
  (:documentation "VOID objects represent empty regular expressions."))

;;; The following four methods allow a VOID object to behave like a
;;; zero-length STR object (only readers needed)

(defmethod len ((void void))
  (declare (optimize speed space))
  0)

(defmethod str ((void void))
  (declare (optimize speed space))
  "")

(defmethod skip ((void void))
  (declare (optimize speed space))
  nil)

(defmethod start-of-end-string-p ((void void))
  (declare (optimize speed space))
  nil)

;;; The PRINT-OBJECT below are here only for debugging purposes, they
;;; aren't used by the regex engine.

(defmethod print-object ((seq seq) stream)
  (print-unreadable-object (seq stream :type t)
    (with-slots ((elements elements))
        seq
      (prin1 (first elements))
      (format stream "~{ ~S~}" (rest elements)))))

(defmethod print-object ((alternation alternation) stream)
  (print-unreadable-object (alternation stream :type t)
    (with-slots ((choices choices))
        alternation
      (prin1 (first choices))
      (format stream "~{~S ~}" (rest choices)))))

(defmethod print-object ((branch branch) stream)
  (print-unreadable-object (branch stream :type t)
    (format stream "(~S) ~S ~S" (test branch) (then-regex branch) (else-regex branch))))

(defmethod print-object ((lookahead lookahead) stream)
  (print-unreadable-object (lookahead stream :type t)
    (format stream "~A~S ~S"
            (if (positivep lookahead) "" "(neg.) ")
            (regex lookahead))))

(defmethod print-object ((lookbehind lookbehind) stream)
  (print-unreadable-object (lookbehind stream :type t)
    (format stream "~A~S"
            (if (positivep lookbehind) "" "(neg.) ")
            (regex lookbehind))))

(defmethod print-object ((repetition repetition) stream)
  (print-unreadable-object (repetition stream :type t)
    (format stream "(~A ~A ~A) ~S"
            (if (greedyp repetition) "greedy" "non-greedy")
            (minimum repetition)
            (maximum repetition)
            (regex repetition))))

(defmethod print-object ((register register) stream)
  (print-unreadable-object (register stream :type t)
    (format stream "~A ~S"
            (num register)
            (regex register))))

(defmethod print-object ((standalone standalone) stream)
  (print-unreadable-object (standalone stream :type t)
    (format stream "~S"
            (regex standalone))))

(defmethod print-object ((back-reference back-reference) stream)
  (print-unreadable-object (back-reference stream :type t)
    (format stream "~A~A"
            (if (case-insensitive-p back-reference) "(c-i) " "")
            (num back-reference))))

(defmethod print-object ((char-class char-class) stream)
  (print-unreadable-object (char-class stream :type t)
    (if (word-char-class-p char-class)
      (format stream "~Aalphanumeric"
              (if (invertedp char-class) "(inv.) " ""))
      (format stream "~Awith ~A element~:P"
              (if (invertedp char-class) "(inv.) " "")
              (hash-table-count (hash char-class))))))

(defmethod print-object ((str str) stream)
  (print-unreadable-object (str stream :type t)
    (format stream "~S~A"
            (str str)
            (if (case-insensitive-p str) " (c-i)" ""))))

(defmethod print-object ((void void) stream)
  (print-unreadable-object (void stream)
    (prin1 'void)))

(defgeneric case-mode (regex old-case-mode)
  (declare (optimize speed space))
  (:documentation "Utility function used by the optimizer (see GATHER-STRINGS).
Returns a keyword denoting the case-(in)sensitivity of a STR or its
second argument if the STR has length 0. Returns NIL for REGEX objects
which are not of type STR."))

(defmethod case-mode ((str str) old-case-mode)
  (cond ((zerop (len str))
          old-case-mode)
        ((case-insensitive-p str)
          :case-insensitive)
        (t
          :case-sensitive)))

(defmethod case-mode ((regex regex) old-case-mode)
  (declare (ignore old-case-mode))
  nil)

(defgeneric copy-regex (regex)
  (declare (optimize speed space))
  (:documentation "Implements a deep copy of a REGEX object."))

(defmethod copy-regex ((anchor anchor))
  (make-instance 'anchor
                 :startp (startp anchor)
                 :multi-line-p (multi-line-p anchor)
                 :no-newline-p (no-newline-p anchor)))

(defmethod copy-regex ((everything everything))
  (make-instance 'everything
                 :single-line-p (single-line-p everything)))

(defmethod copy-regex ((word-boundary word-boundary))
  (make-instance 'copy-regex
                 :negatedp (negatedp word-boundary)))

(defmethod copy-regex ((void void))
  (make-instance 'void))

(defmethod copy-regex ((lookahead lookahead))
  (make-instance 'lookahead
                 :regex (copy-regex (regex lookahead))
                 :positivep (positivep lookahead)))

(defmethod copy-regex ((seq seq))
  (make-instance 'seq
                 :elements (mapcar #'copy-regex (elements seq))))

(defmethod copy-regex ((alternation alternation))
  (make-instance 'alternation
                 :choices (mapcar #'copy-regex (choices alternation))))

(defmethod copy-regex ((branch branch))
  (with-slots ((test test))
      branch
    (make-instance 'branch
                   :test (if (typep test 'regex)
                           (copy-regex test)
                           test)
                   :then-regex (copy-regex (then-regex branch))
                   :else-regex (copy-regex (else-regex branch)))))

(defmethod copy-regex ((lookbehind lookbehind))
  (make-instance 'lookbehind
                 :regex (copy-regex (regex lookbehind))
                 :positivep (positivep lookbehind)
                 :len (len lookbehind)))

(defmethod copy-regex ((repetition repetition))
  (make-instance 'repetition
                 :regex (copy-regex (regex repetition))
                 :greedyp (greedyp repetition)
                 :minimum (minimum repetition)
                 :maximum (maximum repetition)
                 :min-len (min-len repetition)
                 :len (len repetition)
                 :contains-register-p (contains-register-p repetition)))

(defmethod copy-regex ((register register))
  (make-instance 'register
                 :regex (copy-regex (regex register))
                 :num (num register)))

(defmethod copy-regex ((standalone standalone))
  (make-instance 'standalone
                 :regex (copy-regex (regex standalone))))

(defmethod copy-regex ((back-reference back-reference))
  (make-instance 'back-reference
                 :num (num back-reference)
                 :case-insensitive-p (case-insensitive-p back-reference)))

(defmethod copy-regex ((char-class char-class))
  (make-instance 'char-class
                 :hash (hash char-class)
                 :case-insensitive-p (case-insensitive-p char-class)
                 :invertedp (invertedp char-class)
                 :word-char-class-p (word-char-class-p char-class)))

(defmethod copy-regex ((str str))
  (make-instance 'str
                 :str (str str)
                 :case-insensitive-p (case-insensitive-p str)))

;;; Note that COPY-REGEX and REMOVE-REGISTERS could have easily been
;;; wrapped into one function. Maybe in the next release...

;;; Further note that this function is used by CONVERT to factor out
;;; complicated repetitions, i.e. cases like
;;;   (a)* -> (?:a*(a))?
;;; This won't work for, say,
;;;   ((a)|(b))* -> (?:(?:a|b)*((a)|(b)))?
;;; and therefore we stop REGISTER removal once we see an ALTERNATION.

(defgeneric remove-registers (regex)
  (declare (optimize speed space))
  (:documentation "Returns a deep copy of a REGEX (see COPY-REGEX) and
optionally removes embedded REGISTER objects if possible and if the
special variable REMOVE-REGISTERS-P is true."))

(defmethod remove-registers ((register register))
  (declare (special remove-registers-p reg-seen))
  (cond (remove-registers-p
          (remove-registers (regex register)))
        (t
          ;; mark REG-SEEN as true so enclosing REPETITION objects
          ;; (see method below) know if they contain a register or not
          (setq reg-seen t)
          (copy-regex register))))

(defmethod remove-registers ((repetition repetition))
  (let* (reg-seen
         (inner-regex (remove-registers (regex repetition))))
    ;; REMOVE-REGISTERS will set REG-SEEN (see method above) if
    ;; (REGEX REPETITION) contains a REGISTER
    (declare (special reg-seen))
    (make-instance 'repetition
                   :regex inner-regex
                   :greedyp (greedyp repetition)
                   :minimum (minimum repetition)
                   :maximum (maximum repetition)
                   :min-len (min-len repetition)
                   :len (len repetition)
                   :contains-register-p reg-seen)))

(defmethod remove-registers ((standalone standalone))
  (make-instance 'standalone
                 :regex (remove-registers (regex standalone))))

(defmethod remove-registers ((lookahead lookahead))
  (make-instance 'lookahead
                 :regex (remove-registers (regex lookahead))
                 :positivep (positivep lookahead)))

(defmethod remove-registers ((lookbehind lookbehind))
  (make-instance 'lookbehind
                 :regex (remove-registers (regex lookbehind))
                 :positivep (positivep lookbehind)
                 :len (len lookbehind)))

(defmethod remove-registers ((branch branch))
  (with-slots ((test test))
      branch
    (make-instance 'branch
                   :test (if (typep test 'regex)
                           (remove-registers test)
                           test)
                   :then-regex (remove-registers (then-regex branch))
                   :else-regex (remove-registers (else-regex branch)))))

(defmethod remove-registers ((alternation alternation))
  (declare (special remove-registers-p))
  ;; an ALTERNATION, so we can't remove REGISTER objects further down
  (setq remove-registers-p nil)
  (copy-regex alternation))

(defmethod remove-registers ((regex regex))
  (copy-regex regex))

(defmethod remove-registers ((seq seq))
  (make-instance 'seq
                 :elements (mapcar #'remove-registers (elements seq))))

(defgeneric everythingp (regex)
  (declare (optimize speed space))
  (:documentation "Returns an EVERYTHING object if REGEX is equivalent
to this object, otherwise NIL. So, \"(.){1}\" would return true
(i.e. the object corresponding to \".\", for example."))

(defmethod everythingp ((seq seq))
  ;; we might have degenerate cases like (:SEQUENCE :VOID ...)
  ;; due to the parsing process
  (let ((cleaned-elements (remove-if #'(lambda (element)
                                         (typep element 'void))
                                     (elements seq))))
    (and (= 1 (length cleaned-elements))
         (everythingp (first cleaned-elements)))))

(defmethod everythingp ((alternation alternation))
  (with-slots ((choices choices))
      alternation
    (and (= 1 (length choices))
         ;; this is unlikely to happen for human-generated regexes,
         ;; but machine-generated ones might look like this
         (everythingp (first choices)))))

(defmethod everythingp ((repetition repetition))
  (with-slots ((maximum maximum)
               (minimum minimum)
               (regex regex))
      repetition
    (and maximum
         (= 1 minimum maximum)
         ;; treat "<regex>{1,1}" like "<regex>"
         (everythingp regex))))

(defmethod everythingp ((register register))
  (everythingp (regex register)))

(defmethod everythingp ((standalone standalone))
  (everythingp (regex standalone)))

(defmethod everythingp ((everything everything))
  everything)

(defmethod everythingp ((regex regex))
  ;; the general case for ANCHOR, BACK-REFERENCE, BRANCH, CHAR-CLASS,
  ;; LOOKAHEAD, LOOKBEHIND, STR, VOID, and WORD-BOUNDARY
  nil)

(defgeneric regex-length (regex)
  (declare (optimize speed space))
  (:documentation "Return the length of REGEX if it is fixed, NIL otherwise."))

(defmethod regex-length ((seq seq))
  ;; simply add all inner lengths unless one of them is NIL
  (loop for sub-regex in (elements seq)
        for len = (regex-length sub-regex)
        if (not len) do (return nil)
        sum len))

(defmethod regex-length ((alternation alternation))
  ;; only return a true value if all inner lengths are non-NIL and
  ;; mutually equal
  (loop for sub-regex in (choices alternation)
        for old-len = nil then len
        for len = (regex-length sub-regex)
        if (or (not len)
               (and old-len (/= len old-len))) do (return nil)
        finally (return len)))

(defmethod regex-length ((branch branch))
  ;; only return a true value if both alternations have a length and
  ;; if they're equal
  (let ((then-length (regex-length (then-regex branch))))
    (and then-length
         (eql then-length (regex-length (else-regex branch)))
         then-length)))

(defmethod regex-length ((repetition repetition))
  ;; we can only compute the length of a REPETITION object if the
  ;; number of repetitions is fixed; note that we don't call
  ;; REGEX-LENGTH for the inner regex, we assume that the LEN slot is
  ;; always set correctly
  (with-slots ((len len) (minimum minimum) (maximum maximum))
      repetition
    (if (and len
             (eq minimum maximum))
      (* minimum len)
      nil)))

(defmethod regex-length ((register register))
  (regex-length (regex register)))

(defmethod regex-length ((standalone standalone))
  (regex-length (regex standalone)))

(defmethod regex-length ((back-reference back-reference))
  ;; with enough effort we could possibly do better here, but
  ;; currently we just give up and return NIL
  nil)
    
(defmethod regex-length ((char-class char-class))
  1)

(defmethod regex-length ((everything everything))
  1)

(defmethod regex-length ((str str))
  (len str))

(defmethod regex-length ((regex regex))
  ;; the general case for ANCHOR, LOOKAHEAD, LOOKBEHIND, VOID, and
  ;; WORD-BOUNDARY (which all have zero-length)
  0)

(defgeneric regex-min-length (regex)
  (declare (optimize speed space))
  (:documentation "Returns the minimal length of REGEX."))

(defmethod regex-min-length ((seq seq))
  ;; simply add all inner minimal lengths
  (loop for sub-regex in (elements seq)
        for len = (regex-min-length sub-regex)
        sum len))

(defmethod regex-min-length ((alternation alternation))
  ;; minimal length of an alternation is the minimal length of the
  ;; "shortest" element
  (loop for sub-regex in (choices alternation)
        for len = (regex-min-length sub-regex)
        minimize len))

(defmethod regex-min-length ((branch branch))
  ;; minimal length of both alternations
  (min (regex-min-length (then-regex branch))
       (regex-min-length (else-regex branch))))

(defmethod regex-min-length ((repetition repetition))
  ;; obviously the product of the inner minimal length and the minimal
  ;; number of repetitions
  (* (minimum repetition) (min-len repetition)))
    
(defmethod regex-min-length ((register register))
  (regex-min-length (regex register)))
    
(defmethod regex-min-length ((standalone standalone))
  (regex-min-length (regex standalone)))
    
(defmethod regex-min-length ((char-class char-class))
  1)

(defmethod regex-min-length ((everything everything))
  1)

(defmethod regex-min-length ((str str))
  (len str))
    
(defmethod regex-min-length ((regex regex))
  ;; the general case for ANCHOR, BACK-REFERENCE, LOOKAHEAD,
  ;; LOOKBEHIND, VOID, and WORD-BOUNDARY
  0)

(defgeneric compute-offsets (regex start-pos)
  (declare (optimize speed space))
  (:documentation "Returns the offset the following regex would have
relative to START-POS or NIL if we can't compute it. Sets the OFFSET
slot of REGEX to START-POS if REGEX is a STR. May also affect OFFSET
slots of STR objects further down the tree."))

;; note that we're actually only interested in the offset of
;; "top-level" STR objects (see ADVANCE-FN in the SCAN function) so we
;; can stop at variable-length alternations and don't need to descend
;; into repetitions

(defmethod compute-offsets ((seq seq) start-pos)
  (loop for element in (elements seq)
        ;; advance offset argument for next call while looping through
        ;; the elements
        for pos = start-pos then curr-offset
        for curr-offset = (compute-offsets element pos)
        while curr-offset
        finally (return curr-offset)))

(defmethod compute-offsets ((alternation alternation) start-pos)
  (loop for choice in (choices alternation)
        for old-offset = nil then curr-offset
        for curr-offset = (compute-offsets choice start-pos)
        ;; we stop immediately if two alternations don't result in the
        ;; same offset
        if (or (not curr-offset)
               (and old-offset (/= curr-offset old-offset)))
          do (return nil)
        finally (return curr-offset)))

(defmethod compute-offsets ((branch branch) start-pos)
  ;; only return offset if both alternations have equal value
  (let ((then-offset (compute-offsets (then-regex branch) start-pos)))
    (and then-offset
         (eql then-offset (compute-offsets (else-regex branch) start-pos))
         then-offset)))

(defmethod compute-offsets ((repetition repetition) start-pos)
  ;; no need to descend into the inner regex
  (with-slots ((len len)
               (minimum minimum)
               (maximum maximum))
      repetition
    (if (and len
             (eq minimum maximum))
      ;; fixed number of repetitions, so we know how to proceed
      (+ start-pos (* minimum len))
      ;; otherwise return NIL
      nil)))

(defmethod compute-offsets ((register register) start-pos)
  (compute-offsets (regex register) start-pos))
    
(defmethod compute-offsets ((standalone standalone) start-pos)
  (compute-offsets (regex standalone) start-pos))
    
(defmethod compute-offsets ((char-class char-class) start-pos)
  (1+ start-pos))
    
(defmethod compute-offsets ((everything everything) start-pos)
  (1+ start-pos))
    
(defmethod compute-offsets ((str str) start-pos)
  (setf (offset str) start-pos)
  (+ start-pos (len str)))

(defmethod compute-offsets ((back-reference back-reference) start-pos)
  ;; with enough effort we could possibly do better here, but
  ;; currently we just give up and return NIL
  (declare (ignore start-pos))
  nil)

(defmethod compute-offsets ((regex regex) start-pos)
  ;; the general case for ANCHOR, LOOKAHEAD, LOOKBEHIND, VOID, and
  ;; WORD-BOUNDARY (which all have zero-length)
  start-pos)