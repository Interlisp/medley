;;;; -*- Mode: Lisp; Syntax: Common-Lisp; Package: png; -*-
;;;; ------------------------------------------------------------------------------------------
;;;;     Title: The DEFLATE Compression (rfc1951)
;;;;   Created: Thu Apr 24 22:12:58 1997
;;;;    Author: Gilbert Baumann <unk6@rz.uni-karlsruhe.de>
;;;; ------------------------------------------------------------------------------------------
;;;;  (c) copyright 1997,1998 by Gilbert Baumann

(in-package :cl-bench.deflate)

;; Note: This implementation is inherently sloooow. On the other hand
;; it is safe and complete and easily verify-able. See
;; <URL:http://www.gzip.org/zlib/feldspar.html> for an explanation of
;; the algorithm.


;; these DEFVAR used to be DEFCONSTANT, but with a very strict reading
;; of CLtS, they are not truly constant.

(defvar +length-encoding+
  '#((0    3)     (0    4)     (0    5)     (0    6)     (0    7)     (0    8)
     (0    9)     (0   10)     (1   11)     (1   13)     (1   15)     (1   17)
     (2   19)     (2   23)     (2   27)     (2   31)     (3   35)     (3   43)
     (3   51)     (3   59)     (4   67)     (4   83)     (4   99)     (4  115)
     (5  131)     (5  163)     (5  195)     (5  227)     (0  258) ))

(defvar +dist-encoding+
  '#( (0     1)      (0     2)      (0     3)      (0     4)      (1     5)      (1     7)
      (2     9)      (2    13)      (3    17)      (3    25)      (4    33)      (4    49)
      (5    65)      (5    97)      (6   129)      (6   193)      (7   257)      (7   385)
      (8   513)      (8   769)      (9  1025)      (9  1537)     (10  2049)     (10  3073)
     (11  4097)     (11  6145)     (12  8193)     (12 12289)     (13 16385)     (13 24577)))

(defvar +fixed-huffman-code-lengths+
    (let ((res (make-array 288)))
      (loop for i from   0 to 143 do (setf (aref res i) 8))
      (loop for i from 144 to 255 do (setf (aref res i) 9))
      (loop for i from 256 to 279 do (setf (aref res i) 7))
      (loop for i from 280 to 287 do (setf (aref res i) 8))
      res))

(defstruct bit-stream
  (octets nil :type (vector (unsigned-byte 8))) ;a vector of octets
  (pos 0 :type fixnum))                         ;bit position within octet stream

(declaim (inline bit-stream-read-bit))
(declaim (inline bit-stream-read-byte))

(defun bit-stream-read-bit (source)
  (prog1
      (the fixnum
        (logand (the fixnum #x1)
                (the fixnum
                  (ash (the fixnum
                         (aref (the (array (unsigned-byte 8) (*)) (bit-stream-octets source))
                               (the fixnum (ash (the fixnum (bit-stream-pos source)) -3))))
                       (the fixnum (- (the fixnum (logand (the fixnum (bit-stream-pos source)) (the fixnum #x7)))))))))
    (incf (the fixnum (bit-stream-pos source)))))

(defun bit-stream-read-byte (source n)
  "Read one unsigned byte of width 'n' from the bit stream 'source'."
  (let* ((data (bit-stream-octets source))
         (pos  (bit-stream-pos source))
         (i (ash pos -3)))
    (declare (type fixnum i)
             (type fixnum pos))
    (prog1
        (logand
         (the fixnum (1- (the fixnum (ash 1 (the fixnum n)))))
         (the fixnum
           (logior
            (the fixnum (ash (aref (the (array (unsigned-byte 8) (*)) data) i) (- (logand pos #x7))))
            (the fixnum (ash (aref (the (array (unsigned-byte 8) (*)) data) (+ i 1)) (+ (- 8 (logand pos #x7)))))
            (the fixnum (ash (aref (the (array (unsigned-byte 8) (*)) data) (+ i 2)) (+ (- 16 (logand pos #x7)))))
            #|(the fixnum (ash (aref (the (simple-array (unsigned-byte 8) (*)) data) (+ i 3)) (+ (- 24 (logand pos #x7)))))|#
            )))
      (incf (the fixnum (bit-stream-pos source)) (the fixnum n)) )))

(defun bit-stream-read-reversed-byte (source n)
  "Read one unsigned byte of width 'n' from the bit stream 'source'."
  (let ((res 0))
    (dotimes (k n res)
      (setf res (logior res (ash (bit-stream-read-bit source) (1- (- n k))))) )))

(defun bit-stream-skip-to-byte-boundary (bs)
  (setf (bit-stream-pos bs) (* 8 (floor (+ 7 (bit-stream-pos bs)) 8))))

(defun bit-stream-read-symbol (source tree)
  "Read one symbol (code) from the bit-stream source using the huffman code provided by 'tree'."
  (do ()
      ((atom tree) tree)
    (setf tree (if (zerop (bit-stream-read-bit source)) (car tree) (cdr tree)))))

(defun build-huffman-tree (lengthen)
  "Build up a huffman tree given a vector of code lengthen as described in RFC1951."
  (let* ((max-bits (reduce #'max (map 'list #'identity lengthen)))
         (max-symbol (1- (length lengthen)))
         (bl-count (make-array (+ 1 max-bits) :initial-element 0))
         (next-code (make-array (+ 1 max-bits) :initial-element 0))
         (ht nil))
    (dotimes (i (Length lengthen))
      (let ((x (aref lengthen i)))
        (unless (zerop x)
          (incf (aref bl-count x)))))
    (let ((code 0))
      (loop
          for bits from 1 to max-bits
          do
            (progn
              (setf code (ash (+ code (aref bl-count (1- bits))) 1))
              (setf (aref next-code bits) code))))
    (loop
        for n from 0 to max-symbol
        do
          (let ((len (aref lengthen n)))
            (unless (zerop len)
              (setf ht (huffman-insert ht len (aref next-code len) n))
              (incf (aref next-code len)) )))
    ht ))

(defun huffman-insert (ht len code sym)
  (cond ((= 0 len)
         (assert (null ht))
         sym)
        ((logbitp (- len 1) code)
         (unless (consp ht) (setq ht (cons nil nil)))
         (setf (cdr ht) (huffman-insert (cdr ht) (1- len) code sym))
         ht)
        (t
         (unless (consp ht) (setq ht (cons nil nil)))
         (setf (car ht) (huffman-insert (car ht) (1- len) code sym))
         ht) ))

(defun rfc1951-read-huffman-code-lengthen (source code-length-huffman-tree number)
  (let ((res (make-array number :initial-element 0))
        (i 0))
    (do ()
        ((= i number))
      (let ((qux (bit-stream-read-symbol source code-length-huffman-tree)))
        (case qux
          (16
           (let ((cnt (+ 3 (bit-stream-read-byte source 2))))
             (dotimes (k cnt)
               (setf (aref res (+ i k)) (aref res (- i 1))))
             (incf i cnt)))
          (17
           (let ((cnt (+ 3 (bit-stream-read-byte source 3))))
             (dotimes (k cnt)
               (setf (aref res (+ i k)) 0))
             (incf i cnt)))
          (18
           (let ((cnt (+ 11 (bit-stream-read-byte source 7))))
             (dotimes (k cnt)
               (setf (aref res (+ i k)) 0))
             (incf i cnt)))
          (otherwise
           (setf (aref res i) qux)
           (incf i)) )))
    res))

(defun rfc1951-read-length-dist (source code hdists-ht)
  (values
   (+ (cadr (aref +length-encoding+ (- code 257)))
      (bit-stream-read-byte source (car (aref +length-encoding+ (- code 257)))))
   (let ((dist-sym (if hdists-ht
                       (bit-stream-read-symbol source hdists-ht)
                     (bit-stream-read-reversed-byte source 5) )))
         (+ (cadr (aref +dist-encoding+ dist-sym))
            (bit-stream-read-byte source (car (aref +dist-encoding+ dist-sym)))) ) ))

(defun rfc1951-uncompress-octets (octets &key (start 0))
  (let ((res (make-array 0 :element-type '(unsigned-byte 8) :fill-pointer 0 :adjustable t))
        (ptr 0))
    (rfc1951-uncompress-bit-stream (make-bit-stream :octets octets :pos (* 8 start))
                                     #'(lambda (buf n)
                                         (progn
                                           (adjust-array res (list (+ ptr n)))
                                           (setf (fill-pointer res) (+ ptr n))
                                           (replace res buf
                                                    :start1 ptr :end1 (+ ptr n)
                                                    :start2 0 :end2 n)
                                           (incf ptr n))))
    res))

(defun rfc1951-uncompress-bit-stream (bs cb)
  (let (final? ctype
        (buffer (make-array #x10000 :element-type '(unsigned-byte 8)))
        (bptr 0))
    (declare (type (simple-array (unsigned-byte 8) (#x10000)) buffer)
             (type fixnum bptr))
    (macrolet ((put-byte (byte)
                 `(let ((val ,byte))
                    (setf (aref buffer bptr) (the (unsigned-byte 8) val))
                    (setf bptr (the fixnum (logand #xffff (the fixnum (+ bptr 1)))))
                    (when (zerop bptr)
                      (funcall cb buffer #x10000) ))))
      (loop
        (setf final? (= (bit-stream-read-bit bs) 1)
              ctype (bit-stream-read-byte bs 2))
        (ecase ctype
          (0
           ;; no compression
           (bit-stream-skip-to-byte-boundary bs)
           (let ((len (bit-stream-read-byte bs 16))
                 (nlen (bit-stream-read-byte bs 16)))
             (assert (= (logand #xFFFF (lognot nlen)) len))
             (dotimes (k len)
               (put-byte (bit-stream-read-byte bs 8)))))

          (1
           ;; compressed with fixed Huffman code
           (let ((literal-ht (build-huffman-tree +fixed-huffman-code-lengths+)))
             (do ((x (bit-stream-read-symbol bs literal-ht) (bit-stream-read-symbol bs literal-ht)))
                 ((= x 256))
               (cond ((<= 0 x 255)
                      (put-byte x))
                     (t
                      (multiple-value-bind (length dist) (rfc1951-read-length-dist bs x nil)
                        (dotimes (k length)
                          (put-byte (aref buffer (logand (- bptr dist) #xffff)))))) )) ))

          (2
           ;; compressed with dynamic Huffman codes
           (let* ((hlit  (+ 257 (bit-stream-read-byte bs 5))) ;number of literal code lengths
                  (hdist (+ 1 (bit-stream-read-byte bs 5))) ;number of distance code lengths
                  (hclen (+ 4 (bit-stream-read-byte bs 4))) ;number of code lengths for code
                  (hclens (make-array 19 :initial-element 0)) ; length huffman tree
                  literal-ht distance-ht code-len-ht)

             ;; slurp the code lengths code lengths
             (loop
                 for i from 1 to hclen
                 for j in '(16 17 18 0 8 7 9 6 10 5 11 4 12 3 13 2 14 1 15)
                 do (setf (aref hclens j) (bit-stream-read-byte bs 3)))

             ;; slurp the huffman trees for literals and distances
             (setf code-len-ht (build-huffman-tree hclens))
             (setf literal-ht  (build-huffman-tree (rfc1951-read-huffman-code-lengthen bs code-len-ht hlit))
                   distance-ht (build-huffman-tree (rfc1951-read-huffman-code-lengthen bs code-len-ht hdist)))

             ;; actually slurp the contents
             (do ((x (bit-stream-read-symbol bs literal-ht) (bit-stream-read-symbol bs literal-ht)))
                 ((= x 256))
               (cond ((<= 0 x 255)
                      (put-byte x))
                     (t
                      (multiple-value-bind (length dist) (rfc1951-read-length-dist bs x distance-ht)
                        (dotimes (k length)
                          (put-byte (aref buffer (logand (- bptr dist) #xffff)))))) )) )) )
        (when final?
          (funcall cb buffer bptr)
          (return-from rfc1951-uncompress-bit-stream 'foo)) ))))


;; deflate a gzipped file. Requires reading the header, putting the
;; data into an array, and deflating the array. The format of the
;; header is documented in RFC1952.
(defun test-deflate-file (filename)
  (let ((compressed (make-array 0 :adjustable t
                                :fill-pointer t
                                :element-type '(unsigned-byte 8)))
        (header-flags 0)
        (xlen 0))
    (with-open-file (in filename :direction :input
                        :element-type '(unsigned-byte 8))
      (unless (and (= #x1f (read-byte in))
                   (= #x8b (read-byte in)))
        (error "~a is not a gzipped file" filename))
      (unless (= #x8 (read-byte in))
        (error "~a is not using deflate compression" filename))
      (setq header-flags (read-byte in))
      ;; skip over the modification time + XFL + OS marker
      (dotimes (i 6) (read-byte in))
      (unless (zerop (logand header-flags 4))    ; contains FEXTRA data
        (incf xlen (read-byte in))
        (incf xlen (* 256 (read-byte in)))
        (dotimes (i xlen) (read-byte in)))
      (unless (zerop (logand header-flags 8))    ; contains FNAME data
        (loop :until (zerop (read-byte in))))
      (unless (zerop (logand header-flags 16))    ; contains FCOMMENT data
        (loop :until (zerop (read-byte in))))
      (unless (zerop (logand header-flags 2))    ; contains FHCRC
        (read-byte in)
        (read-byte in))
      (loop :for byte = (read-byte in nil)
            :while byte :do (vector-push-extend byte compressed)))
    (rfc1951-uncompress-octets compressed)
    (values)))


(defun run-deflate-file ()
  (test-deflate-file "files/message.gz"))


;; EOF
