;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-PPCRE; Base: 10 -*-
;;; $Header: /usr/local/cvsrep/cl-ppcre/lexer.lisp,v 1.1.1.1 2002/12/20 10:10:44 edi Exp $

;;; The lexer's responsibility is to convert the regex string into a
;;; sequence of tokens which are in turn consumed by the parser.
;;;
;;; The lexer is aware of Perl's 'extended mode' and it also 'knows'
;;; (with a little help from the parser) how many register groups it
;;; has opened so far. (The latter is necessary for interpreting
;;; strings like "\\10" correctly.)

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

(defun fix-pos (pos)
  (declare (optimize speed space))
  (declare (type fixnum pos))
  "Will fix positions reported by error messages so that they match the
original regex string and not the one prefixed by modifiers like (?i)."
  (- pos *error-msg-offset*))

(defun map-char-to-special-char-class (chr)
  (declare (optimize speed space))
  "Maps escaped characters like \"\\d\" to the tokens which represent
their associated character classes."
  (case chr
    ((#\d)
      :digit-class)
    ((#\D)
      :non-digit-class)
    ((#\w)
      :word-char-class)
    ((#\W)
      :non-word-char-class)
    ((#\s)
      :whitespace-char-class)
    ((#\S)
      :non-whitespace-char-class)))

(defclass lexer ()
  ((str :initarg :str
        :reader str
        :type string
        :documentation  "The regex string which is lexed by this lexer.")
   (len :reader len
        :type fixnum
        :documentation "The length of the regex string.")
   (reg :initform 0
        :accessor reg
        :type fixnum
        :documentation "The number of register groups opened so far.")
   (pos :initform 0
        :accessor pos
        :type fixnum
        :documentation "The current position within the regex string,
i.e. the next character that will be read.")
   ;; looks like we actually don't need a stack here,
   ;; remembering one position would suffice - but hey...
   (last-pos :initform nil
             :accessor last-pos
             :documentation "A stack which holds older positions
the lexer might wish to get back to."))
  (:documentation "LEXER objects are used to hold the regex string which is
currently lexed and to keep track of the lexer's state."))

(defmethod initialize-instance :after ((lexer lexer) &rest init-args)
  (declare (optimize speed space))
  (declare (ignore init-args))
  "Computes the length of the regex string after initializing the lexer object."
  (setf (slot-value lexer 'len) (length (str lexer))))

(defmethod end-of-string-p ((lexer lexer))
  (declare (optimize speed space))
  "Tests whether we're at the end of the regex string."
  (<= (len lexer) (pos lexer)))

(defmethod next-char-non-extended ((lexer lexer))
  (declare (optimize speed space))
  "Returns the next character which is to be examined and updates the
POS slot. Does not respect extended mode."
  (with-accessors ((pos pos) (str str))
      lexer
    (if (end-of-string-p lexer)
      nil
      (prog1
        (char str pos)
        (incf pos)))))

(defmethod next-char ((lexer lexer))
  (declare (optimize speed space))
  (declare (special extended-mode-p))
  "Returns the next character which is to be examined and updates the
POS slot. Respects extended mode, i.e.  whitespace, comments, and also
nested comments are skipped if applicable."
  (with-slots ((pos pos))
      lexer
    (let ((next-char (next-char-non-extended lexer))
          last-loop-pos)
      (loop
        ;; remember where we started
        (setq last-loop-pos pos)
        ;; first we look for nested comments like (?#foo)
        (when (and next-char
                   (char= next-char #\()
                   (looking-at-p lexer #\?))
          (incf pos)
          (cond ((looking-at-p lexer #\#)
                  ;; must be a nested comment - so we have to search
                  ;; for the closing parenthesis
                  (let ((error-pos (- pos 2)))
                    (unless
                        ;; loop 'til ')' or end of regex string and
                        ;; return NIL if ')' wasn't encountered
                        (loop for skip-char = next-char
                                  then (next-char-non-extended lexer)
                              while (and skip-char
                                         (char/= skip-char #\)))
                              finally (return skip-char))
                      (error "Comment group started at position ~A not closed"
                             (fix-pos error-pos))))
                  (setq next-char (next-char-non-extended lexer)))
                (t
                  ;; undo effect of previous INCF if we didn't see a #
                  (decf pos))))
        (when extended-mode-p
          ;; now - if we're in extended mode - we skip whitespace and
          ;; comments; repeat the following loop while we look at
          ;; whitespace or #\#
          (loop while (and next-char
                           (or (char= next-char #\#)
                               (whitespacep next-char)))
                do (setq next-char
                           (if (char= next-char #\#)
                             ;; if we saw a comment marker skip until
                             ;; we're behind #\Newline...
                             (loop for skip-char = next-char
                                     then (next-char-non-extended lexer)
                                   while (and skip-char
                                              (char/= skip-char #\Newline))
                                   finally (return (next-char-non-extended lexer)))
                             ;; ...otherwise (whitespace) skip until
                             ;; we see the next non-whitespace
                             ;; character
                             (loop for skip-char = next-char
                                     then (next-char-non-extended lexer)
                                   while (and skip-char
                                              (whitespacep skip-char))
                                   finally (return skip-char))))))
        ;; if the position has moved we have to repeat our tests
        ;; because of cases like /^a (?#xxx) (?#yyy) {3}c/x which
        ;; would be equivalent to /^a{3}c/ in Perl
        (unless (> pos last-loop-pos)
          (return next-char))))))

(defmethod looking-at-p ((lexer lexer) chr)
  (declare (optimize speed space))
  "Tests whether the next character the lexer would see is CHR.
Does not respect extended mode."
  (and (not (end-of-string-p lexer))
       (char= (char (str lexer) (pos lexer))
              chr)))

(defmethod fail ((lexer lexer))
  (declare (optimize speed space))
  "Moves (POS LEXER) back to the last position stored in (LAST-POS LEXER)
and pops the LAST-POS stack."
  (with-accessors ((pos pos) (last-pos last-pos))
      lexer
    (unless last-pos
      (error "LAST-POS stack of LEXER ~A is empty" lexer))
    (setq pos (pop last-pos))
    nil))

(defmethod get-number ((lexer lexer) &key (radix 10) max-length no-whitespace-p)
  (declare (optimize speed space))
  "Read and consume the number the lexer is currently looking at and
return it. Returns NIL if no number could be identified.
RADIX is used as in PARSE-INTEGER. If MAX-LENGTH is not NIL we'll read
at most the next MAX-LENGTH characters. If NO-WHITESPACE-P is not NIL
we don't tolerate whitespace in front of the number."
  (when (and no-whitespace-p
             (not (end-of-string-p lexer))
             (whitespacep (char (str lexer) (pos lexer))))
    (return-from get-number nil))
  (multiple-value-bind (integer new-pos)
      (parse-integer (str lexer)
                     :start (pos lexer)
                     :end (if max-length
                            (let ((end-pos (+ (pos lexer) max-length)))
                              (if (< end-pos (len lexer))
                                end-pos
                                nil))
                            nil)
                     :radix radix
                     :junk-allowed t)
    (cond ((and integer (>= integer 0))
            (setf (pos lexer) new-pos)
            integer)
          (t nil))))

(defmethod try-number ((lexer lexer) &key (radix 10) max-length no-whitespace-p)
  "Like GET-NUMBER but won't consume anything if no number is seen."
  (declare (optimize speed space))
  ;; remember current position
  (push (pos lexer) (last-pos lexer))
  (let ((number (get-number lexer
                            :radix radix
                            :max-length max-length
                            :no-whitespace-p no-whitespace-p)))
    (or number (fail lexer))))
  
(defun make-char-from-code (number error-pos)
  (declare (optimize speed space))
  "Create character from char-code NUMBER. NUMBER can be NIL
which is interpreted as 0. ERROR-POS is the position where
the corresponding number started within the regex string."
  ;; Only look at rightmost eight bits in compliance with Perl
  (let ((code (logand #o377 (or number 0))))
    (or (and (< code char-code-limit)
             (code-char code))
        (error "No character for hex-code ~X at position ~A~%"
               number (fix-pos error-pos)))))

(defmethod unescape-char ((lexer lexer))
  (declare (optimize speed space))
  (declare (special extended-mode-p))
  "Convert the characters(s) following a backslash into a token
which is returned. This function is to be called when the backslash
has already been consumed. Special character classes like \\W are
handled elsewhere."
  (when (end-of-string-p lexer)
    (error "String ends with backslash"))
  (let ((chr (next-char-non-extended lexer)))
    (case chr
      ((#\c)
        ;; \cx means control-x in Perl
        (let ((next-char (next-char-non-extended lexer)))
          (unless next-char
            (error "Character missing after '\\c' at position ~A"
                   (fix-pos (pos lexer))))
          (code-char (logxor #x40 (char-code (char-upcase next-char))))))
      ((#\x)
        ;; \x should be followed by a hexadecimal char code,
        ;; two digits or less
        (let* ((error-pos (pos lexer))
               (number (get-number lexer :radix 16 :max-length 2 :no-whitespace-p t)))
          ;; note that it is OK if \x is followed by zero digits
          (make-char-from-code number error-pos)))
      ((#\0 #\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
        ;; \x should be followed by an octal char code,
        ;; three digits or less
        (let* ((error-pos (decf (pos lexer)))
               (number (get-number lexer :radix 8 :max-length 3)))
          (make-char-from-code number error-pos)))
      ;; the following five character names are 'semi-standard'
      ;; according to the CLHS but I'm not aware of any implementation
      ;; that doesn't implement them
      ((#\t)
        #\Tab)
      ((#\n)
        #\Newline)
      ((#\r)
        #\Return)
      ((#\f)
        #\Page)
      ((#\b)
        #\Backspace)
      ((#\a)
        (code-char 7))                  ; ASCII bell
      ((#\e)
        (code-char 27))                 ; ASCII escape
      (otherwise
        ;; all other characters aren't affected by a backslash
        chr))))

(defmethod collect-char-class ((lexer lexer))
  (declare (optimize speed space))
  "Reads and consumes characters from regex string until a right
bracket is seen. Assembles them into a list (which is returned) of
characters, character ranges, like (:RANGE #\A #\E) for a-e, and
tokens representing special character classes."
  (let ((start-pos (pos lexer))         ; remember start for error message
        hyphen-seen
        last-char
        list)
    (flet ((handle-char (c)
             "Do the right thing with character C depending on whether
we're inside a range or not."
             (cond ((and hyphen-seen last-char)
                     (pop list)
                     (push (list :range last-char c) list)
                     (setq last-char nil))
                   (t
                     (push c list)
                     (setq last-char c)))
             (setq hyphen-seen nil)))
      (loop for first = t then nil
            for c = (next-char-non-extended lexer)
            ;; leave loop if at end of string
            while c
            do (cond
                 ((char= c #\\)
                   ;; we've seen a backslash
                   (let ((next-char (next-char-non-extended lexer)))
                     (case next-char
                       ((#\d #\D #\w #\W #\s #\S)
                         ;; a special character class
                         (push (map-char-to-special-char-class next-char) list)
                         ;; if the last character was a hyphen
                         ;; just collect it literally
                         (when hyphen-seen
                           (push #\- list))
                         ;; if the next character is a hyphen do the same
                         (when (looking-at-p lexer #\-)
                           (push #\- list)
                           (incf (pos lexer)))
                         (setq hyphen-seen nil))
                       (otherwise
                         ;; otherwise unescape the following character(s)
                         (decf (pos lexer))
                         (handle-char (unescape-char lexer))))))
                 (first
                   ;; the first character must not be a right bracket
                   ;; and isn't treated specially if it's a hyphen
                   (handle-char c))
                 ((char= c #\])
                   ;; end of character class
                   ;; make sure we collect a pending hyphen
                   (when hyphen-seen
                     (setq hyphen-seen nil)
                     (handle-char #\-))
                   ;; reverse the list to preserve the order intended
                   ;; by the author of the regex string
                   (return-from collect-char-class (nreverse list)))
                 ((and (char= c #\-)
                       last-char
                       (not hyphen-seen))
                   ;; if the last character was 'just a character'
                   ;; we expect to be in the middle of a range
                   (setq hyphen-seen t))
                 ((char= c #\-)
                   ;; otherwise this is just an ordinary hyphen
                   (handle-char #\-))
                 (t
                   ;; default case - just collect the character
                   (handle-char c))))
      ;; we can only exit the loop normally if we've reached the end
      ;; of the regex string without seeing a right bracket
      (error "Missing right bracket to close character class started at pos ~A"
             (fix-pos start-pos)))))

(defmethod maybe-parse-flags ((lexer lexer) test-only)
  (declare (optimize speed space))
  (declare (special extended-mode-p))
  "Reads a sequence of modifiers (including #\- to reverse their
meaning) and returns a corresponding list of \"flag\" tokens.  The
\"x\" modifier is treated specially in that it dynamically modifies
the behaviour of the lexer itself via the special variable
EXTENDED-MODE-P (unless TEST-ONLY is true)."
  (prog1
    (loop with set = t
          for chr = (next-char-non-extended lexer)
          unless chr
            do (error "Unexpected end of string")
          while (find chr "-imsx" :test #'char=)
          ;; the first #\- will invert the meaning of all modifiers
          ;; following it
          if (char= chr #\-)
            do (setq set nil)
          else if (and (char= chr #\x)
                       (not test-only))
            ;; only modify current setting if we're not testing
            do (setq extended-mode-p set)
          else collect (if set
                         (case chr
                           ((#\i)
                             :case-insensitive-p)
                           ((#\m)
                             :multi-line-mode-p)
                           ((#\s)
                             :single-line-mode-p))
                         (case chr
                           ((#\i)
                             :case-sensitive-p)
                           ((#\m)
                             :not-multi-line-mode-p)
                           ((#\s)
                             :not-single-line-mode-p))))
    (decf (pos lexer))))

(defmethod get-quantifier ((lexer lexer))
  (declare (optimize speed space))
  "Returns a list of two values (min max) if what the lexer is looking
at can be interpreted as a quantifier. Otherwise returns NIL and
resets the lexer to its old position."
  ;; remember starting position for FAIL and UNGET-TOKEN functions
  (push (pos lexer) (last-pos lexer))
  (let ((next-char (next-char lexer)))
    (case next-char
      ((#\*)
        ;; * (Kleene star): match 0 or more times
        '(0 nil))
      ((#\+)
        ;; +: match 1 or more times
        '(1 nil))
      ((#\?)
        ;; ?: match 0 or 1 times
        '(0 1))
      ((#\{)
        ;; one of
        ;;   {n}:   match exactly n times
        ;;   {n,}:  match at least n times
        ;;   {n,m}: match at least n but not more than m times
        ;; note that anything not matching one of these patterns will
        ;; be interpreted literally - even whitespace isn't allowed
        (let ((num1 (get-number lexer :no-whitespace-p t)))
          (if num1
            (let ((next-char (next-char-non-extended lexer)))
              (case next-char
                ((#\,)
                  (let* ((num2 (get-number lexer :no-whitespace-p t))
                         (next-char (next-char-non-extended lexer)))
                    (case next-char
                      ((#\})
                        ;; this is the case {n,} (NUM2 is NIL) or {n,m}
                        (list num1 num2))
                      (otherwise
                        (fail lexer)))))
                ((#\})
                  ;; this is the case {n}
                  (list num1 num1))
                (otherwise
                  (fail lexer))))
            ;; no number following left curly brace, so we treat it
            ;; like a normal character
            (fail lexer))))
      ;; cannot be a quantifier
      (otherwise
        (fail lexer)))))

(defmethod get-token ((lexer lexer) &key test-only)
  (declare (optimize speed space))
  "Returns and consumes the next token from the regex string (or NIL)."
  ;; remember starting position for UNGET-TOKEN function
  (with-accessors ((pos pos) (str str) (reg reg) (last-pos last-pos))
      lexer
    (push pos last-pos)
    (let ((next-char (next-char lexer)))
      (cond (next-char
              (case next-char
                ;; the easy cases first - the following six characters
                ;; always have a special meaning and get translated
                ;; into tokens immediately
                ((#\))
                  :close-paren)
                ((#\|)
                  :vertical-bar)
                ((#\?)
                  :question-mark)
                ((#\.)
                  :everything)
                ((#\^)
                  :start-anchor)
                ((#\$)
                  :end-anchor)
                ((#\+ #\*)
                  ;; quantifiers will always be consumend by
                  ;; GET-QUANTIFIER, they must not appear here
                  (error "Quantifier '~A' not allowed at position ~A"
                         next-char (fix-pos (1- pos))))
                ((#\{)
                  ;; left brace isn't a special character in it's own
                  ;; right but we must check if what follows might
                  ;; look like a quantifier
                  (let ((this-pos pos)
                        (this-last-pos last-pos))
                    (unget-token lexer)
                    (when (get-quantifier lexer)
                      (error "Quantifier '~A' not allowed at position ~A"
                             (subseq str (car this-last-pos) pos)
                             (fix-pos (car this-last-pos))))
                    (setq pos this-pos
                          last-pos this-last-pos)
                    next-char))
                ((#\[)
                  ;; left bracket always starts a character class
                  (if test-only
                    ;; if we're only testing the contents of the
                    ;; character class don't really matter
                    '(:char-class)
                    (cons  (cond ((looking-at-p lexer #\^)
                                   (incf pos)
                                   :inverted-char-class)
                                 (t
                                   :char-class))
                           (collect-char-class lexer))))
                ((#\\)
                  ;; backslash might mean different things so we have
                  ;; to peek one char ahead:
                  (let ((next-char (next-char-non-extended lexer)))
                    (case next-char
                      ((#\A)
                        :modeless-start-anchor)
                      ((#\Z)
                        :modeless-end-anchor)
                      ((#\z)
                        :modeless-end-anchor-no-newline)
                      ((#\b)
                        :word-boundary)
                      ((#\B)
                        :non-word-boundary)
                      ((#\d #\D #\w #\W #\s #\S)
                        ;; these will be treated like character classes
                        (map-char-to-special-char-class next-char))
                      ((#\1 #\2 #\3 #\4 #\5 #\6 #\7 #\8 #\9)
                        ;; uh, a digit...
                        (let* ((old-pos (decf pos))
                               ;; ...so let's get the whole number first
                               (backref-number (get-number lexer)))
                          (cond ((and (> backref-number reg)
                                      (<= 10 backref-number))
                                  ;; \10 and higher are treated as
                                  ;; octal character codes if we
                                  ;; haven't opened that much register
                                  ;; groups yet
                                  (setq pos old-pos)
                                  ;; re-read the number from the old
                                  ;; position and convert it to its
                                  ;; corresponding character
                                  (make-char-from-code (get-number lexer :radix 8 :max-length 3)
                                                       old-pos))
                                (t
                                  ;; otherwise this must refer to a
                                  ;; backreference
                                  (list :back-reference backref-number)))))
                      ((#\0)
                        ;; this always means an octal character code
                        ;; (at most three digits)
                        (let ((old-pos (decf pos)))
                          (make-char-from-code (get-number lexer :radix 8 :max-length 3)
                                               old-pos)))
                      (otherwise
                        ;; in all other cases just unescape the
                        ;; character
                        (decf pos)
                        (unescape-char lexer)))))
                ((#\()
                  ;; an open parenthesis might mean different things
                  ;; depending on what follows...
                  (cond ((looking-at-p lexer #\?)
                          ;; this is the case '(?' (and probably more behind)
                          (incf pos)
                          ;; we have to check for modifiers first
                          ;; because a colon might follow
                          (let* ((flags (maybe-parse-flags lexer test-only))
                                 (next-char (next-char-non-extended lexer)))
                            ;; modifiers are only allowed if a colon
                            ;; or a closing parenthesis are following
                            (when (and flags
                                       (not (find next-char ":)" :test #'char=)))
                              (error "Sequence '~A' not recognized at position ~A"
                                     (subseq str (car last-pos) pos)
                                     (fix-pos (car last-pos))))
                            (case next-char
                              ((nil)
                                ;; syntax error
                                (error "End of string following '(?'"))
                              ((#\))
                                ;; an empty group except for the flags
                                ;; (if there are any)
                                (or (and flags
                                         (cons :flags flags))
                                    :void))
                              ((#\()
                                ;; branch
                                :open-paren-paren)
                              ((#\>)
                                ;; standalone
                                :open-paren-greater)
                              ((#\=)
                                ;; positive look-ahead
                                :open-paren-equal)
                              ((#\!)
                                ;; negative look-ahead
                                :open-paren-exclamation)
                              ((#\:)
                                ;; non-capturing group - return flags
                                ;; as second value
                                (values :open-paren-colon flags))
                              ((#\<)
                                ;; might be a look-behind assertion,
                                ;; so check next character
                                (let ((next-char (next-char-non-extended lexer)))
                                  (case next-char
                                    ((#\=)
                                      ;; positive look-behind
                                      :open-paren-less-equal)
                                    ((#\!)
                                      ;; negative look-behind
                                      :open-paren-less-exclamation)
                                    ((#\))
                                      ;; Perl allows "(?<)" and treats
                                      ;; it like a null string
                                      :void)
                                    ((nil)
                                      ;; syntax error
                                      (error "End of string following '(?<'"))
                                    (t
                                      ;; also syntax error
                                      (error "Character '~A' may not follow '(?<' at position ~A"
                                             next-char (fix-pos (1- pos)))))))
                              (otherwise
                                (error "Character '~A' may not follow '(?' at position ~A"
                                       next-char (fix-pos (1- pos)))))))
                        (t
                          ;; if next-char was not #\? (this is within
                          ;; the first COND), we've just seen an
                          ;; opening parenthesis and leave it like
                          ;; that
                          :open-paren)))
                (otherwise
                  ;; all other characters are their own tokens
                  next-char)))
            ;; we didn't get a character (this if the "else" branch from
            ;; the first IF), so we don't return a token but NIL
            (t
              (pop last-pos)
              nil)))))
  
(defmethod unget-token ((lexer lexer))
  (declare (optimize speed space))
  "Moves the lexer back to the last position stored in the LAST-POS stack."
  (with-accessors ((pos pos) (last-pos last-pos))
      lexer
    (if last-pos
      (setq pos (pop last-pos))
      (error "No token to unget"))))

(defmethod start-of-subexpr-p ((lexer lexer))
  (declare (optimize speed space))
  "Tests whether the next token can start a valid sub-expression, i.e.
a stand-alone regex. So, e.g., tokens like :QUESTION-MARK are not
allowed. Note that no token (i.e. we're at the end of the regex
string) is fine."
  (let ((token (get-token lexer :test-only t)))
    (cond (token
            (unget-token lexer)
            (or (member token '(:open-paren
                                :open-paren-colon
                                :open-paren-greater
                                :open-paren-paren
                                :open-paren-equal
                                :open-paren-exclamation
                                :open-paren-less-equal
                                :open-paren-less-exclamation
                                :digit-class
                                :non-digit-class
                                :whitespace-char-class
                                :non-whitespace-char-class
                                :word-char-class
                                :non-word-char-class
                                :start-anchor
                                :end-anchor
                                :modeless-start-anchor
                                :modeless-end-anchor
                                :modeless-end-anchor-no-newline
                                :word-boundary
                                :non-word-boundary
                                :everything
                                :void)
                        :test #'eq)
                (and (consp token)
                     (member (car token) '(:char-class
                                           :inverted-char-class
                                           :back-reference
                                           :flags)
                             :test #'eq))
                (characterp token)))
          (t nil))))