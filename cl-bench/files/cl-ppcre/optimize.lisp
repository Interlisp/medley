;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-PPCRE; Base: 10 -*-
;;; $Header: /usr/local/cvsrep/cl-ppcre/optimize.lisp,v 1.1.1.1 2002/12/20 10:10:44 edi Exp $

;;; This file contains optimizations which can be applied to converted
;;; parse trees.

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

(defun string-list-to-simple-string (string-list)
  (declare (optimize speed space))
  "Concatenates a list of strings to one simple-string."
  ;; note that we can't use APPLY with CONCATENATE here because of
  ;; CALL-ARGUMENTS-LIMIT
  (reduce #'(lambda (str1 str2)
              (concatenate 'simple-string str1 str2))
          string-list
          :initial-value (make-string 0)))

(defgeneric flatten (regex)
  (declare (optimize speed space))
  (:documentation "Merges adjacent sequences and alternations, i.e. it
transforms #<SEQ #<STR \"a\"> #<SEQ #<STR \"b\"> #<STR \"c\">>> to
#<SEQ #<STR \"a\"> #<STR \"b\"> #<STR \"c\">>. This is a destructive
operation on REGEX."))

(defmethod flatten ((seq seq))
  (with-slots ((elements elements))
      seq
    (setq elements
            ;; loop through all elements of the sequence
            (loop for element in elements
                  ;; flatten inner elements first
                  for flattened-element = (flatten element)
                  if (typep flattened-element 'seq)
                    ;; "splice" sequences into collected list
                    nconc (elements flattened-element)
                  else if flattened-element
                    ;; and collect other regexes as is
                    nconc (list flattened-element)))
    (if elements
      seq
      (make-instance 'void))))

(defmethod flatten ((alternation alternation))
  (with-slots ((choices choices))
      alternation
    (setq choices
            ;; loop through all choices of the alternation
            (loop for choice in choices
                  for flattened-choice = (flatten choice)
                  if (typep flattened-choice 'alternation)
                    ;; "splice" alternations into collected list
                    nconc (choices flattened-choice)
                  else
                    ;; and collect other regexes as is
                    nconc (list flattened-choice)))
    alternation))

(defmethod flatten ((branch branch))
  (with-slots ((test test)
               (then-regex then-regex)
               (else-regex else-regex))
      branch
    (setq test
            (if (numberp test)
              test
              (flatten test))
          then-regex (flatten then-regex)
          else-regex (flatten else-regex))
    branch))

(defmethod flatten ((regex regex))
  (typecase regex
    ((or repetition register lookahead lookbehind standalone)
      ;; if REGEX contains exactly one inner REGEX object flatten it
      (setf (regex regex)
              (flatten (regex regex)))
      regex)
    (otherwise
      ;; otherwise (ANCHOR, BACK-REFERENCE, CHAR-CLASS, EVERYTHING,
      ;; LOOKAHEAD, LOOKBEHIND, STR, VOID, and WORD-BOUNDARY) do
      ;; nothing
      regex)))

(defgeneric gather-strings (regex)
  (declare (optimize speed space))
  (:documentation "Collects adjacent strings or characters into one
string provided they have the same case mode. This is a destructive
operation on REGEX."))

(defmethod gather-strings ((seq seq))
  ;; note that GATHER-STRINGS is to be applied after FLATTEN, i.e. it
  ;; expects SEQ to be flattened already; in particular, SEQ cannot be
  ;; empty and cannot contain embedded SEQ objects
  (with-slots ((elements elements))
      seq
    (let ((gathered-seq
            (loop with collector and skip
                  ;; loop through all elements of SEQ
                  for element in elements
                  for old-case-mode = nil then case-mode
                  for case-mode = (case-mode element old-case-mode)
                  if (and case-mode
                          (eq case-mode old-case-mode))
                    ;; if ELEMENT is a STR and we have collected a STR
                    ;; of the same case mode in the last iteration we
                    ;; push ELEMENT onto COLLECTOR and remember the
                    ;; value of its SKIP slot
                    do (push (str element) collector)
                    ;; it suffices to remember the last SKIP slot
                    ;; because due to the way MAYBE-ACCUMULATE works
                    ;; adjacent STR objects have the same SKIP value
                    and do (setq skip (skip element))
                  else
                    if collector
                      ;; otherwise if we have collected something
                      ;; already we convert it into a STR
                      collect (make-instance 'str
                                             :skip skip
                                             :str (string-list-to-simple-string
                                                   (nreverse collector))
                                             :case-insensitive-p
                                               (eq old-case-mode
                                                   :case-insensitive))
                        into result
                    end
                    and if case-mode
                      ;; if ELEMENT is a string with a different case
                      ;; mode than the last one we have either just
                      ;; converted COLLECTOR into a STR or COLLECTOR
                      ;; is still empty; in both cases we can now
                      ;; begin to fill it anew
                      do (setq collector (list (str element)))
                      ;; and we remember the SKIP value as above
                      and do (setq skip (skip element))
                    else
                      ;; otherwise this is not a STR so we apply
                      ;; GATHER-STRINGS to it and collect it directly
                      ;; into RESULT
                      collect (gather-strings element) into result
                      ;; we also have to empty COLLECTOR here in case
                      ;; it was still filled from the last iteration
                      and do (setq collector nil)
                  finally (return (if collector
                                    ;; if COLLECTOR isn't empty we
                                    ;; have to convert it to a STR as
                                    ;; above and append it to RESULT
                                    ;; before we return it
                                    (nconc result
                                           (list
                                            (make-instance
                                             'str
                                             :skip skip
                                             :str (string-list-to-simple-string
                                                   (nreverse collector))
                                             :case-insensitive-p
                                             (eq case-mode
                                                 :case-insensitive))))
                                    ;; otherwise just return RESULT
                                    result)))))
      (cond ((rest gathered-seq)
              ;; if GATHERED-SEQ has at least two elements we set the
              ;; ELEMENTS slot of SEQ accordingly and return SEQ
              (setq elements gathered-seq)
              seq)
            (t
              ;; otherwise it suffices to return the one element of
              ;; GATHERED-SEQ, i.e. we drop the enclosing SEQ
              (car gathered-seq))))))

(defmethod gather-strings ((alternation alternation))
  ;; loop ON the choices of ALTERNATION so we can modify them directly
  (loop for choices-rest on (choices alternation)
        while choices-rest
        do (setf (car choices-rest)
                   (gather-strings (car choices-rest))))
  alternation)

(defmethod gather-strings ((branch branch))
  (with-slots ((test test)
               (then-regex then-regex)
               (else-regex else-regex))
      branch
    (setq test
            (if (numberp test)
              test
              (gather-strings test))
          then-regex (gather-strings then-regex)
          else-regex (gather-strings else-regex))
    branch))

(defmethod gather-strings ((regex regex))
  (typecase regex
    ((or repetition register lookahead lookbehind standalone)
      ;; if REGEX contains exactly one inner REGEX object apply
      ;; GATHER-STRINGS to it
      (setf (regex regex)
              (gather-strings (regex regex)))
      regex)
    (otherwise
      ;; otherwise (ANCHOR, BACK-REFERENCE, CHAR-CLASS, EVERYTHING,
      ;; LOOKAHEAD, LOOKBEHIND, STR, VOID, and WORD-BOUNDARY) do
      ;; nothing
      regex)))

;; Note that START-ANCHORED-P will be called after FLATTEN and GATHER-STRINGS.

(defgeneric start-anchored-p (regex &optional in-seq-p)
  (declare (optimize speed space))
  (:documentation "Returns T if REGEX starts with a \"real\" start
anchor, i.e. one that's not in multi-line mode, NIL otherwise. If
IN-SEQ-P is true the function will return :ZERO-LENGTH if REGEX is a
zero-length assertion."))

(defmethod start-anchored-p ((seq seq) &optional in-seq-p)
  (declare (ignore in-seq-p))
  ;; note that START-ANCHORED-P is to be applied after FLATTEN and
  ;; GATHER-STRINGS, i.e. SEQ cannot be empty and cannot contain
  ;; embedded SEQ objects
  (loop for element in (elements seq)
        for anchored-p = (start-anchored-p element t)
        ;; skip zero-length elements because they won't affect the
        ;; "anchoredness" of the sequence
        while (eq anchored-p :zero-length)
        finally (return (and anchored-p (not (eq anchored-p :zero-length))))))

(defmethod start-anchored-p ((alternation alternation) &optional in-seq-p)
  (declare (ignore in-seq-p))
  ;; clearly an alternation can only be start-anchored if all of its
  ;; choices are start-anchored
  (loop for choice in (choices alternation)
        always (start-anchored-p choice)))

(defmethod start-anchored-p ((branch branch) &optional in-seq-p)
  (declare (ignore in-seq-p))
  (and (start-anchored-p (then-regex branch))
       (start-anchored-p (else-regex branch))))

(defmethod start-anchored-p ((repetition repetition) &optional in-seq-p)
  (declare (ignore in-seq-p))
  ;; well, this wouldn't make much sense, but anyway...
  (and (plusp (minimum repetition))
       (start-anchored-p (regex repetition))))

(defmethod start-anchored-p ((register register) &optional in-seq-p)
  (declare (ignore in-seq-p))
  (start-anchored-p (regex register)))

(defmethod start-anchored-p ((standalone standalone) &optional in-seq-p)
  (declare (ignore in-seq-p))
  (start-anchored-p (regex standalone)))

(defmethod start-anchored-p ((anchor anchor) &optional in-seq-p)
  (declare (ignore in-seq-p))
  (and (startp anchor)
       (not (multi-line-p anchor))))

(defmethod start-anchored-p ((regex regex) &optional in-seq-p)
  (typecase regex
    ((or lookahead lookbehind word-boundary void)
      ;; zero-length assertions
      (if in-seq-p
        :zero-length
        nil))
    (otherwise
      ;; BACK-REFERENCE, CHAR-CLASS, EVERYTHING, and STR
      nil)))

;; Note that END-STRING-AUX will be called after FLATTEN and GATHER-STRINGS.

(defgeneric end-string-aux (regex &optional old-case-insensitive-p)
  (declare (optimize speed space))
  (:documentation "Returns the constant string (if it exists) REGEX
ends with wrapped into a STR object, otherwise NIL.
OLD-CASE-INSENSITIVE-P is the CASE-INSENSITIVE-P slot of the last STR
collected or :VOID if no STR has been collected yet. (This is a helper
function called by END-STRIN.)"))

(defmethod end-string-aux ((str str)
                           &optional (old-case-insensitive-p :void))
  (declare (special last-str))
  (cond ((and (not (skip str))          ; avoid constituents of STARTS-WITH
              ;; only use STR if nothing has been collected yet or if
              ;; the collected string has the same value for
              ;; CASE-INSENSITIVE-P
              (or (eq old-case-insensitive-p :void)
                  (eq (case-insensitive-p str) old-case-insensitive-p)))
          (setf last-str str
                ;; set the SKIP property of this STR
                (skip str) t)
          str)
        (t nil)))

(defmethod end-string-aux ((seq seq)
                           &optional (old-case-insensitive-p :void))
  (declare (special continuep))
  (let* ((collected-strings
           (nreverse
            ;; loop through all elements in reverse order
            (loop for element in (reverse (elements seq))
                  ;; remember the case-(in)sensitivity of the last
                  ;; relevant STR object
                  for loop-old-case-insensitive-p = old-case-insensitive-p
                    then (if skip
                           loop-old-case-insensitive-p
                           (case-insensitive-p element-end))
                  ;; the end-string of the current element
                  for element-end = (end-string-aux element
                                                    loop-old-case-insensitive-p)
                  ;; whether we encountered a zero-length element
                  for skip = (if element-end
                               (zerop (len element-end))
                               nil)
                  ;; set CONTINUEP to NIL if we have to stop
                  ;; collecting to alert END-STRING-AUX methods on
                  ;; enclosing SEQ objects
                  unless element-end
                    do (setq continuep nil)
                  ;; end loop if we neither got a STR nor a
                  ;; zero-length element
                  while element-end
                  ;; only collect if not zero-length
                  unless skip
                    collect element-end
                  ;; stop collecting if END-STRING-AUX on inner SEQ
                  ;; has said so
                  while continuep)))
         (concatenated-string
           (string-list-to-simple-string (mapcar #'str collected-strings))))
    (if (zerop (length concatenated-string))
      ;; don't bother to return zero-length strings
      nil
      (make-instance 'str
                     :str concatenated-string
                     :case-insensitive-p (case-insensitive-p
                                          (first collected-strings))))))

(defmethod end-string-aux ((register register)
                           &optional (old-case-insensitive-p :void))
  (end-string-aux (regex register) old-case-insensitive-p))
    
(defmethod end-string-aux ((standalone standalone)
                           &optional (old-case-insensitive-p :void))
  (end-string-aux (regex standalone) old-case-insensitive-p))
    
(defmethod end-string-aux ((regex regex)
                           &optional (old-case-insensitive-p :void))
  (declare (special last-str end-anchored-p continuep))
  (typecase regex
    ((or anchor lookahead lookbehind word-boundary void)
      ;; a zero-length REGEX object - for the sake of END-STRING-AUX
      ;; this is a zero-length string
      (when (and (typep regex 'anchor)
                 (not (startp regex))
                 (or (no-newline-p regex)
                     (not (multi-line-p regex)))
                 (eq old-case-insensitive-p :void))
        ;; if this is a "real" end-anchor and we haven't collected
        ;; anything so far we can set END-ANCHORED-P (where 1 or 0
        ;; indicate whether we accept a #\Newline at the end or not)
        (setq end-anchored-p (if (no-newline-p regex) 0 1)))
      (make-instance 'str
                     :str ""
                     :case-insensitive-p :void))
    (otherwise
      ;; (ALTERNATION, BACK-REFERENCE, BRANCH, CHAR-CLASS, EVERYTHING,
      ;; REPETITION)
      nil)))

(defmethod end-string ((regex regex))
  (declare (optimize speed space))
  "Returns the constant string (if it exists) REGEX ends with wrapped
into a STR object, otherwise NIL."
  (declare (special end-string-offset))
  ;; LAST-STR points to the last STR object (seen from the end) that's
  ;; part of END-STRING; CONTINUEP is set to T if we stop collecting
  ;; in the middle of a SEQ
  (let ((continuep t)
        last-str)
    (declare (special continuep last-str))
    (prog1
      (end-string-aux regex)
      (when last-str
        ;; if we've found something set the START-OF-END-STRING-P of
        ;; the leftmost STR collected accordingly and remember the
        ;; OFFSET of this STR (in a special variable provided by the
        ;; caller of this function)
        (setf (start-of-end-string-p last-str) t
              end-string-offset (offset last-str))))))

(defgeneric compute-min-rest (regex current-min-rest)
  (declare (optimize speed space))
  (:documentation "Returns the minimal length of REGEX plus
CURRENT-MIN-REST. This is similar to REGEX-MIN-LENGTH except that it
recurses down into REGEX and sets the MIN-REST slots of REPETITION
objects."))

(defmethod compute-min-rest ((seq seq) current-min-rest)
  (loop for element in (reverse (elements seq))
        for last-min-rest = current-min-rest then this-min-rest
        for this-min-rest = (compute-min-rest element last-min-rest)
        finally (return this-min-rest)))
    
(defmethod compute-min-rest ((alternation alternation) current-min-rest)
  (loop for choice in (choices alternation)
        minimize (compute-min-rest choice current-min-rest)))

(defmethod compute-min-rest ((branch branch) current-min-rest)
  (min (compute-min-rest (then-regex branch) current-min-rest)
       (compute-min-rest (else-regex branch) current-min-rest)))

(defmethod compute-min-rest ((str str) current-min-rest)
  (+ current-min-rest (len str)))
    
(defmethod compute-min-rest ((repetition repetition) current-min-rest)
  (setf (min-rest repetition) current-min-rest)
  (compute-min-rest (regex repetition) current-min-rest)
  (+ current-min-rest (* (minimum repetition) (min-len repetition))))

(defmethod compute-min-rest ((register register) current-min-rest)
  (compute-min-rest (regex register) current-min-rest))
    
(defmethod compute-min-rest ((standalone standalone) current-min-rest)
  (declare (ignore current-min-rest))
  (compute-min-rest (regex standalone) 0))
    
(defmethod compute-min-rest ((lookahead lookahead) current-min-rest)
  (compute-min-rest (regex lookahead) current-min-rest)
  current-min-rest)
    
(defmethod compute-min-rest ((lookbehind lookbehind) current-min-rest)
  (compute-min-rest (regex lookbehind) (+ current-min-rest (len lookbehind)))
  current-min-rest)
    
(defmethod compute-min-rest ((regex regex) current-min-rest)
  (typecase regex
    ((or char-class everything)
      (1+ current-min-rest))
    (otherwise
      ;; zero min-len and no embedded regexes (ANCHOR,
      ;; BACK-REFERENCE, VOID, and WORD-BOUNDARY)
      current-min-rest))) 