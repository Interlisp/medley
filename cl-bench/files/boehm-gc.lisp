;;; boehm-gc.lisp -- benchmark testing GC performance
;;
;; Time-stamp: <2002-11-22 emarsden>
;;
;; see <URL:http://www.hpl.hp.com/personal/Hans_Boehm/gc/gc_bench.html>
;; for original code in C, C++, Java and Scheme. This is adapted from
;; the Scheme version.
;;
;;
;;  This is adapted from a benchmark written by John Ellis and Pete Kovac
;;  of Post Communications.
;;  It was modified by Hans Boehm of Silicon Graphics.
;;  It was translated into Scheme by William D Clinger of Northeastern Univ;
;;    the Scheme version uses (RUN-BENCHMARK <string> <thunk>)
;;  Last modified 30 May 1997.
;;
;;       This is no substitute for real applications.  No actual application
;;       is likely to behave in exactly this way.  However, this benchmark was
;;       designed to be more representative of real applications than other
;;       Java GC benchmarks of which we are aware.
;;       It attempts to model those properties of allocation requests that
;;       are important to current GC techniques.
;;       It is designed to be used either to obtain a single overall performance
;;       number, or to give a more detailed estimate of how collector
;;       performance varies with object lifetimes.  It prints the time
;;       required to allocate and collect balanced binary trees of various
;;       sizes.  Smaller trees result in shorter object lifetimes.  Each cycle
;;       allocates roughly the same amount of memory.
;;       Two data structures are kept around during the entire process, so
;;       that the measured performance is representative of applications
;;       that maintain some live in-memory data.  One of these is a tree
;;       containing many pointers.  The other is a large array containing
;;       double precision floating point numbers.  Both should be of comparable
;;       size.
;;
;;       The results are only really meaningful together with a specification
;;       of how much memory was used.  It is possible to trade memory for
;;       better time performance.  This benchmark should be run in a 32MB
;;       heap, though we don't currently know how to enforce that uniformly.


(in-package :cl-bench.boehm-gc)


(defstruct node left right dummy1 dummy2)

;; build tree top down, assigning to older objects
(defun populate (depth thisNode)
  (when (> depth 0)
    (setf (node-left thisNode) (make-node))
    (setf (node-right thisNode) (make-node))
    (populate (1- depth) (node-left thisNode))
    (populate (1- depth) (node-right thisNode))))

;; build tree bottom-up
(defun make-tree (depth)
  (if (<= depth 0) (make-node)
      (make-node :left (make-tree (- depth 1))
                 :right (make-tree (- depth 1)))))

;; nodes used by a tree of a given size
(defmacro tree-size (i) `(- (expt 2 (1+ ,i)) 1))

;; number of iterations to use for a given tree depth
(defmacro iteration-count (i)
  `(floor (* 2 (tree-size stretch-tree-depth))
    (tree-size ,i)))

(defun gcbench (stretch-tree-depth)
  (declare (fixnum stretch-tree-depth))

  ;;   Parameters are determined by stretch-tree-depth.
  ;;   In Boehm's version the parameters were fixed as follows:
  ;;     public static final int stretch-tree-depth    = 18;  // about 16Mb
  ;;     public static final int kLongLivedTreeDepth  = 16;  // about 4Mb
  ;;     public static final int kArraySize  = 500000;       // about 4Mb
  ;;     public static final int kMinTreeDepth = 4;
  ;;     public static final int kMaxTreeDepth = 16;
  ;;   In Larceny the storage numbers above would be 12 Mby, 3 Mby, 6 Mby.

  (let* ((kLongLivedTreeDepth (- stretch-tree-depth 2))
         (kArraySize          (* 4 (tree-size kLongLivedTreeDepth)))
         (kMinTreeDepth       4)
         (kMaxTreeDepth       kLongLivedTreeDepth))
    ;; (format t "Stretching memory with a binary tree of depth ~d~%" stretch-tree-depth)

    ;; stretch the memory space quickly
    (make-tree stretch-tree-depth)

    ;; Create a long lived object
    ;; (format t "Creating a long-lived binary tree of depth ~d~%" kLongLivedTreeDepth)
    (let ((longLivedTree (make-node)))
      (populate kLongLivedTreeDepth longLivedTree)

      ;; create long-lived array, filling half of it
      ;; (format t "Creating a long-lived array of ~d inexact reals~%" kArraySize)
      (let ((array (make-array kArraySize :element-type 'single-float)))
        (loop :for i :below (floor kArraySize 2)
              :do (setf (aref array i) (/ 1.0 (1+ i))))

        (do ((d kMinTreeDepth (+ d 2)))
            ((> d kMaxTreeDepth))
          (let ((iteration-count (iteration-count d)))
            ;; (format t "~&Creating ~d trees of depth ~d~%" iteration-count d)
            ;; (format t "GCBench: Top down construction~%")
            (dotimes (i iteration-count) (populate d (make-node)))
            ;; (format t "GCBench: Bottom up construction~%")
            (dotimes (i iteration-count) (make-tree d))))

        ;; these are fake references to LongLivedTree and array to
        ;; keep them from being optimized away
        (assert (not (null longLivedTree)))
        (assert (let ((n (min 1000 (1- (floor (length array) 2)))))
                  (= (round (aref array n)) (round (/ 1.0 (1+ n))))))))))

(defun gc-benchmark (&optional (k 18))
  ;; (format t "The garbage collector should touch about ~d megabytes of heap storage.~%"
  ;;         (expt 2 (- k 13)))
  ;; (format t "The use of more or less memory will skew the results.~%")
  (gcbench k))


;; EOF
