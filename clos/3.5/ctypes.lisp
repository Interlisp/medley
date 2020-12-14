;;;-*-Mode:LISP; Package: PCL; Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;;

(in-package 'clos)

;;;
;;; The built-in method combination types as taken from page 1-31 of 88-002R.
;;; Note that the STANDARD method combination type is defined by hand in the
;;; file combin.lisp.
;;;

(define-method-combination +      :identity-with-one-argument t)
(define-method-combination and    :identity-with-one-argument t)
(define-method-combination append :identity-with-one-argument nil)
(define-method-combination list   :identity-with-one-argument nil)
(define-method-combination max    :identity-with-one-argument t)
(define-method-combination min    :identity-with-one-argument t)
(define-method-combination nconc  :identity-with-one-argument t)
(define-method-combination or     :identity-with-one-argument t)
(define-method-combination progn  :identity-with-one-argument t)
