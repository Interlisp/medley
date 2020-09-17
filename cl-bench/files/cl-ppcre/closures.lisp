;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-PPCRE; Base: 10 -*-
;;; $Header: /usr/local/cvsrep/cl-ppcre/closures.lisp,v 1.1.1.1 2002/12/20 10:10:44 edi Exp $

;;; Here we create the closures which together build the final
;;; scanner.

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

(declaim (inline special-string= special-string-equal))

(defun *string*= (string2 start1 end1 start2 end2)
  "Like STRING=, i.e. compares the special string *STRING* from START1
to END1 with STRING2 from START2 to END2. Note that there's no
boundary check - this has to be implemented by the caller."
  (declare (optimize speed
                     (safety 0)
                     (space 0)
                     (debug 0)
                     (compilation-speed 0)
                     #+:lispworks (hcl:fixnum-safety 0)))
  (declare (type fixnum start1 end1 start2 end2))
  (loop for string1-idx of-type fixnum from start1 below end1
        for string2-idx of-type fixnum from start2 below end2
        always (char= (schar *string* string1-idx)
                      (schar string2 string2-idx))))

(defun *string*-equal (string2 start1 end1 start2 end2)
  "Like STRING-EQUAL, i.e. compares the special string *STRING* from
START1 to END1 with STRING2 from START2 to END2. Note that there's no
boundary check - this has to be implemented by the caller."
  (declare (optimize speed
                     (safety 0)
                     (space 0)
                     (debug 0)
                     (compilation-speed 0)
                     #+:lispworks (hcl:fixnum-safety 0)))
  (declare (type fixnum start1 end1 start2 end2))
  (loop for string1-idx of-type fixnum from start1 below end1
        for string2-idx of-type fixnum from start2 below end2
        always (char-equal (schar *string* string1-idx)
                           (schar string2 string2-idx))))

(defgeneric create-matcher-aux (regex next-fn)
  (declare (optimize speed
                     (safety 0)
                     (space 0)
                     (debug 0)
                     (compilation-speed 0)
                     #+:lispworks (hcl:fixnum-safety 0)))
  (:documentation "Creates a closure which takes one parameter,
START-POS, and tests whether REGEX can match *STRING* at START-POS
such that the call to NEXT-FN after the match would succeed."))
                
(defmethod create-matcher-aux ((seq seq) next-fn)
  ;; the closure for a SEQ is a chain of closures for the elements of
  ;; this sequence which call each other in turn; the last closure
  ;; calls NEXT-FN
  (loop for element in (reverse (elements seq))
        for curr-matcher = next-fn then next-matcher
        for next-matcher = (create-matcher-aux element curr-matcher)
        finally (return next-matcher)))

(defmethod create-matcher-aux ((alternation alternation) next-fn)
  ;; first create closures for all alternations of ALTERNATION
  (let ((all-matchers (mapcar #'(lambda (choice)
                                  (create-matcher-aux choice next-fn))
                              (choices alternation))))
    ;; now create a closure which checks if one of the closures
    ;; created above can succeed
    (lambda (start-pos)
      (declare (type fixnum start-pos))
      (loop for matcher in all-matchers
            thereis (funcall (the function matcher) start-pos)))))

(defmethod create-matcher-aux ((register register) next-fn)
  ;; the position of this REGISTER within the whole regex; we start to
  ;; count at 0
  (let ((num (num register)))
    (declare (type fixnum num))
    ;; STORE-END-OF-REG is a thin wrapper around NEXT-FN which will
    ;; update the corresponding values of *REGS-START* and *REGS-END*
    ;; after the inner matcher has succeeded
    (flet ((store-end-of-reg (start-pos)
               (declare (type fixnum start-pos)
                        (type function next-fn))
               (setf (svref *reg-starts* num) (svref *regs-maybe-start* num)
                     (svref *reg-ends* num) start-pos)
           (funcall next-fn start-pos)))
      ;; the inner matcher is a closure corresponding to the regex
      ;; wrapped by this REGISTER
      (let ((inner-matcher (create-matcher-aux (regex register)
                                               #'store-end-of-reg)))
        (declare (type function inner-matcher))
        ;; here comes the actual closure for REGISTER
        (lambda (start-pos)
          (declare (type fixnum start-pos))
          ;; remember the old values of *REGS-START* and friends in
          ;; case we cannot match
          (let ((old-*reg-starts* (svref *reg-starts* num))
                (old-*regs-maybe-start* (svref *regs-maybe-start* num))
                (old-*reg-ends* (svref *reg-ends* num)))
            ;; we cannot use *REGS-START* here because Perl allows
            ;; regular expressions like /(a|\1x)*/
            (setf (svref *regs-maybe-start* num) start-pos)
            (let ((next-pos (funcall inner-matcher start-pos)))
              (unless next-pos
                ;; restore old values on failure
                (setf (svref *reg-starts* num) old-*reg-starts*
                      (svref *regs-maybe-start* num) old-*regs-maybe-start*
                      (svref *reg-ends* num) old-*reg-ends*))
              next-pos)))))))

(defmethod create-matcher-aux ((lookahead lookahead) next-fn)
  ;; create a closure which just checks for the inner regex and
  ;; doesn't care about NEXT-FN
  (let ((test-matcher (create-matcher-aux (regex lookahead) #'identity)))
    (declare (type function next-fn test-matcher))
    (if (positivep lookahead)
      ;; positive look-ahead: check success of inner regex, then call
      ;; NEXT-FN
      (lambda (start-pos)
        (and (funcall test-matcher start-pos)
             (funcall next-fn start-pos)))
      ;; negative look-ahead: check failure of inner regex, then call
      ;; NEXT-FN
      (lambda (start-pos)
        (and (not (funcall test-matcher start-pos))
             (funcall next-fn start-pos))))))

(defmethod create-matcher-aux ((lookbehind lookbehind) next-fn)
  (let ((len (len lookbehind))
        ;; create a closure which just checks for the inner regex and
        ;; doesn't care about NEXT-FN
        (test-matcher (create-matcher-aux (regex lookbehind) #'identity)))
    (declare (type function next-fn test-matcher)
             (type fixnum len))
    (if (positivep lookbehind)
      ;; positive look-behind: check success of inner regex (if we're
      ;; far enough from the start of *STRING*), then call NEXT-FN
      (lambda (start-pos)
        (declare (type fixnum start-pos))
        (and (>= (- start-pos *start-pos*) len)
             (funcall test-matcher (- start-pos len))
             (funcall next-fn start-pos)))
      ;; negative look-behind: check failure of inner regex (if we're
      ;; far enough from the start of *STRING*), then call NEXT-FN
      (lambda (start-pos)
        (declare (type fixnum start-pos))
        (and (or (< start-pos len)
                 (not (funcall test-matcher (- start-pos len))))
             (funcall next-fn start-pos))))))

(defmacro insert-char-class-tester ((char-class chr-expr) &body body)
  "Utility macro to replace each occurence of '(CHAR-CLASS-TEST)
within BODY with the correct test (corresponding to CHAR-CLASS)
against CHR-EXPR."
  (let ((=char-class= (gensym)))
    ;; the actual substitution is done here: replace
    ;; '(CHAR-CLASS-TEST) with NEW
    (flet ((substitute-char-class-tester (new)
               (subst new '(char-class-test) body
                      :test #'equalp)))
      `(let* ((,=char-class= ,char-class)
              (hash (hash ,=char-class=))
              (count (hash-table-count hash))
              ;; collect a list of "all" characters in the hash if
              ;; there aren't more than two
              (key-list (if (<= count 2)
                          (loop for chr being the hash-keys of hash
                                collect chr)
                          nil))
              downcasedp)
        ;; check if we can partition the hash into three ranges (or
        ;; less)
        (multiple-value-bind (min1 max1 min2 max2 min3 max3)
            (create-ranges-from-hash hash)
          ;; if that didn't work and CHAR-CLASS is case-insensitive we
          ;; try it again with every character downcased
          (when (and (not min1)
                     (case-insensitive-p ,=char-class=))
            (multiple-value-setq (min1 max1 min2 max2 min3 max3)
              (create-ranges-from-hash hash :downcasep t))
            (setq downcasedp t))
          (cond ((= count 1)
                  ;; hash contains exactly one character so we just
                  ;; check for this single character; (note that this
                  ;; actually can't happen because this case is
                  ;; optimized away in CONVERT already...)
                  (let ((chr1 (first key-list)))
                    ,@(substitute-char-class-tester
                       `(char= ,chr-expr chr1))))
                ((= count 2)
                  ;; hash contains exactly two characters
                  (let ((chr1 (first key-list))
                        (chr2 (second key-list)))
                    ,@(substitute-char-class-tester
                       `(let ((chr ,chr-expr))
                         (or (char= chr chr1)
                             (char= chr chr2))))))
                ((word-char-class-p ,=char-class=)
                  ;; special-case: hash is \w, \W, [\w], [\W] or
                  ;; something equivalent
                  ,@(substitute-char-class-tester
                     `(word-char-p ,chr-expr)))
                ((= count +regex-char-code-limit+)
                  ;; according to the ANSI standard we might have all
                  ;; possible characters in the hash even if it
                  ;; doesn't contain +CHAR-CODE-LIMIT+ characters but
                  ;; this doesn't seem to be the case for current
                  ;; implementations (also note that this optimization
                  ;; implies that you must not have characters with
                  ;; character codes beyond +REGEX-CHAR-CODE-LIMIT+ in
                  ;; your regexes if you've changed this limit); we
                  ;; expect the compiler to optimize this T "test"
                  ;; away
                  ,@(substitute-char-class-tester t))
                ((and downcasedp min1 min2 min3)
                  ;; three different ranges, downcased
                  ,@(substitute-char-class-tester
                     `(let ((down-chr (char-downcase ,chr-expr)))
                       (or (char<= min1 down-chr max1)
                           (char<= min2 down-chr max2)
                           (char<= min3 down-chr max3)))))
                ((and downcasedp min1 min2)
                  ;; two ranges, downcased
                  ,@(substitute-char-class-tester
                     `(let ((down-chr (char-downcase ,chr-expr)))
                       (or (char<= min1 down-chr max1)
                           (char<= min2 down-chr max2)))))
                ((and downcasedp min1)
                  ;; one downcased range
                  ,@(substitute-char-class-tester
                     `(char<= min1 (char-downcase ,chr-expr) max1)))
                ((and min1 min2 min3)
                  ;; three ranges
                  ,@(substitute-char-class-tester
                     `(let ((chr ,chr-expr))
                       (or (char<= min1 chr max1)
                           (char<= min2 chr max2)
                           (char<= min3 chr max3)))))
                ((and min1 min2)
                  ;; two ranges
                  ,@(substitute-char-class-tester
                     `(let ((chr ,chr-expr))
                       (or (char<= min1 chr max1)
                           (char<= min2 chr max2)))))
                (min1
                  ;; one range
                  ,@(substitute-char-class-tester
                     `(char<= min1 ,chr-expr max1)))
                (t
                  ;; the general case; note that most of the above
                  ;; "optimizations" are based on experiences and
                  ;; benchmarks with CMUCL - if you're really
                  ;; concerned with speed you might find out that the
                  ;; general case is almost always the best one for
                  ;; other implementations (because the speed of their
                  ;; hash-table access in relation to other operations
                  ;; might be better than in CMUCL)
                  ,@(substitute-char-class-tester
                     `(gethash ,chr-expr hash)))))))))

(defmethod create-matcher-aux ((char-class char-class) next-fn)
  (declare (type function next-fn))
  ;; insert a test against the current character within *STRING*
  (insert-char-class-tester (char-class (schar *string* start-pos))
    (if (invertedp char-class)
      (lambda (start-pos)
        (declare (type fixnum start-pos))
        (and (< start-pos *end-pos*)
             (not (char-class-test))
             (funcall next-fn (1+ start-pos))))
      (lambda (start-pos)
        (declare (type fixnum start-pos))
        (and (< start-pos *end-pos*)
             (char-class-test)
             (funcall next-fn (1+ start-pos)))))))

(defmethod create-matcher-aux ((str str) next-fn)
  (declare (type fixnum *end-string-pos*)
           (type function next-fn)
           ;; this special value is set by CREATE-SCANNER when the
           ;; closures are built
           (special end-string))
  (let* ((len (len str))
         (case-insensitive-p (case-insensitive-p str))
         (start-of-end-string-p (start-of-end-string-p str))
         (skip (skip str))
         (str (str str))
         (chr (schar str 0))
         (end-string (and end-string (str end-string)))
         (end-string-len (if end-string
                           (length end-string)
                           nil)))
    (declare (type fixnum len))
    (cond ((and start-of-end-string-p case-insensitive-p)
            ;; closure for the first STR which belongs to the constant
            ;; string at the end of the regular expression;
            ;; case-insensitive version
            (lambda (start-pos)
              (declare (type fixnum start-pos end-string-len))
              (let ((test-end-pos (+ start-pos end-string-len)))
                (declare (type fixnum test-end-pos))
                ;; either we're at *END-STRING-POS* (which means that
                ;; it has already been confirmed that end-string
                ;; starts here) or we really have to test
                (and (or (= start-pos *end-string-pos*)
                         (and (<= test-end-pos *end-pos*)
                              (*string*-equal end-string start-pos test-end-pos
                                              0 end-string-len)))
                     (funcall next-fn (+ start-pos len))))))
          (start-of-end-string-p
            ;; closure for the first STR which belongs to the constant
            ;; string at the end of the regular expression;
            ;; case-sensitive version
            (lambda (start-pos)
              (declare (type fixnum start-pos end-string-len))
              (let ((test-end-pos (+ start-pos end-string-len)))
                (declare (type fixnum test-end-pos))
                ;; either we're at *END-STRING-POS* (which means that
                ;; it has already been confirmed that end-string
                ;; starts here) or we really have to test
                (and (or (= start-pos *end-string-pos*)
                         (and (<= test-end-pos *end-pos*)
                              (*string*= end-string start-pos test-end-pos
                                         0 end-string-len)))
                     (funcall next-fn (+ start-pos len))))))
          (skip
            ;; a STR which can be skipped because some other function
            ;; has already confirmed that it matches
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (funcall next-fn (+ start-pos len))))
          ((and (= len 1) case-insensitive-p)
            ;; STR represent exactly one character; case-insensitive
            ;; version
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (and (< start-pos *end-pos*)
                   (char-equal (schar *string* start-pos) chr)
                   (funcall next-fn (1+ start-pos)))))
          ((= len 1)
            ;; STR represent exactly one character; case-sensitive
            ;; version
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (and (< start-pos *end-pos*)
                   (char= (schar *string* start-pos) chr)
                   (funcall next-fn (1+ start-pos)))))
          (case-insensitive-p
            ;; general case, case-insensitive version
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (let ((next-pos (+ start-pos len)))
                (declare (type fixnum next-pos))
                (and (<= next-pos *end-pos*)
                     (*string*-equal str start-pos next-pos 0 len)
                     (funcall next-fn next-pos)))))
          (t
            ;; general case, case-sensitive version
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (let ((next-pos (+ start-pos len)))
                (declare (type fixnum next-pos))
                (and (<= next-pos *end-pos*)
                     (*string*= str start-pos next-pos 0 len)
                     (funcall next-fn next-pos))))))))

(declaim (inline word-boundary-p))

(defun word-boundary-p (start-pos)
  "Check whether START-POS is a word-boundary within *STRING*."
  (declare (optimize speed
                     (safety 0)
                     (space 0)
                     (debug 0)
                     (compilation-speed 0)
                     #+:lispworks (hcl:fixnum-safety 0)))
  (declare (type fixnum start-pos))
  (let ((1-start-pos (1- start-pos)))
    ;; either the character before START-POS is a word-constituent and
    ;; the character at START-POS isn't...
    (or (and (or (= start-pos *end-pos*)
                 (and (< start-pos *end-pos*)
                      (not (word-char-p (schar *string* start-pos)))))
             (and (< 1-start-pos *end-pos*)
                  (<= *start-pos* 1-start-pos)
                  (word-char-p (schar *string* 1-start-pos))))
        ;; ...or vice versa
        (and (or (= start-pos *start-pos*)
                 (and (< 1-start-pos *end-pos*)
                      (<= *start-pos* 1-start-pos)
                      (not (word-char-p (schar *string* 1-start-pos)))))
             (and (< start-pos *end-pos*)
                  (word-char-p (schar *string* start-pos)))))))

(defmethod create-matcher-aux ((word-boundary word-boundary) next-fn)
  (declare (type function next-fn))
  (if (negatedp word-boundary)
    (lambda (start-pos)
      (and (not (word-boundary-p start-pos))
           (funcall next-fn start-pos)))
    (lambda (start-pos)
      (and (word-boundary-p start-pos)
           (funcall next-fn start-pos)))))

(defmethod create-matcher-aux ((everything everything) next-fn)
  (declare (type function next-fn))
  (if (single-line-p everything)
    ;; closure for single-line-mode: we really match everything, so we
    ;; just advance the index into *STRING* by one and carry on
    (lambda (start-pos)
      (declare (type fixnum start-pos))
      (and (< start-pos *end-pos*)
           (funcall next-fn (1+ start-pos))))
    ;; not single-line-mode, so we have to make sure we don't match
    ;; #\Newline
    (lambda (start-pos)
      (declare (type fixnum start-pos))
      (and (< start-pos *end-pos*)
           (char/= (schar *string* start-pos) #\Newline)
           (funcall next-fn (1+ start-pos))))))

(defmethod create-matcher-aux ((anchor anchor) next-fn)
  (declare (type function next-fn))
  (let ((startp (startp anchor))
        (multi-line-p (multi-line-p anchor)))
    (cond ((no-newline-p anchor)
            ;; this must be and end-anchor and it must be modeless, so
            ;; we just have to check whether START-POS equals
            ;; *END-POS*
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (and (= start-pos *end-pos*)
                   (funcall next-fn start-pos))))
          ((and startp multi-line-p)
            ;; a start-anchor in multi-line-mode: check if we're at
            ;; *START-POS* or if the last character was #\Newline
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (and (or (= start-pos *start-pos*)
                       (and (<= start-pos *end-pos*)
                            (> start-pos *start-pos*)
                            (char= #\Newline
                                   (schar *string* (1- start-pos)))))
                   (funcall next-fn start-pos))))
          (startp
            ;; a start-anchor which is not in multi-line-mode, so just
            ;; check whether we're at *START-POS*
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (and (= start-pos *start-pos*)
                   (funcall next-fn start-pos))))
          (multi-line-p
            ;; an end-anchor in multi-line-mode: check if we're at
            ;; *END-POS* or if the character we're looking at is
            ;; #\Newline
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (and (or (= start-pos *end-pos*)
                       (and (< start-pos *end-pos*)
                            (char= #\Newline
                                   (schar *string* start-pos))))
                   (funcall next-fn start-pos))))
          (t
            ;; an end-anchor which is not in multi-line-mode, so just
            ;; check if we're at *END-POS* or if we're looking at
            ;; #\Newline and there's nothing behind it
            (lambda (start-pos)
              (declare (type fixnum start-pos))
              (and (or (= start-pos *end-pos*)
                       (and (= start-pos (1- *end-pos*))
                            (char= #\Newline
                                   (schar *string* start-pos))))
                   (funcall next-fn start-pos)))))))

(defmethod create-matcher-aux ((back-reference back-reference) next-fn)
  (declare (type function next-fn))
  ;; the position of the corresponding REGISTER within the whole
  ;; regex; we start to count at 0
  (let ((num (num back-reference)))
    (if (case-insensitive-p back-reference)
      ;; the case-insensitive version
      (lambda (start-pos)
        (declare (type fixnum start-pos))
        (let ((reg-start (svref *reg-starts* num))
              (reg-end (svref *reg-ends* num)))
          ;; only bother to check if the corresponding REGISTER as
          ;; matched successfully already
          (and reg-start
               (let ((next-pos (+ start-pos (- (the fixnum reg-end)
                                               (the fixnum reg-start)))))
                 (declare (type fixnum next-pos))
                 (and
                   (<= next-pos *end-pos*)
                   (*string*-equal *string* start-pos next-pos
                                   reg-start reg-end)
                   (funcall next-fn next-pos))))))
      ;; the case-sensitive version
      (lambda (start-pos)
        (declare (type fixnum start-pos))
        (let ((reg-start (svref *reg-starts* num))
              (reg-end (svref *reg-ends* num)))
          ;; only bother to check if the corresponding REGISTER as
          ;; matched successfully already
          (and reg-start
               (let ((next-pos (+ start-pos (- (the fixnum reg-end)
                                               (the fixnum reg-start)))))
                 (declare (type fixnum next-pos))
                 (and
                   (<= next-pos *end-pos*)
                   (*string*= *string* start-pos next-pos
                              reg-start reg-end)
                   (funcall next-fn next-pos)))))))))

(defmethod create-matcher-aux ((branch branch) next-fn)
  (with-slots ((test test))
      branch
    (let ((then-matcher (create-matcher-aux (then-regex branch) next-fn))
          (else-matcher (create-matcher-aux (else-regex branch) next-fn)))
      (declare (type function then-matcher else-matcher))
      (cond ((numberp test)
              (lambda (start-pos)
                (declare (type fixnum test))
                (if (and (< test (length *reg-starts*))
                         (svref *reg-starts* test))
                  (funcall then-matcher start-pos)
                  (funcall else-matcher start-pos))))
            (t
              (let ((test-matcher (create-matcher-aux test #'identity)))
                (declare (type function test-matcher))
                (lambda (start-pos)
                  (if (funcall test-matcher start-pos)
                    (funcall then-matcher start-pos)
                    (funcall else-matcher start-pos)))))))))

(defmethod create-matcher-aux ((standalone standalone) next-fn)
  (let ((inner-matcher (create-matcher-aux (regex standalone) #'identity)))
    (declare (type function next-fn inner-matcher))
    (lambda (start-pos)
      (let ((next-pos (funcall inner-matcher start-pos)))
        (and next-pos
             (funcall next-fn next-pos))))))

(defmethod create-matcher-aux ((void void) next-fn)
  ;; optimize away VOIDs: don't create a closure, just return NEXT-FN
  next-fn)

;; Local variables:
;; eval: (put 'insert-char-class-tester 'common-lisp-indent-function '((&whole 4 1) &body))
