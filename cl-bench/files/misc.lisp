;;; misc.lisp
;;;
;;; Time-stamp: <2004-06-28 emarsden>


(in-package :cl-bench.misc)



(defun run-compiler ()
  (compile-file (make-pathname :directory '(:relative "files")
                               :name "gabriel"
                               :type "olisp")
                :print nil
                #-gcl :verbose #-gcl nil))

(defun run-fasload ()
  (load
   (compile-file-pathname
    (make-pathname :directory '(:relative "files")
                   :name "gabriel"
                   :type "olisp"))))


;; by Gene Luks (adapted from the Larceny benchmarks)
;
; Procedure P_n generates a grey code of all perms of n elements
; on top of stack ending with reversal of starting sequence
;
; F_n is flip of top n elements.
;
; procedure P_n
;   if n>1 then
;     begin
;        repeat   P_{n-1},F_n   n-1 times;
;        P_{n-1}
;     end
(defun permutations (x)
  (let* ((x x)
         (perms (list x)))
    (labels ((P (n)
               (if (> n 1)
                   (do ((j (- n 1) (- j 1)))
                       ((zerop j)
                        (P (- n 1)))
                     (P (- n 1))
                     (F n))))
             (F (n)
               (setf x (revloop x n (list-tail x n)))
               (push x perms))
             (revloop (x n y)
               (if (zerop n) y
                   (revloop (cdr x)
                            (- n 1)
                            (cons (car x) y))))
             (list-tail (x n)
               (if (zerop n) x
                   (list-tail (cdr x) (- n 1)))))
      (P (length x))
      perms)))

(defun iota (n)
  (do ((n n (- n 1))
       (p '() (cons n p)))
      ((zerop n) p)))

(defun run-permutations ()
  (let* ((perms (permutations (iota 9)))
         (sums (mapcar (lambda (l) (reduce '+ l)) perms)))
    (assert (eql 1 (length (remove-duplicates sums))))))




;; Destructive merge of two sorted lists.
;; From Hansen's MS thesis.
(defun merge! (a b predicate)
  (labels ((merge-loop (r a b)
             (cond ((funcall predicate (car b) (car a))
                    (setf (cdr r) b)
                    (if (null (cdr b))
                        (setf (cdr b) a)
                        (merge-loop b a (cdr b))))
                   (t ; (car a) <= (car b)
                    (setf (cdr r) a)
                    (if (null (cdr a))
                        (setf (cdr a) b)
                        (merge-loop a (cdr a) b))))))
    (cond ((null a) b)
          ((null b) a)
          ((funcall predicate (car b) (car a))
           (if (null (cdr b))
               (setf (cdr b) a)
               (merge-loop b a (cdr b)))
           b)
          (t                           ; (car a) <= (car b)
           (if (null (cdr a))
               (setf (cdr a) b)
               (merge-loop a (cdr a) b))
           a))))

;; Stable sort procedure which copies the input list and then sorts
;; the new list imperatively.  On the systems we have benchmarked,
;; this generic list sort has been at least as fast and usually much
;; faster than the library's sort routine.
;; Due to Richard O'Keefe; algorithm attributed to D.H.D. Warren.
(defun sort! (seq predicate)
  (labels ((astep (n)
             (cond ((> n 2)
                    (let* ((j (truncate n 2))
                           (a (astep j))
                           (k (- n j))
                           (b (astep k)))
                      (merge! a b predicate)))
                   ((= n 2)
                    (let ((x (car seq))
                          (y (cadr seq))
                          (p seq))
                      (setf seq (cddr seq))
                      (when (funcall predicate y x)
                        (setf (car p) y)
                        (setf (cadr p) x))
                      (setf (cddr p) nil)
                      p))
                   ((= n 1)
                    (let ((p seq))
                      (setf seq (cdr seq))
                      (setf (cdr p) nil)
                      p))
                   (t nil))))
    (astep (length seq))))


(defun integer-hash (key)
  (declare (type (unsigned-byte 32) key))
  (flet ((u32* (a b) (ldb (byte 32 0) (* a b)))
         (u32-right-shift (integer count)
           (ldb (byte 32 0) (ash integer count))))
    (u32* (u32-right-shift key 3) 2654435761)))

(defun make-big-list (n)
  (let ((list (list)))
    (dotimes (i n)
      (push (integer-hash n) list))
    list))


(defparameter *big-seq-list* nil)
(defparameter *big-mess-list* nil)


;; This setup function is called before the main benchmark function,
;; without an intervening GC. The allocation time here doesn't count
;; towards the benchmark. It's important to avoid an intervening GC,
;; because the compaction resulting from the collector could skew
;; results (esp for /mess below).
(defun setup-walk-list/seq ()
  (setf *big-seq-list* (make-big-list 2000000)))

;; walk the list to calculate its length
(defun walk-list/seq ()
  (let (before after)
    (setf before (length *big-seq-list*))
    (push 42 *big-seq-list*)
    (setf after (length *big-seq-list*))
    (assert (eql after (1+ before)))
    (setq *big-seq-list* nil)))


;; allocate a large list of fixnums, and merge-sort the list so that
;; pointers in the list are maximally spread out over memory.
(defun setup-walk-list/mess ()
  (setf *big-mess-list* (make-big-list 2000000))
  (sort! *big-mess-list* #'<))

(defun walk-list/mess ()
  (let ((before 0)
        (after 0))
    (dolist (i *big-mess-list*)
      (incf before))
    (push 42 *big-mess-list*)
    (dolist (i *big-mess-list*)
      (incf after))
    (assert (eql after (1+ before)))
    (setq *big-mess-list* nil)))


;; EOF
