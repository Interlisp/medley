;;; -*- Mode: LISP; Syntax: COMMON-LISP; Package: CL-PPCRE; Base: 10 -*-
;;; $Header: /usr/local/cvsrep/cl-ppcre/parser.lisp,v 1.1.1.1 2002/12/20 10:10:44 edi Exp $

;;; The parser will - with the help of the lexer - parse a regex
;;; string and convert it into a "parse tree" (see docs for details
;;; about the syntax of these trees). Note that the lexer might return
;;; illegal parse trees. It is assumed that the conversion process
;;; later on will track them down.

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

(defmethod group ((lexer lexer))
  (declare (optimize speed space)
           (special extended-mode-p))
  "Parses and consumes a <group>.
The productions are: <group> -> \"(\"<regex>\")\"
                                \"(?:\"<regex>\")\"
                                \"(?<\"<regex>\")\"
                                \"(?<flags>:\"<regex>\")\"
                                \"(?=\"<regex>\")\"
                                \"(?!\"<regex>\")\"
                                \"(?<=\"<regex>\")\"
                                \"(?<!\"<regex>\")\"
                                \"(?(\"<num>\")\"<regex>\")\"
                                \"(?(\"<regex>\")\"<regex>\")\"
                                <legal-token>
where <flags> is parsed by the lexer function MAYBE-PARSE-FLAGS.
Will return <parse-tree> or (<grouping-type> <parse-tree>) where
<grouping-type> is one of six keywords - see source for details."
  ;; make sure modifications of extended mode are discarded at closing
  ;; parenthesis
  (multiple-value-bind (open-token flags)
      (get-token lexer)
    (cond ((eq open-token :open-paren-paren)
            ;; special case for conditional regular expressions; note
            ;; that at this point we accept a couple of illegal
            ;; combinations which'll be sorted out later by the
            ;; converter
            (let* ((open-paren-pos (car (last-pos lexer)))
                   ;; check if what follows "(?(" is a number
                   (number (try-number lexer :no-whitespace-p t))
                   ;; make changes to extended-mode-p local
                   (extended-mode-p extended-mode-p))
              (declare (special extended-mode-p))
              (cond (number
                      ;; condition is a number (i.e. refers to a
                      ;; back-reference)
                      (let* ((inner-close-token (get-token lexer))
                             (regex (regex lexer))
                             (close-token (get-token lexer)))
                        (unless (eq inner-close-token :close-paren)
                          (error "Opening paren at position ~A has no matching closing paren"
                                 (fix-pos (+ open-paren-pos 2))))
                        (unless (eq close-token :close-paren)
                          (error "Opening paren at position ~A has no matching closing paren"
                                 (fix-pos open-paren-pos)))
                        (list :branch number regex)))
                    (t
                      ;; condition must be a full regex (actually a
                      ;; look-behind or look-ahead); and here comes a
                      ;; terrible kludge: instead of being cleanly
                      ;; separated from the lexer, the parser pushes
                      ;; back the lexer by one position, thereby
                      ;; landing in the middle of the 'token' "(?(" -
                      ;; yuck!!
                      (decf (pos lexer))
                      (let* ((inner-regex (group lexer))
                             (regex (regex lexer))
                             (close-token (get-token lexer)))
                        (unless (eq close-token :close-paren)
                          (error "Opening paren at position ~A has no matching closing paren"
                                 (fix-pos open-paren-pos)))
                        (list :branch inner-regex regex))))))
          ((member open-token '(:open-paren
                                :open-paren-colon
                                :open-paren-greater
                                :open-paren-equal
                                :open-paren-exclamation
                                :open-paren-less-equal
                                :open-paren-less-exclamation)
                   :test #'eq)
            ;; make changes to extended-mode-p local
            (let ((extended-mode-p extended-mode-p))
              (declare (special extended-mode-p))
              ;; we saw one of the six token representing opening
              ;; parentheses
              (let* ((open-paren-pos (car (last-pos lexer)))
                     (regex (regex lexer))
                     (close-token (get-token lexer)))
                (when (eq open-token :open-paren)
                  ;; if this is the "("<regex>")" production we have to
                  ;; increment the register counter of the lexer
                  (incf (reg lexer)))
                (unless (eq close-token :close-paren)
                  ;; the token following <regex> must be the closing
                  ;; parenthesis or this is a syntax error
                  (error "Opening paren at position ~A has no matching closing paren"
                         (fix-pos open-paren-pos)))
                (if flags
                  ;; if the lexer has returned a list of flags this must
                  ;; have been the "(?:"<regex>")" production
                  (cons :group (nconc flags (list regex)))
                  (list (case open-token
                          ((:open-paren)
                            :register)
                          ((:open-paren-colon)
                            :group)
                          ((:open-paren-greater)
                            :standalone)
                          ((:open-paren-equal)
                            :positive-lookahead)
                          ((:open-paren-exclamation)
                            :negative-lookahead)
                          ((:open-paren-less-equal)
                            :positive-lookbehind)
                          ((:open-paren-less-exclamation)
                            :negative-lookbehind))
                        regex)))))
          (t
            ;; this is the <legal-token> production; <legal-token> is
            ;; any token which passes START-OF-SUBEXPR-P (otherwise
            ;; parsing had already stopped in the SEQ method)
            open-token))))

(defmethod greedy-quant ((lexer lexer))
  (declare (optimize speed space))
  "Parses and consumes a <greedy-quant>.
The productions are: <greedy-quant> -> <group> | <group><quantifier>
where <quantifier> is parsed by the lexer function GET-QUANTIFIER.
Will return <parse-tree> or (:GREEDY-REPETITION <min> <max> <parse-tree>)."
  (let* ((group (group lexer))
         (token (get-quantifier lexer)))
    (if token
      ;; if GET-QUANTIFIER returned a non-NIL value it's the
      ;; two-element list (<min> <max>)
      (list :greedy-repetition (first token) (second token) group)
      group)))

(defmethod quant ((lexer lexer))
  (declare (optimize speed space))
  "Parses and consumes a <quant>.
The productions are: <quant> -> <greedy-quant> | <greedy-quant>\"?\".
Will return the <parse-tree> returned by GREEDY-QUANT and optionally
change :GREEDY-REPETITION to :NON-GREEDY-REPETITION."
  (let* ((greedy-quant (greedy-quant lexer))
         (token (get-token lexer :test-only t)))
    (when token
      (if (eq token :question-mark)
        (setf (car greedy-quant) :non-greedy-repetition)
        (unget-token lexer)))
    greedy-quant))

(defmethod seq ((lexer lexer))
  (declare (optimize speed space))
  "Parses and consumes a <seq>.
The productions are: <seq> -> <quant> | <quant><seq>.
Will return <parse-tree> or (:SEQUENCE <parse-tree> <parse-tree>)."
  ;; Note that we're calling START-OF-SUBEXPR-P before we actually try
  ;; to parse a <seq> or <quant> in order to catch empty regular
  ;; expressions
  (if (start-of-subexpr-p lexer)
    (let ((quant (quant lexer)))
      (if (start-of-subexpr-p lexer)
        (list :sequence quant (seq lexer))
        quant))
    :void))

(defmethod regex ((lexer lexer))
  (declare (optimize speed space))
  "Parses and consumes a <regex>, a complete regular expression.
The productions are: <regex> -> <seq> | <seq>\"|\"<regex>.
Will return <parse-tree> or (:ALTERNATION <parse-tree> <parse-tree>)."
  (let ((token (get-token lexer :test-only t)))
    (cond ((not token)
            ;; if we didn't get any token we return :VOID which stands
            ;; for "empty regular expression"
            :void)
          ((eq token :vertical-bar)
            ;; now check whether the expression started with a
            ;; vertical bar, i.e. <seq> - the left alternation - is
            ;; empty
            (list :alternation :void (regex lexer)))
          (t
            ;; otherwise un-read the token we just saw and parse a
            ;; <seq> plus the token following it
            (unget-token lexer)
            (let* ((seq (seq lexer))
                   (token (get-token lexer :test-only t)))
              (cond ((not token)
                      ;; no further token, just a <seq>
                      seq)
                    ((eq token :vertical-bar)
                      ;; if the token was a vertical bar, this is an
                      ;; alternation and we have the second production
                      (list :alternation seq (regex lexer)))
                    (t
                      ;; a token which is not a vertical bar - this is
                      ;; either a syntax error or we're inside of a
                      ;; group and the next token is a closing
                      ;; parenthesis; so we just un-read the token and
                      ;; let another function take care of it
                      (unget-token lexer)
                      seq)))))))

(defun parse-string (str)
  (declare (optimize speed space))
  "Translate the regex string STR into a parse tree."
  (let* ((lexer (make-instance 'lexer :str str))
         (extended-mode-p nil)
         (parse-tree (regex lexer)))
    ;; initialize the extended mode flag to NIL before starting the lexer
    (declare (special extended-mode-p))
    ;; check whether we've consumed the whole regex string
    (if (end-of-string-p lexer)
      parse-tree
      (error "Expected end of string at position ~A"
             (fix-pos (pos lexer))))))