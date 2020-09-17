;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-PPCRE; Base: 10 -*-
;;; $Header: /usr/local/cvsrep/cl-ppcre/util.lisp,v 1.1.1.1 2002/12/20 10:10:44 edi Exp $

;;; Utility functions and constants dealing with the hash-tables
;;; we use to encode character classes

;;; Hash-tables are treated like sets, i.e. a character C is a member of the
;;; hash-table H iff (GETHASH C H) is true.

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

(eval-when (:compile-toplevel :execute :load-toplevel)
  (unless (boundp '+regex-char-code-limit+)
    (defconstant +regex-char-code-limit+ char-code-limit
      "The upper exclusive bound on the char-codes of characters
which can occur in character classes.
Change this value BEFORE compiling CL-PPCRE if you don't need
the full Unicode support of LW, ACL, or CLISP."))
  
  (defun make-char-hash (test)
    (declare (optimize speed space))
    "Returns a hash-table of all characters satisfying test."
    (loop with hash = (make-hash-table)
          for c of-type fixnum from 0 below +regex-char-code-limit+
          for chr = (code-char c)
          if (and chr (funcall test chr))
            do (setf (gethash chr hash) t)
          finally (return hash)))

  (declaim (inline word-char-p))
  
  (defun word-char-p (chr)
    (declare (optimize speed
                       (safety 0)
                       (space 0)
                       (debug 0)
                       (compilation-speed 0)
                       #+:lispworks (hcl:fixnum-safety 0)))
    "Tests whether a character is a \"word\" character.
In the ASCII charset this is equivalent to a-z, A-Z, 0-9, or _,
i.e. the same as Perl's [\\w]."
    (or (alphanumericp chr)
        (char= chr #\_)))

  (unless (boundp '+whitespace-char-string+)
    (defconstant +whitespace-char-string+
      (coerce
       '(#\Space #\Tab #\Linefeed #\Return #\Page)
       'string)
      "A string of all characters which are considered to be whitespace.
Same as Perl's [\\s]."))

  (defun whitespacep (chr)
    (declare (optimize speed space))
    "Tests whether a character is whitespace,
i.e. whether it would match [\\s] in Perl."
    (find chr +whitespace-char-string+ :test #'char=)))

;; the following DEFCONSTANT statements are wrapped with
;; (UNLESS (BOUNDP ...) ...) to make SBCL happy

(unless (boundp '+digit-hash+)
  (defconstant +digit-hash+
    (make-char-hash (lambda (chr) (char<= #\0 chr #\9)))
    "Hash-table containing the digits from 0 to 9."))

(unless (boundp '+word-char-hash+)
  (defconstant +word-char-hash+
    (make-char-hash #'word-char-p)
    "Hash-table containing all \"word\" characters."))

(unless (boundp '+whitespace-char-hash+)
  (defconstant +whitespace-char-hash+
    (make-char-hash #'whitespacep)
    "Hash-table containing all whitespace characters."))

(defun merge-hash (hash1 hash2)
  (declare (optimize speed space))
  "Returns the \"sum\" of two hashes."
  (loop for chr being the hash-keys of hash2
        do (setf (gethash chr hash1) t))
  hash1)

(defun merge-inverted-hash (hash1 hash2)
  (declare (optimize speed space))
  "Returns the \"sum\" of hash1 and the \"inverse\" of hash2."
  (loop for c of-type fixnum from 0 below +regex-char-code-limit+
        for chr = (code-char c)
        if (and chr (not (gethash chr hash2)))
            do (setf (gethash chr hash1) t))
  hash1)

(defun create-ranges-from-hash (hash &key downcasep)
  (declare (optimize speed space))
  "Tries to identify up to three intervals (with respect to CHAR<)
which together comprise HASH. Returns NIL if this is not possible.
If DOWNCASEP is true it will treat the hash-table as if it represents
both the lower-case and the upper-case variants of its members and
will only return the respective lower-case intervals."
  ;; discard empty hash-tables
  (unless (plusp (hash-table-count hash))
    (return-from create-ranges-from-hash nil))
  (loop with min1 and min2 and min3
        and max1 and max2 and max3
        ;; loop through all characters in HASH, sorted by CHAR<
        for chr in (sort (loop for chr being the hash-keys of hash
                               collect (if downcasep
                                         (char-downcase chr)
                                         chr))
                         #'char<)
        for code = (char-code chr)
        ;; MIN1, MAX1, etc. are _exclusive_
        ;; bounds of the intervals identified so far
        do (cond
             ((not min1)
               ;; this will only happen once, for the first character
               (setq min1 (1- code)
                     max1 (1+ code)))
             ((<= min1 code max1)
               ;; we're here as long as CHR fits into the first interval
               (setq min1 (min min1 (1- code))
                     max1 (max max1 (1+ code))))
             ((not min2)
               ;; we need to open a second interval
               ;; this'll also happen only once
               (setq min2 (1- code)
                     max2 (1+ code)))
             ((<= min2 code max2)
               ;; CHR fits into the second interval
               (setq min2 (min min2 (1- code))
                     max2 (max max2 (1+ code))))
             ((not min3)
               ;; we need to open the third interval
               ;; happens only once
               (setq min3 (1- code)
                     max3 (1+ code)))
             ((<= min3 code max3)
               ;; CHR fits into the third interval
               (setq min3 (min min3 (1- code))
                     max3 (max max3 (1+ code))))
             (t
               ;; we're out of luck, CHR doesn't fit
               ;; into one of the three intervals
               (return nil)))
        ;; on success return all bounds
        ;; make them inclusive bounds before returning
        finally (return (values (code-char (1+ min1))
                                (code-char (1- max1))
                                (and min2 (code-char (1+ min2)))
                                (and max2 (code-char (1- max2)))
                                (and min3 (code-char (1+ min3)))
                                (and max3 (code-char (1- max3)))))))
