;;;-*-Mode:LISP; Package:(CLOS LISP 1000); Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;;

(in-package 'clos)

;;;
;;; pre-allocate generic function caches.  The hope is that this will put
;;; them nicely together in memory, and that that may be a win.  Of course
;;; the first gc copy will probably blow that out, this really wants to be
;;; wrapped in something that declares the area static.
;;;
;;; This preallocation only creates about 25% more caches than CLOS itself
;;; uses need.  Some ports may want to preallocate some more of these.
;;; 
(eval-when (load)
  (flet ((allocate (n size)
	   (mapcar #'free-cache
		   (mapcar #'get-cache
			   (make-list n :initial-element size)))))
    (allocate 128 4)
    (allocate 64 8)
    (allocate 64 9)
    (allocate 32 16)
    (allocate 16 17)
    (allocate 16 32)
    (allocate 1  64)))