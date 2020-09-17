;; benchmarks speed of array and sequence operations
;;
;; Author: Eric Marsden <emarsden@laas.fr>
;; Time-stamp: <2003-12-29 emarsden>
;;
;;
;; Timing tests for creation, initialization, access and garbage
;; collection for arrays, vectors, bitvectors and strings.
;;
;; NOTE: be careful running these in CMUCL on Linux with sizes larger
;; than your RAM; you will most likely crash your machine.


(in-package :cl-bench.arrays)


(defun bench-1d-arrays (&optional (size 100000) (runs 10))
  (declare (fixnum size))
  (let ((ones (make-array size :element-type '(integer 0 1000) :initial-element 1))
        (twos (make-array size :element-type '(integer 0 1000) :initial-element 2))
        (threes (make-array size :element-type '(integer 0 2000))))
    (dotimes (runs runs)
      (dotimes (pos size)
        (setf (aref threes pos) (+ (aref ones pos) (aref twos pos))))
      (assert (null (search (list 4 5 6) threes)))))
  (values))

(defun bench-2d-arrays (&optional (size 2000) (runs 10))
  (declare (fixnum size))
  (let ((ones (make-array (list size size) :element-type '(integer 0 1000) :initial-element 1))
        (twos (make-array (list size size) :element-type '(integer 0 1000) :initial-element 2))
        (threes (make-array (list size size) :element-type '(integer 0 2000))))
    (dotimes (runs runs)
      (dotimes (i size)
        (dotimes (j size)
          (setf (aref threes i j)
                (+ (aref ones i j) (aref twos i j)))))
      (assert (eql 3 (aref threes 3 3)))))
  (values))

(defun bench-3d-arrays (&optional (size 200) (runs 10))
  (declare (fixnum size))
  (let ((ones (make-array (list size size size) :element-type '(integer 0 1000) :initial-element 1))
        (twos (make-array (list size size size) :element-type '(integer 0 1000) :initial-element 2))
        (threes (make-array (list size size size) :element-type '(integer 0 2000))))
    (dotimes (runs runs)
      (dotimes (i size)
        (dotimes (j size)
          (dotimes (k size)
            (setf (aref threes i j k)
                  (+ (aref ones i j k) (aref twos i j k))))))
      (assert (eql 3 (aref threes 3 3 3)))))
  (values))

(defun bench-bitvectors (&optional (size 1000000) (runs 700))
  (declare (fixnum size))
  (let ((zeros (make-array size :element-type 'bit :initial-element 0))
        (ones  (make-array size :element-type 'bit :initial-element 1))
        (xors  (make-array size :element-type 'bit)))
    (dotimes (runs runs)
      (bit-xor zeros ones xors)
      (bit-nand zeros ones xors)
      (bit-and zeros xors)))
  (values))

(defun bench-strings (&optional (size 1000000) (runs 50))
  (declare (fixnum size))
  (let ((zzz (make-string size :initial-element #\z))
        (xxx (make-string size)))
    (dotimes (runs runs)
      (and (fill xxx #\x)
           (replace xxx zzz)
           (search "xxxd" xxx)
           (nstring-upcase xxx))))
  (values))

(defun bench-strings/adjustable (&optional (size 1000000) (runs 100))
  (declare (fixnum size))
  (dotimes (runs runs)
    (let ((sink (make-array 10 :element-type 'character :adjustable t :fill-pointer 0)))
      (dotimes (i size)
        (vector-push-extend (code-char (mod i 128)) sink))))
  (values))

;; certain implementations such as OpenMCL have an array (and thus
;; string) length limit of (expt 2 24), so don't try this on humungous
;; sizes
(defun bench-string-concat (&optional (size 1000000) (runs 100))
  (declare (fixnum size))
  (dotimes (runs runs)
    (let ((len (length
                (with-output-to-string (string)
                  (dotimes (i size)
                    (write-sequence "hi there!" string))))))
      (assert (eql len (* size (length "hi there!")))))
    (values)))

(defun bench-search-sequence (&optional (size 1000000) (runs 10))
  (declare (fixnum size))
  (let ((haystack (make-array size :element-type '(integer 0 1000))))
    (dotimes (runs runs)
      (dotimes (i size)
        (setf (aref haystack i) (mod i 1000)))
      (assert (null (find -1 haystack :test #'=)))
      (assert (null (find-if #'minusp haystack)))
      (assert (null (position -1 haystack :test #'= :from-end t)))
      (loop :for i :from 20 :to 900 :by 20
            :do (assert (eql i (position i haystack :test #'=))))
      (assert (eql 0 (search #(0 1 2 3 4) haystack :end2 1000 :from-end t)))))
  (values))


;; EOF
