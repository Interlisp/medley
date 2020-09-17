;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-PPCRE; Base: 10 -*-
;;; $Header: /usr/local/cvsrep/cl-ppcre/convert.lisp,v 1.1.1.1 2002/12/20 10:10:44 edi Exp $

;;; Here the parse tree is converted into its internal representation
;;; using REGEX objects.  At the same time some optimizations are
;;; already applied.

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

(defun pre-flatten (list token)
  (declare (optimize speed space))
  "Recursively merges nested sublists of LIST which start with TOKEN
directly into LIST. This is a destructive operation on LIST."
  (cond ((null list) nil)
        ((and (consp (first list))
              (eq token (first (first list))))
          (nconc (pre-flatten (rest (first list)) token)
                 (pre-flatten (rest list) token)))
        (t
          (setf (rest list)
                  (pre-flatten (rest list) token))
          list)))
          

;;; The flags that represent the "ism" modifiers are always kept
;;; together in a three-element list. We use the following macros to
;;; access individual elements.

(defmacro case-insensitive-mode-p (flags)
  "Accessor macro to extract the first flag out of a three-element flag list."
  `(first ,flags))

(defmacro multi-line-mode-p (flags)
  "Accessor macro to extract the second flag out of a three-element flag list."
  `(second ,flags))

(defmacro single-line-mode-p (flags)
  "Accessor macro to extract the third flag out of a three-element flag list."
  `(third ,flags))

(defun set-flag (token)
  (declare (optimize speed space))
  (declare (special flags))
  "Reads a flag token and sets or unsets the corresponding entry in
the special FLAGS list."
  (case token
    ((:case-insensitive-p)
      (setf (case-insensitive-mode-p flags) t))
    ((:case-sensitive-p)
      (setf (case-insensitive-mode-p flags) nil))
    ((:multi-line-mode-p)
      (setf (multi-line-mode-p flags) t))
    ((:not-multi-line-mode-p)
      (setf (multi-line-mode-p flags) nil))
    ((:single-line-mode-p)
      (setf (single-line-mode-p flags) t))
    ((:not-single-line-mode-p)
      (setf (single-line-mode-p flags) nil))
    (otherwise
      (error "Unknown flag token ~A" token))))

(defun add-range-to-hash (hash from to)
  (declare (optimize speed space))
  (declare (special flags))
  "Adds all characters from character FROM to character TO (inclusive)
to the char class hash HASH. Does the right thing with respect to
case-(in)sensitivity as specified by the special variable FLAGS."
  (let ((from-code (char-code from))
        (to-code (char-code to)))
    (when (> from-code to-code)
      (error "Invalid range from ~A to ~A in char-class" from to))
    (if (case-insensitive-mode-p flags)
      (loop for code from from-code to to-code
            for chr = (code-char code)
            do (setf (gethash (char-upcase chr) hash) 1
                     (gethash (char-downcase chr) hash) 1))
      (loop for code from from-code to to-code
            do (setf (gethash (code-char code) hash) 1)))
    hash))

(defun convert-char-class-to-hash (list)
  (declare (optimize speed space))
  "Combines all items in LIST into one char class hash and returns it.
Items can be single characters, character ranges like (:RANGE #\A #\E),
or special character classes like :DIGIT-CLASS. Does the right thing
with respect to case-(in)sensitivity as specified by the special
variable FLAGS."
  (loop with hash = (make-hash-table)
        for item in list
        if (characterp item)
          ;; treat a single character C like a range (:RANGE C C)
          do (add-range-to-hash hash item item)
        else if (symbolp item)
          ;; special character classes
          do (case item
               ((:digit-class)
                 (merge-hash hash +digit-hash+))
               ((:non-digit-class)
                 (merge-inverted-hash hash +digit-hash+))
               ((:whitespace-char-class)
                 (merge-hash hash +whitespace-char-hash+))
               ((:non-whitespace-char-class)
                 (merge-inverted-hash hash +whitespace-char-hash+))
               ((:word-char-class)
                 (merge-hash hash +word-char-hash+))
               ((:non-word-char-class)
                 (merge-inverted-hash hash +word-char-hash+))
               (otherwise
                 (error "Unknown symbol ~A in character class" item)))
        else if (and (consp item)
                     (eq (car item) :range))
          ;; proper ranges
          do (add-range-to-hash hash
                                (second item)
                                (third item))
        else do (error "Unknown item ~A in char-class list" item)
        finally (return hash)))

(defun maybe-split-repetition (regex
                               greedyp
                               minimum
                               maximum
                               min-len
                               length
                               reg-seen)
  (declare (optimize speed space))
  "Splits a REPETITION object into a constant and a varying part if
applicable, i.e. something like
  a{3,} -> a{3}a*
The arguments to this function correspond to the REPETITION slots of
the same name."
  ;; note the usage of COPY-REGEX here; we can't use the same REGEX
  ;; object in both REPETITIONS because they will have different
  ;; offsets
  (when maximum
    (when (zerop maximum)
      ;; trivial case: don't repeat at all
      (return-from maybe-split-repetition
        (make-instance 'void)))
    (when (= 1 minimum maximum)
      ;; another trivial case: "repeat" exactly once
      (return-from maybe-split-repetition
        regex)))
  ;; first set up the constant part of the repetition
  ;; maybe that's all we need
  (let ((constant-repetition (if (plusp minimum)
                               (make-instance 'repetition
                                              :regex (copy-regex regex)
                                              :greedyp greedyp
                                              :minimum minimum
                                              :maximum minimum
                                              :min-len min-len
                                              :len length
                                              :contains-register-p reg-seen)
                               nil)))
    (when (and maximum
               (= maximum minimum))
      (return-from maybe-split-repetition
        ;; no varying part needed because min = max
        constant-repetition))
    ;; now construct the varying part
    (let* ((new-maximum (if maximum (- maximum minimum) nil))
           (varying-repetition
             (make-instance 'repetition
                            :regex regex
                            :greedyp greedyp
                            :minimum 0
                            :maximum new-maximum
                            :min-len min-len
                            :len length
                            :contains-register-p reg-seen)))
      (cond ((zerop minimum)
              ;; min = 0, no constant part needed
              varying-repetition)
            ((= 1 minimum)
              ;; min = 1, constant part needs no REPETITION wrapped around
              (make-instance 'seq
                             :elements (list (copy-regex regex)
                                             varying-repetition)))
            (t
              ;; general case
              (make-instance 'seq
                             :elements (list constant-repetition
                                             varying-repetition)))))))

;; During the conversion of the parse tree we keep track of the start
;; of the parse tree in the special variable STARTS-WITH which'll
;; either hold a STR object or an EVERYTHING object. The latter is the
;; case if the regex starts with ".*" which implicitely anchors the
;; regex at the start (perhaps modulo #\Newline).

(defmethod maybe-accumulate ((str str))
  (declare (optimize speed space))
  (declare (special accumulate-start-p starts-with))
  "Accumulate STR into the special variable STARTS-WITH if
ACCUMULATE-START-P (also special) is true and STARTS-WITH is either
NIL or a STR object of the same case mode. Always returns NIL."
  (when accumulate-start-p
    (etypecase starts-with
      (str
        ;; STARTS-WITH already holds a STR, so we check if we can
        ;; concatenate
        (if (eq (case-insensitive-p starts-with)
                (case-insensitive-p str))
          ;; we modify STARTS-WITH in place
          (setf (len starts-with)
                  (+ (len starts-with) (len str))
                (str starts-with)
                  (concatenate 'string (str starts-with) (str str))
                ;; STR objects that are parts of STARTS-WITH always
                ;; have their SKIP slot set to true because the SCAN
                ;; function will take care of them, i.e. the matcher
                ;; can ignore them
                (skip str) t)
          (setq accumulate-start-p nil)))
      (null
        ;; STARTS-WITH is still empty, so we create a new STR object
        (setf starts-with
                (make-instance 'str
                               :str (str str)
                               :case-insensitive-p (case-insensitive-p str))
              ;; see remark about SKIP above
              (skip str) t))
      (everything
        ;; STARTS-WITH already holds an EVERYTHING object - we can't
        ;; concatenate
        (setq accumulate-start-p nil))))
  nil)

(defun convert-aux (parse-tree)
  (declare (optimize speed space))
  (declare (special flags reg-num accumulate-start-p starts-with max-back-ref))
  "Converts the parse tree PARSE-TREE into a REGEX object and returns it.

Will also
  - split and optimize repetitions,
  - accumulate strings or EVERYTHING objects into the special variable
    STARTS-WITH,
  - keep track of all registers seen in the special variable REG-NUM,
  - keep track of the highest backreference seen in the special
    variable MAX-BACK-REF,
  - maintain and adher to the currently applicable modifiers in the special
    variable FLAGS, and
  - maybe even wash your car..."
  (cond ((consp parse-tree)
          (case (first parse-tree)
            ;; (:SEQUENCE {<regex>}*)
            ((:sequence)
              (make-instance 'seq
                             :elements (mapcar #'convert-aux
                                               (pre-flatten (rest parse-tree)
                                                            :sequence))))
            ;; (:GROUP {<regex>}*)
            ;; this is a syntactical construct equivalent to :SEQUENCE
            ;; intended to keep the effect of modifiers local
            ((:group)
              ;; make a local copy of FLAGS and shadow the global
              ;; value while we descend into the enclosed regexes
              (let ((flags (copy-list flags)))
                (declare (special flags))
                (make-instance 'seq
                               :elements (mapcar #'convert-aux
                                                 (pre-flatten (rest parse-tree)
                                                              :sequence)))))
            ;; (:ALTERNATION {<regex>}*)
            ((:alternation)
              ;; we must stop accumulating objects into STARTS-WITH
              ;; once we reach an alternation
              (setq accumulate-start-p nil)
              (make-instance 'alternation
                             :choices (mapcar #'convert-aux
                                              (pre-flatten (rest parse-tree)
                                                           :alternation))))
            ;; (:BRANCH <test> <regex>)
            ;; <test> must be look-ahead, look-behind or number;
            ;; if <regex> is an alternation it must have one or two
            ;; choices
            ((:branch)
              (setq accumulate-start-p nil)
              (let* ((test-candidate (second parse-tree))
                     (test (cond ((numberp test-candidate)
                                   (when (zerop test-candidate)
                                     (error "Register 0 doesn't exist: ~S"
                                            parse-tree))
                                   (1- test-candidate))
                                 (t (convert-aux test-candidate))))
                     (alternations (convert-aux (third parse-tree))))
                (when (and (not (numberp test))
                           (not (typep test 'lookahead))
                           (not (typep test 'lookbehind)))
                  (error "Branch test must be look-ahead, look-behind or number: ~S"
                         parse-tree))
                (typecase alternations
                  (alternation
                    (case (length (choices alternations))
                      ((0)
                        (error "No choices in branch: ~S" parse-tree))
                      ((1)
                        (make-instance 'branch
                                       :test test
                                       :then-regex (first
                                                    (choices alternations))))
                      ((2)
                        (make-instance 'branch
                                       :test test
                                       :then-regex (first
                                                    (choices alternations))
                                       :else-regex (second
                                                    (choices alternations))))
                      (otherwise
                        (error "Too much choices in branch: ~S"
                               parse-tree))))
                  (otherwise
                    (make-instance 'branch
                                   :test test
                                   :then-regex alternations)))))
            ;; (:POSITIVE-LOOKAHEAD|:NEGATIVE-LOOKAHEAD <regex>)
            ((:positive-lookahead :negative-lookahead)
              ;; keep the effect of modifiers local to the enclosed
              ;; regex and temporarily stop accumulating into
              ;; STARTS-WITH
              (let ((flags (copy-list flags))
                    (accumulate-start-p nil))
                (declare (special flags accumulate-start-p))
                (make-instance 'lookahead
                               :regex (convert-aux (second parse-tree))
                               :positivep (eq (first parse-tree)
                                              :positive-lookahead))))
            ;; (:POSITIVE-LOOKBEHIND|:NEGATIVE-LOOKBEHIND <regex>)
            ((:positive-lookbehind :negative-lookbehind)
              ;; keep the effect of modifiers local to the enclosed
              ;; regex and temporarily stop accumulating into
              ;; STARTS-WITH
              (let* ((flags (copy-list flags))
                     (accumulate-start-p nil)
                     (regex (convert-aux (second parse-tree)))
                     (len (regex-length regex)))
                (declare (special flags accumulate-start-p))
                ;; lookbehind assertions must be of fixed length
                (unless len
                  (error "Variable length look-behind not implemented (yet): ~S"
                         parse-tree))
                (make-instance 'lookbehind
                               :regex regex
                               :positivep (eq (first parse-tree)
                                              :positive-lookbehind)
                               :len len)))
            ;; (:GREEDY-REPETITION|:NON-GREEDY-REPETITION <min> <max> <regex>)
            ((:greedy-repetition :non-greedy-repetition)
              ;; remember the value of ACCUMULATE-START-P upon entering
              (let ((local-accumulate-start-p accumulate-start-p))
                (let ((minimum (second parse-tree))
                      (maximum (third parse-tree)))
                  (unless (and maximum
                               (= 1 minimum maximum))
                    ;; set ACCUMULATE-START-P to NIL for the rest of
                    ;; the conversion because we can't continue to
                    ;; accumulate inside as well as after a proper
                    ;; repetition
                    (setq accumulate-start-p nil))
                  (let* (reg-seen
                         (regex (convert-aux (fourth parse-tree)))
                         (min-len (regex-min-length regex))
                         (greedyp (eq (first parse-tree) :greedy-repetition))
                         (length (regex-length regex)))
                    ;; note that this declaration already applies to
                    ;; the call to CONVERT-AUX above
                    (declare (special reg-seen))
                    (when (and local-accumulate-start-p
                               (not starts-with)
                               (zerop minimum)
                               (not maximum))
                      ;; if this repetition is (equivalent to) ".*"
                      ;; and if we're at the start of the regex we
                      ;; remember it for ADVANCE-FN (see the SCAN
                      ;; function)
                      (setq starts-with (everythingp regex)))
                    (if (or (not reg-seen)
                            (not greedyp)
                            (not length)
                            (zerop length)
                            (and maximum (= minimum maximum)))
                      ;; the repetition doesn't enclose a register, or
                      ;; it's not greedy, or we can't determine it's
                      ;; (inner) length, or the length is zero, or the
                      ;; number of repetitions is fixed; in all of
                      ;; these cases we don't bother to optimize
                      (maybe-split-repetition regex
                                              greedyp
                                              minimum
                                              maximum
                                              min-len
                                              length
                                              reg-seen)
                      ;; otherwise we make a transformation that looks
                      ;; roughly like one of
                      ;;   <regex>* -> (?:<regex'>*<regex>)?
                      ;;   <regex>+ -> <regex'>*<regex>
                      ;; where the trick is that as much as possible
                      ;; registers from <regex> are removed in
                      ;; <regex'>
                      (let* (reg-seen   ; new instance for REMOVE-REGISTERS
                             (remove-registers-p t)
                             (inner-regex (remove-registers regex))
                             (inner-repetition
                               ;; this is the "<regex'>" part
                               (maybe-split-repetition inner-regex
                                                       ;; always greedy
                                                       t
                                                       ;; reduce minimum by 1
                                                       ;; unless it's already 0
                                                       (if (zerop minimum)
                                                         0
                                                         (1- minimum))
                                                       ;; reduce maximum by 1
                                                       ;; unless it's NIL
                                                       (and maximum
                                                            (1- maximum))
                                                       min-len
                                                       length
                                                       reg-seen))
                             (inner-seq
                               ;; this is the "<regex'>*<regex>" part
                               (make-instance 'seq
                                              :elements (list inner-repetition
                                                              regex))))
                        ;; note that this declaration already applies
                        ;; to the call to REMOVE-REGISTERS above
                        (declare (special remove-registers-p reg-seen))
                        ;; wrap INNER-SEQ with a greedy
                        ;; {0,1}-repetition (i.e. "?") if necessary
                        (if (plusp minimum)
                          inner-seq
                          (maybe-split-repetition inner-seq
                                                  t
                                                  0
                                                  1
                                                  min-len
                                                  nil
                                                  t))))))))
            ;; (:REGISTER <regex>)
            ((:register)
              ;; keep the effect of modifiers local to the enclosed
              ;; regex; also, assign the current value of REG-NUM to
              ;; the corresponding slot of the REGISTER object and
              ;; increase this counter afterwards
              (let ((flags (copy-list flags))
                    (stored-reg-num reg-num))
                (declare (special flags reg-seen))
                (setq reg-seen t)
                (incf reg-num)
                (make-instance 'register
                               :regex (convert-aux (second parse-tree))
                               :num stored-reg-num)))
            ;; (:STANDALONE <regex>)
            ((:standalone)
              ;; keep the effect of modifiers local to the enclosed
              ;; regex
              (let ((flags (copy-list flags)))
                (declare (special flags))
                (make-instance 'standalone
                               :regex (convert-aux (second parse-tree)))))
            ;; (:BACK-REFERENCE <number>)
            ((:back-reference)
              (let ((backref-number (second parse-tree)))
                (when (or (not (typep backref-number 'fixnum))
                          (<= backref-number 0))
                  (error "Illegal back-reference: ~S" parse-tree))
                ;; stop accumulating into STARTS-WITH and increase
                ;; MAX-BACK-REF if necessary
                (setq accumulate-start-p nil
                      max-back-ref (max max-back-ref
                                        backref-number))
                (make-instance 'back-reference
                               ;; we start counting from 0 internally
                               :num (1- backref-number)
                               :case-insensitive-p (case-insensitive-mode-p
                                                    flags))))
            ;; (:CHAR-CLASS|:INVERTED-CHAR-CLASS {<item>}*)
            ;; where item is one of
            ;;   - a character
            ;;   - a character range: (:RANGE <char1> <char2>)
            ;;   - a special char class symbol like :DIGIT-CHAR-CLASS
            ((:char-class :inverted-char-class)
              ;; first create the hash-table and some auxiliary values
              (let* ((item-list (rest parse-tree))
                     (hash (convert-char-class-to-hash item-list))
                     (invertedp (eq (first parse-tree) :inverted-char-class))
                     (count (hash-table-count hash))
                     ;; collect the hash-table keys into a list if
                     ;; COUNT is smaller than 3
                     (hash-keys (if (<= count 2)
                                  (loop for chr being the hash-keys of hash
                                        collect chr)
                                  nil))
                     (word-char-class-p nil))
                (when (every (lambda (item) (eq item :word-char-class))
                             item-list)
                  ;; treat "[\\w]" like "\\w"
                  (setq word-char-class-p t))
                (when (every (lambda (item) (eq item :non-word-char-class))
                             item-list)
                  ;; treat "[\\W]" like "\\W"
                  (setq word-char-class-p t)
                  (setq invertedp (not invertedp)))
                (cond ((and (not invertedp)
                            (= count 1))
                        ;; convert one-element hash table into a STR
                        ;; object and try to accumulate into
                        ;; STARTS-WITH
                        (let ((str (make-instance 'str
                                                  :str (string
                                                        (first hash-keys))
                                                  :case-insensitive-p nil)))
                          (maybe-accumulate str)
                          str))
                      ((and (not invertedp)
                            (= count 2)
                            (char-equal (first hash-keys) (second hash-keys)))
                        ;; convert two-element hash table into a
                        ;; case-insensitive STR object and try to
                        ;; accumulate into STARTS-WITH if the two
                        ;; characters are CHAR-EQUAL
                        (let ((str (make-instance 'str
                                                  :str (string
                                                        (first hash-keys))
                                                  :case-insensitive-p t)))
                          (maybe-accumulate str)
                          str))
                      (t
                        ;; the general case; stop accumulating into STARTS-WITH
                        (setq accumulate-start-p nil)
                        (make-instance 'char-class
                                       :hash hash
                                       :case-insensitive-p
                                         (case-insensitive-mode-p flags)
                                       :invertedp invertedp
                                       :word-char-class-p word-char-class-p)))))
            ;; (:FLAGS {<flag>}*)
            ;; where flag is a modifier symbol like :CASE-INSENSITIVE-P
            ((:flags)
              ;; set/unset the flags corresponding to the symbols
              ;; following :FLAGS
              (mapcar #'set-flag (rest parse-tree))
              ;; we're only interested in the side effect of
              ;; setting/unsetting the flags and turn this syntactical
              ;; construct into a VOID object which'll be optimized
              ;; away when creating the matcher
              (make-instance 'void))
            (otherwise
              (error "Unknown token ~A in parse-tree" (first parse-tree)))))
        ((or (characterp parse-tree) (stringp parse-tree))
          ;; turn characters or strings into STR objects and try to
          ;; accumulate into STARTS-WITH
          (let ((str (make-instance 'str
                                    :str (string parse-tree)
                                    :case-insensitive-p
                                      (case-insensitive-mode-p flags))))
            (maybe-accumulate str)
            str))
        (t
          ;; and now for the tokens which are symbols
          (case parse-tree
            ((:void)
              (make-instance 'void))
            ((:word-boundary)
              (make-instance 'word-boundary :negatedp nil))             
            ((:non-word-boundary)
              (make-instance 'word-boundary :negatedp t))             
            ;; the special character classes
            ((:digit-class
              :non-digit-class
              :word-char-class
              :non-word-char-class
              :whitespace-char-class
              :non-whitespace-char-class)
              ;; stop accumulating into STARTS-WITH
              (setq accumulate-start-p nil)
              (make-instance 'char-class
                             ;; use the constants defined in util.lisp
                             :hash (case parse-tree
                                     ((:digit-class
                                       :non-digit-class)
                                       +digit-hash+)
                                     ((:word-char-class
                                       :non-word-char-class)
                                       +word-char-hash+)
                                     ((:whitespace-char-class
                                       :non-whitespace-char-class)
                                       +whitespace-char-hash+))
                             ;; this value doesn't really matter but
                             ;; NIL should result in slightly faster
                             ;; matchers
                             :case-insensitive-p nil
                             :invertedp (member parse-tree
                                                '(:non-digit-class
                                                  :non-word-char-class
                                                  :non-whitespace-char-class)
                                                :test #'eq)
                             :word-char-class-p (member parse-tree
                                                        '(:word-char-class
                                                          :non-word-char-class)
                                                        :test #'eq)))
            ((:start-anchor             ; Perl's "^"
              :end-anchor               ; Perl's "$"
              :modeless-end-anchor-no-newline
                                        ; Perl's "\z"
              :modeless-start-anchor    ; Perl's "\A"
              :modeless-end-anchor)     ; Perl's "\Z"
              (make-instance 'anchor
                             :startp (member parse-tree
                                             '(:start-anchor
                                               :modeless-start-anchor)
                                             :test #'eq)
                             ;; set this value according to the
                             ;; current settings of FLAGS (unless it's
                             ;; a modeless anchor)
                             :multi-line-p
                               (and (multi-line-mode-p flags)
                                    (not (member parse-tree
                                                 '(:modeless-start-anchor
                                                   :modeless-end-anchor
                                                   :modeless-end-anchor-no-newline)
                                                 :test #'eq)))
                             :no-newline-p
                               (eq parse-tree
                                   :modeless-end-anchor-no-newline)))
            ((:everything)
              ;; stop accumulating into STARTS-WITHS
              (setq accumulate-start-p nil)
              (make-instance 'everything
                             :single-line-p (single-line-mode-p flags)))
            ;; special tokens corresponding to Perl's "ism" modifiers
            ((:case-insensitive-p
              :case-sensitive-p
              :multi-line-mode-p
              :not-multi-line-mode-p
              :single-line-mode-p
              :not-single-line-mode-p)
              ;; we're only interested in the side effect of
              ;; setting/unsetting the flags and turn these tokens
              ;; into VOID objects which'll be optimized away when
              ;; creating the matcher
              (set-flag parse-tree)
              (make-instance 'void))
            (otherwise
              (error "Unknown token ~A in parse-tree" parse-tree))))))

(defun convert (parse-tree)
  (declare (optimize speed space))
  "Converts the parse tree PARSE-TREE into an equivalent REGEX object
and returns three values: the REGEX object, the number of registers
seen and an object the regex starts with which is either a STR object
or an EVERYTHING object (if the regex starts with something like
\".*\") or NIL."
  ;; this function basically just initializes the special variables
  ;; and then calls CONVERT-AUX to do all the work
  (let* ((flags (list nil nil nil))
         (reg-num 0)
         (accumulate-start-p t)
         starts-with
         (max-back-ref 0)
         (converted-parse-tree (convert-aux parse-tree)))
    (declare (special flags reg-num accumulate-start-p starts-with max-back-ref))
    ;; make sure we don't reference registers which aren't there
    (if (> max-back-ref reg-num)
      (error "Backreference to register ~A which has not been defined" max-back-ref))
    (values converted-parse-tree reg-num starts-with)))
