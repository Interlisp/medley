;;;-*-Mode:LISP; Package:(CLOS LISP 1000); Base:10; Syntax:Common-lisp -*-
;;;
;;; *************************************************************************
;;; Copyright (c) 1991 Venue
;;; All rights reserved.
;;; *************************************************************************
;;;
;;; The basics of the CLOS wrapper cache mechanism.
;;;

(in-package 'clos)
;;;
;;; The caching algorithm implemented:
;;;
;;; << put a paper here >>
;;;
;;; For now, understand that as far as most of this code goes, a cache has
;;; two important properties.  The first is the number of wrappers used as
;;; keys in each cache line.  Throughout this code, this value is always
;;; called NKEYS.  The second is whether or not the cache lines of a cache
;;; store a value.  Throughout this code, this always called VALUEP.
;;;
;;; Depending on these values, there are three kinds of caches.
;;;
;;; NKEYS = 1, VALUEP = NIL
;;;
;;; In this kind of cache, each line is 1 word long.  No cache locking is
;;; needed since all read's in the cache are a single value.  Nevertheless
;;; line 0 (location 0) is reserved, to ensure that invalid wrappers will
;;; not get a first probe hit.
;;;
;;; To keep the code simpler, a cache lock count does appear in location 0
;;; of these caches, that count is incremented whenever data is written to
;;; the cache.  But, the actual lookup code (see make-dlap) doesn't need to
;;; do locking when reading the cache.
;;; 
;;;
;;; NKEYS = 1, VALUEP = T
;;;
;;; In this kind of cache, each line is 2 words long.  Cache locking must
;;; be done to ensure the synchronization of cache reads.  Line 0 of the
;;; cache (location 0) is reserved for the cache lock count.  Location 1
;;; of the cache is unused (in effect wasted).
;;; 
;;; NKEYS > 1
;;;
;;; In this kind of cache, the 0 word of the cache holds the lock count.
;;; The 1 word of the cache is line 0.  Line 0 of these caches is not
;;; reserved.
;;;
;;; This is done because in this sort of cache, the overhead of doing the
;;; cache probe is high enough that the 1+ required to offset the location
;;; is not a significant cost.  In addition, because of the larger line
;;; sizes, the space that would be wasted by reserving line 0 to hold the
;;; lock count is more significant.
;;;


;;;
;;; Caches
;;;
;;; A cache is essentially just a vector.  The use of the individual `words'
;;; in the vector depends on particular properties of the cache as described
;;; above.
;;;
;;; This defines an abstraction for caches in terms of their most obvious
;;; implementation as simple vectors.  But, please notice that part of the
;;; implementation of this abstraction, is the function lap-out-cache-ref.
;;; This means that most port-specific modifications to the implementation
;;; of caches will require corresponding port-specific modifications to the
;;; lap code assembler.
;;;
(defmacro cache-ref (cache location)
  `(svref (the simple-vector ,cache) (the fixnum ,location)))

(defun emit-cache-ref (cache-operand location-operand)
  (operand :iref cache-operand location-operand))


(defun cache-size (cache)
  (array-dimension (the simple-vector cache) 0))

(defun allocate-cache (size)
  (make-array size :adjustable nil))

(defmacro cache-lock-count (cache)
  `(cache-ref ,cache 0))

(defun flush-cache-internal (cache)
  (without-interrupts  
    (fill (the simple-vector cache) nil)
    (setf (cache-lock-count cache) 0))
  cache)

(defmacro modify-cache (cache &body body)
  `(without-interrupts
     (multiple-value-prog1
       (progn ,@body)
       (let ((old-count (cache-lock-count ,cache)))
	 (setf (cache-lock-count ,cache)
	       (if (= old-count most-positive-fixnum) 1 (1+ old-count)))))))



;;;
;;; Some facilities for allocation and freeing caches as they are needed.
;;; This is done on the assumption that a better port of CLOS will arrange
;;; to cons these all the same static area.  Given that, the fact that
;;; CLOS tries to reuse them should be a win.
;;; 
(defvar *free-caches* (make-hash-table :size 16))

;;;
;;; Return a cache that has had flush-cache-internal called on it.  This
;;; returns a cache of exactly the size requested, it won't ever return a
;;; larger cache.
;;; 
(defun get-cache (size)
  (let ((entry (gethash size *free-caches*)))
    (without-interrupts
      (cond ((null entry)
	     (setf (gethash size *free-caches*) (cons 0 nil))
	     (get-cache size))
	    ((null (cdr entry))
	     (incf (car entry))
	     (flush-cache-internal (allocate-cache size)))
	    (t
	     (let ((cache (cdr entry)))
	       (setf (cdr entry) (cache-ref cache 0))
	       (flush-cache-internal cache)))))))

(defun free-cache (cache)
  (let ((entry (gethash (cache-size cache) *free-caches*)))
    (without-interrupts
      (if (null entry)
	  (error "Attempt to free a cache not allocated by GET-CACHE.")
	  (let ((thread (cdr entry)))
	    (loop (unless thread (return))
		  (when (eq thread cache) (error "Freeing a cache twice."))
		  (setq thread (cache-ref thread 0)))	  
	    (flush-cache-internal cache)		;Help the GC
	    (setf (cache-ref cache 0) (cdr entry))
	    (setf (cdr entry) cache)
	    nil)))))

;;;
;;; This is just for debugging and analysis.  It shows the state of the free
;;; cache resource.
;;; 
(defun show-free-caches ()
  (let ((elements ()))
    (maphash #'(lambda (s e) (push (list s e) elements)) *free-caches*)
    (setq elements (sort elements #'< :key #'car))
    (dolist (e elements)
      (let* ((size (car e))
	     (entry (cadr e))
	     (allocated (car entry))
	     (head (cdr entry))
	     (free 0))
	(loop (when (null head) (return t))
	      (setq head (cache-ref head 0))
	      (incf free))
	(format t
		"~&There  ~4D are caches of size ~4D. (~D free  ~3D%)"
		allocated
		size
		free
		(floor (* 100 (/ free (float allocated)))))))))


;;;
;;; Wrapper cache numbers
;;; 

;;;
;;; The constant WRAPPER-CACHE-NUMBER-ADDS-OK controls the number of non-zero
;;; bits wrapper cache numbers will have.
;;;
;;; The value of this constant is the number of wrapper cache numbers which
;;; can be added and still be certain the result will be a fixnum.  This is
;;; used by all the code that computes primary cache locations from multiple
;;; wrappers.
;;;
;;; The value of this constant is used to derive the next two which are the
;;; forms of this constant which it is more convenient for the runtime code
;;; to use.
;;; 
(eval-when (compile load eval)

(defconstant wrapper-cache-number-adds-ok 4)

(defconstant wrapper-cache-number-length
	     (- (integer-length most-positive-fixnum)
		wrapper-cache-number-adds-ok))

(defconstant wrapper-cache-number-mask
	     (1- (expt 2 wrapper-cache-number-length)))


(defvar *get-wrapper-cache-number* (make-random-state))

(defun get-wrapper-cache-number ()
  (let ((n 0))
    (loop
      (setq n
	    (logand wrapper-cache-number-mask
		    (random most-positive-fixnum *get-wrapper-cache-number*)))
      (unless (zerop n) (return n)))))


(unless (> wrapper-cache-number-length 8)
  (error "In this implementation of Common Lisp, fixnums are so small that~@
          wrapper cache numbers end up being only ~D bits long.  This does~@
          not actually keep CLOS from running, but it may degrade cache~@
          performance.~@
          You may want to consider changing the value of the constant~@
          WRAPPER-CACHE-NUMBER-ADDS-OK.")))


;;;
;;; wrappers themselves
;;;
;;; This caching algorithm requires that wrappers have more than one wrapper
;;; cache number.  You should think of these multiple numbers as being in
;;; columns.  That is, for a given cache, the same column of wrapper cache
;;; numbers will be used.
;;;
;;; If at some point the cache distribution of a cache gets bad, the cache
;;; can be rehashed by switching to a different column.
;;;
;;; The columns are referred to by field number which is that number which,
;;; when used as a second argument to wrapper-ref, will return that column
;;; of wrapper cache number.
;;;
;;; This code is written to allow flexibility as to how many wrapper cache
;;; numbers will be in each wrapper, and where they will be located.  It is
;;; also set up to allow port specific modifications to `pack' the wrapper
;;; cache numbers on machines where the addressing modes make that a good
;;; idea.
;;; 
(eval-when (compile load eval)
(defconstant wrapper-layout
	     '(number
	       number
	       number
	       number
	       number
	       number
	       number
	       number
	       state
	       instance-slots-layout
	       class-slots
	       class))
)

(eval-when (compile load eval)

(defun wrapper-field (type)
  (position type wrapper-layout))

(defun next-wrapper-field (field-number)
  (position (nth field-number wrapper-layout)
	    wrapper-layout
	    :start (1+ field-number)))

);eval-when

(defmacro wrapper-ref (wrapper n)
  `(svref ,wrapper ,n))

(defun emit-wrapper-ref (wrapper-operand field-operand)
  (operand :iref wrapper-operand field-operand))

	      
(defmacro wrapper-state (wrapper)
  `(wrapper-ref ,wrapper ,(wrapper-field 'state)))

(defmacro wrapper-instance-slots-layout (wrapper)
  `(wrapper-ref ,wrapper ,(wrapper-field 'instance-slots-layout)))

(defmacro wrapper-class-slots (wrapper)
  `(wrapper-ref ,wrapper ,(wrapper-field 'class-slots)))

(defmacro wrapper-class (wrapper)
  `(wrapper-ref ,wrapper ,(wrapper-field 'class)))


(defmacro make-wrapper-internal ()
  `(let ((wrapper (make-array ,(length wrapper-layout) :adjustable nil)))
     ,@(gathering1 (collecting)
	 (iterate ((i (interval :from 0))
		   (desc (list-elements wrapper-layout)))
	   (ecase desc
	     (number
	      (gather1 `(setf (wrapper-ref wrapper ,i)
			      (get-wrapper-cache-number))))
	     ((state instance-slots-layout class-slots class)))))
     (setf (wrapper-state wrapper) 't)     
     wrapper))

(defun make-wrapper (class)
  (let ((wrapper (make-wrapper-internal)))
    (setf (wrapper-class wrapper) class)
    wrapper))

;;;
;;; The wrapper cache machinery provides general mechanism for trapping on
;;; the next access to any instance of a given class.  This mechanism is
;;; used to implement the updating of instances when the class is redefined
;;; (make-instances-obsolete).  The same mechanism is also used to update
;;; generic function caches when there is a change to the supers of a class.
;;;
;;; Basically, a given wrapper can be valid or invalid.  If it is invalid,
;;; it means that any attempt to do a wrapper cache lookup using the wrapper
;;; should trap.  Also, methods on slot-value-using-class check the wrapper
;;; validity as well.  This is done by calling check-wrapper-validity.
;;; 

(defun invalid-wrapper-p (wrapper)
  (neq (wrapper-state wrapper) 't))

(defvar *previous-nwrappers* (make-hash-table))

(defun invalidate-wrapper (owrapper state nwrapper)
  (ecase state
    ((flush obsolete)
     (let ((new-previous ()))
       ;;
       ;; First off, a previous call to invalidate-wrapper may have recorded
       ;; owrapper as an nwrapper to update to.  Since owrapper is about to
       ;; be invalid, it no longer makes sense to update to it.
       ;;
       ;; We go back and change the previously invalidated wrappers so that
       ;; they will now update directly to nwrapper.  This corresponds to a
       ;; kind of transitivity of wrapper updates.
       ;; 
       (dolist (previous (gethash owrapper *previous-nwrappers*))
	 (when (eq state 'obsolete)
	   (setf (car previous) 'obsolete))
	 (setf (cadr previous) nwrapper)
	 (push previous new-previous))
       
       (iterate ((type (list-elements wrapper-layout))
		 (i (interval :from 0)))
	 (when (eq type 'number) (setf (wrapper-ref owrapper i) 0)))
       (push (setf (wrapper-state owrapper) (list state nwrapper))
	     new-previous)
       
       (setf (gethash owrapper *previous-nwrappers*) ()
	     (gethash nwrapper *previous-nwrappers*) new-previous)))))

(defun check-wrapper-validity (instance)
  (let* ((owrapper (wrapper-of instance))
	 (state (wrapper-state owrapper)))
    (if (eq state  't)
	owrapper
	(let ((nwrapper
		(ecase (car state)
		  (flush
		    (flush-cache-trap owrapper (cadr state) instance))
		  (obsolete
		    (obsolete-instance-trap owrapper (cadr state) instance)))))
	  ;;
	  ;; This little bit of error checking is superfluous.  It only
	  ;; checks to see whether the person who implemented the trap
	  ;; handling screwed up.  Since that person is hacking internal
	  ;; CLOS code, and is not a user, this should be needless.  Also,
	  ;; since this directly slows down instance update and generic
	  ;; function cache refilling, feel free to take it out sometime
	  ;; soon.
	  ;; 
	  (cond ((neq nwrapper (wrapper-of instance))
		 (error "Wrapper returned from trap not wrapper of instance."))
		((invalid-wrapper-p nwrapper)
		 (error "Wrapper returned from trap invalid.")))
	  nwrapper))))



(defun compute-line-size (nelements) (expt 2 (ceiling (log nelements 2))))

(defun compute-cache-parameters (nkeys valuep nlines-or-cache)
  (declare (values cache-mask actual-size line-size nlines))
  (flet ((compute-mask (cache-size line-size)
	   (logxor (1- cache-size) (1- line-size))))
    (if (= nkeys 1)
	(let* ((line-size (if valuep 2 1))
	       (cache-size (if (numberp nlines-or-cache)
			       (* line-size
				  (expt 2 (ceiling (log nlines-or-cache 2))))
			       (cache-size nlines-or-cache))))
	  (values (compute-mask cache-size line-size)
		  cache-size
		  line-size
		  (/ cache-size line-size)))
	(let* ((line-size (compute-line-size (+ nkeys (if valuep 1 0))))
	       (cache-size (if (numberp nlines-or-cache)
			       (* line-size 
				  (expt 2 (ceiling (log nlines-or-cache 2))))
			       (1- (cache-size nlines-or-cache)))))
	  (values (compute-mask cache-size line-size)
		  (1+ cache-size)
		  line-size
		  (/ cache-size line-size))))))



;;;
;;; The various implementations of computing a primary cache location from
;;; wrappers.  Because some implementations of this must run fast there are
;;; several implementations of the same algorithm.
;;;
;;; The algorithm is:
;;;
;;;  SUM       over the wrapper cache numbers,
;;;  ENSURING  that the result is a fixnum
;;;  MASK      the result against the mask argument.
;;;
;;;

;;;
;;; COMPUTE-PRIMARY-CACHE-LOCATION
;;; 
;;; The basic functional version.  This is used by the cache miss code to
;;; compute the primary location of an entry.  
;;;
(defun compute-primary-cache-location (field mask wrappers)
  (if (not (consp wrappers))
      (logand mask (wrapper-ref wrappers field))
      (let ((location 0))
	(iterate ((wrapper (list-elements wrappers))
		  (i (interval :from 0)))
	  ;;
	  ;; First add the cache number of this wrapper to location.
	  ;; 
	  (let ((wrapper-cache-number (wrapper-ref wrapper field)))
	    (if (zerop wrapper-cache-number)
		(return-from compute-primary-cache-location 0)
		(setq location (+ location wrapper-cache-number))))
	  ;;
	  ;; Then, if we are working with lots of wrappers, deal with
	  ;; the wrapper-cache-number-mask stuff.
	  ;; 
	  (when (and (not (zerop i))
		     (zerop (mod i wrapper-cache-number-adds-ok)))
	    (setq location
		  (logand location wrapper-cache-number-mask))))
	(1+ (logand mask location)))))

;;;
;;; COMPUTE-PRIMARY-CACHE-LOCATION-FROM-LOCATION
;;;
;;; This version is called on a cache line.  It fetches the wrappers from
;;; the cache line and determines the primary location.  Various parts of
;;; the cache filling code call this to determine whether it is appropriate
;;; to displace a given cache entry.
;;; 
;;; If this comes across a wrapper whose cache-no is 0, it returns the symbol
;;; invalid to suggest to its caller that it would be provident to blow away
;;; the cache line in question.
;;;
(defun compute-primary-cache-location-from-location (field cache location mask nkeys)
  (let ((result 0))
    (dotimes (i nkeys)
      (let* ((wrapper (cache-ref cache (+ i location)))
	     (wcn (wrapper-ref wrapper field)))
	(setq result (+ result wcn)))
      (when (and (not (zerop i))
		 (zerop (mod i wrapper-cache-number-adds-ok)))
	(setq result (logand result wrapper-cache-number-mask)))
      )    
    (if (= nkeys 1)
	(logand mask result)
	(1+ (logand mask result)))))

(defun emit-1-wrapper-compute-primary-cache-location (wrapper primary wrapper-cache-no)
  (with-lap-registers ((mask index))
    (let ((field wrapper-cache-no))
      (flatten-lap
        (opcode :move (operand :cvar 'mask) mask)
        (opcode :move (operand :cvar 'field) field)
        (opcode :move (emit-wrapper-ref wrapper field) wrapper-cache-no)
        (opcode :move (operand :ilogand wrapper-cache-no mask) primary)))))

(defun emit-n-wrapper-compute-primary-cache-location (wrappers primary miss-label)
  (with-lap-registers ((field index)
		       (mask index))
    (let ((add-wrapper-cache-numbers
	   (flatten-lap
	    (gathering1 (flattening-lap)
	       (iterate ((wrapper (list-elements wrappers))
			 (i (interval :from 1)))
		 (gather1
		  (with-lap-registers ((wrapper-cache-no index))
		    (flatten-lap
		     (opcode :move (emit-wrapper-ref wrapper field) wrapper-cache-no)
		     (opcode :izerop wrapper-cache-no miss-label)
		     (opcode :move (operand :i+ primary wrapper-cache-no) primary)
		     (when (zerop (mod i wrapper-cache-number-adds-ok))
		       (opcode :move (operand :ilogand primary mask) primary))))))))))
      (flatten-lap
       (opcode :move (operand :constant 0) primary)
       (opcode :move (operand :cvar 'field) field)
       (opcode :move (operand :cvar 'mask) mask)
       add-wrapper-cache-numbers
       (opcode :move (operand :ilogand primary mask) primary)
       (opcode :move (operand :i1+ primary) primary)))))



;;;
;;;  NIL              means nothing so far, no actual arg info has NILs
;;;                   in the metatype
;;;  CLASS            seen all sorts of metaclasses
;;;                   (specifically, more than one of the next 4 values)
;;;  T                means everything so far is the class T
;;;  STANDARD-CLASS   seen only standard classes
;;;  BUILT-IN-CLASS   seen only built in classes
;;;  STRUCTURE-CLASS  seen only structure classes
;;;  
(defun raise-metatype (metatype new-specializer)
  (let ((standard  (find-class 'standard-class))
	(fsc       (find-class 'funcallable-standard-class))
;	(structure (find-class 'structure-class))
	(built-in  (find-class 'built-in-class)))
    (flet ((specializer->metatype (x)
	     (let ((meta-specializer 
		     (if (and (eq *boot-state* 'complete)
			      (eql-specializer-p x))
			 (class-of (class-of (eql-specializer-object x)))
			 (class-of x))))
	       (cond ((eq x *the-class-t*) t)
		     ((*subtypep meta-specializer standard)  'standard-instance)
		     ((*subtypep meta-specializer fsc)       'standard-instance)
;                    ((*subtypep meta-specializer structure) 'structure-instance)
		     ((*subtypep meta-specializer built-in)  'built-in-instance)
		     (t (error "CLOS can not handle the specializer ~S (meta-specializer ~S)."
			       new-specializer meta-specializer))))))
      ;;
      ;; We implement the following table.  The notation is
      ;; that X and Y are distinct meta specializer names.
      ;; 
      ;;   NIL    <anything>    ===>  <anything>
      ;;    X      X            ===>      X
      ;;    X      Y            ===>    CLASS
      ;;    
      (let ((new-metatype (specializer->metatype new-specializer)))
	(cond ((null metatype) new-metatype)
	      ((eq metatype new-metatype) new-metatype)
	      (t 'class))))))


(defun emit-fetch-wrapper (metatype argument dest miss-label &optional slot)
  (let ((exit-emit-fetch-wrapper (make-symbol "exit-emit-fetch-wrapper")))
    (with-lap-registers ((arg t))
      (ecase metatype
	(standard-instance
	  (let ((get-std-inst-wrapper (make-symbol "get-std-inst-wrapper"))
		(get-fsc-inst-wrapper (make-symbol "get-fsc-inst-wrapper")))
	    (flatten-lap
	      (opcode :move (operand :arg argument) arg)
	      (opcode :std-instance-p arg get-std-inst-wrapper)	   ;is it a std wrapper?
	      (opcode :fsc-instance-p arg get-fsc-inst-wrapper)	   ;is it a fsc wrapper?
	      (opcode :go miss-label)
	      (opcode :label get-fsc-inst-wrapper)
	      (opcode :move (operand :fsc-wrapper arg) dest)	   ;get fsc wrapper
	      (and slot
		   (opcode :move (operand :fsc-slots arg) slot))
	      (opcode :go exit-emit-fetch-wrapper)
	      (opcode :label get-std-inst-wrapper)
	      (opcode :move (operand :std-wrapper arg) dest)	   ;get std wrapper
	      (and slot
		   (opcode :move (operand :std-slots arg) slot))
	      (opcode :label exit-emit-fetch-wrapper))))

	(class
	  (when slot (error "Can't do a slot reg for this metatype."))
	  (let ((get-std-inst-wrapper (make-symbol "get-std-inst-wrapper"))
		(get-fsc-inst-wrapper (make-symbol "get-fsc-inst-wrapper"))
		(get-built-in-wrapper (make-symbol "get-built-in-wrapper")))
	    (flatten-lap
	      (opcode :move (operand :arg argument) arg)
	      (opcode :std-instance-p arg get-std-inst-wrapper)
	      (opcode :fsc-instance-p arg get-fsc-inst-wrapper)
	      (opcode :built-in-instance-p arg get-built-in-wrapper)
	      ;; If the code falls through the checks above, there is a serious problem
	      (opcode :label get-fsc-inst-wrapper)
	      (opcode :move (operand :fsc-wrapper arg) dest)
	      (opcode :go exit-emit-fetch-wrapper)
	      (opcode :label get-built-in-wrapper)
	      (opcode :move (operand :built-in-wrapper arg) dest)
	      (opcode :go exit-emit-fetch-wrapper)
	      (opcode :label get-std-inst-wrapper)
	      (opcode :move (operand :std-wrapper arg) dest)
	      (opcode :label exit-emit-fetch-wrapper))))
	(structure-instance 
	  (when slot (error "Can't do a slot reg for this metatype."))
	  (error "Not yet implemented"))
	(built-in-instance
	  (when slot (error "Can't do a slot reg for this metatype."))
	  (let ((get-built-in-wrapper (make-symbol "get-built-in-wrapper")))
	    (flatten-lap
	      (opcode :move (operand :arg argument) arg)
	      (opcode :built-in-instance-p arg get-built-in-wrapper)
	      (opcode :go miss-label)
	      (opcode :label get-built-in-wrapper)
	      (opcode :move (operand :built-in-wrapper arg) dest))))))))


;;;
;;; Some support stuff for getting a hold of symbols that we need when
;;; building the discriminator codes.  Its ok for these to be interned
;;; symbols because we don't capture any user code in the scope in which
;;; these symbols are bound.
;;; 

(defvar *dfun-arg-symbols* '(.ARG0. .ARG1. .ARG2. .ARG3.))

(defun dfun-arg-symbol (arg-number)
  (or (nth arg-number (the list *dfun-arg-symbols*))
      (intern (format nil ".ARG~A." arg-number) *the-clos-package*)))

(defvar *slot-vector-symbols* '(.SLOTS0. .SLOTS1. .SLOTS2. .SLOTS3.))

(defun slot-vector-symbol (arg-number)
  (or (nth arg-number (the list *slot-vector-symbols*))
      (intern (format nil ".SLOTS~A." arg-number) *the-clos-package*)))

(defun make-dfun-lambda-list (metatypes applyp)
  (gathering1 (collecting)
    (iterate ((i (interval :from 0))
	      (s (list-elements metatypes)))
      (progn s)
      (gather1 (dfun-arg-symbol i)))
    (when applyp
      (gather1 '&rest)
      (gather1 '.dfun-rest-arg.))))

(defun make-dlap-lambda-list (metatypes applyp)
  (gathering1 (collecting)
    (iterate ((i (interval :from 0))
	      (s (list-elements metatypes)))
      (progn s)
      (gather1 (dfun-arg-symbol i)))
    (when applyp
      (gather1 '&rest))))

(defun make-dfun-call (metatypes applyp fn-variable)
  (let ((required
	  (gathering1 (collecting)
	    (iterate ((i (interval :from 0))
		      (s (list-elements metatypes)))
	      (progn s)
	      (gather1 (dfun-arg-symbol i))))))
    (if applyp
	`(apply   ,fn-variable ,@required .dfun-rest-arg.)
	`(funcall ,fn-variable ,@required))))


;;;
;;; Here is where we actually fill, recache and expand caches.
;;;
;;; The function FILL-CACHE is the ONLY external entrypoint into this code.
;;; It returns 4 values:
;;;   a wrapper field number
;;;   a cache
;;;   a mask
;;;   an absolute cache size (the size of the actual vector)
;;;
;;;
(defun fill-cache (field cache nkeys valuep limit-fn wrappers value)
  (declare (values field cache mask size))
  (fill-cache-internal field cache nkeys valuep limit-fn wrappers value))

(defun default-limit-fn (nlines)
  (case nlines
    ((1 2 4) 1)
    ((8 16)  4)
    (otherwise 6)))


;;;
;;; Its too bad Common Lisp compilers freak out when you have a defun with
;;; a lot of LABELS in it.  If I could do that I could make this code much
;;; easier to read and work with.
;;;
;;; Ahh Scheme...
;;; 
;;; In the absence of that, the following little macro makes the code that
;;; follows a little bit more reasonable.  I would like to add that having
;;; to practically write my own compiler in order to get just this simple
;;; thing is something of a drag.
;;;
(eval-when (compile load eval)

(proclaim '(special *nkeys* *valuep* *limit-fn*))

;;; This patch avoids a bug in the ENVCALL instruction. Lookup of free
;;; variables under ENVCALL always results in nil. In particular, the
;;; compiler generates such code for flet and friends. Therefore, some
;;; macros must be defined at top-level.

;(defmacro cache     () '.cache.)
;(defmacro nkeys () '*nkeys*)
;(defmacro valuep    () '*valuep*)
;(defmacro limit-fn  () '*limit-fn*)
;(defmacro line-size () '.line-size.)
;(defmacro mask      () '.mask.)
;(defmacro size      () '.size.)
;(defmacro nlines    () '.nlines.)
;(defmacro line-reserved-p (line)
;            `(and (= (nkeys) 1)
;                 (= ,line 0)))
;(defmacro line-location (line)
;            `(and (null (line-reserved-p ,line))
;                 (if (= (nkeys) 1)
;                     (* ,line (line-size))
;                     (1+ (* ,line (line-size))))))
;(defmacro location-line (location)
;            `(if (= (nkeys) 1)
;                (/ ,location (line-size))
;                (/ (1- ,location) (line-size))))
;end patch

(defvar *local-cache-functions*
	`((cache     () .cache.)
	  (nkeys     () *nkeys*)
	  (valuep    () *valuep*)
	  (limit-fn  () *limit-fn*)
	  (line-size () .line-size.)
	  (mask      () .mask.)
	  (size      () .size.)
	  (nlines    () .nlines.)
	  ;;
	  ;; Return T IFF this cache location is reserved.  The only time
	  ;; this is true is for line number 0 of an nkeys=1 cache.  
	  ;;
	  (line-reserved-p (line)
	    (and (= (nkeys) 1)
		 (= line 0))) 
	  ;;
	  ;; Given a line number, return the cache location.  This is the
	  ;; value that is the second argument to cache-ref.  Basically,
	  ;; this deals with the offset of nkeys>1 caches and multiplies
	  ;; by line size.  This returns nil if the line is reserved.
	  ;; 	  
	  (line-location (line)
	    (and (null (line-reserved-p line))
		 (if (= (nkeys) 1)
		     (* line (line-size))
		     (1+ (* line (line-size)))))) 
	  ;;
	  ;; Given a cache location, return the line.  This is the inverse
	  ;; of LINE-LOCATION.
	  ;; 	  
	  (location-line (location)
	    (if (= (nkeys) 1)
		(/ location (line-size))
		(/ (1- location) (line-size)))) 
	  ;;
	  ;; Given a line number, return the wrappers stored at that line.
	  ;; As usual, if nkeys=1, this returns a single value.  Only when
	  ;; nkeys>1 does it return a list.  An error is signalled if the
	  ;; line is reserved.
	  ;;
	  (line-wrappers (line)
	    (when (line-reserved-p line) (error "Line is reserved."))
	    (let ((location (line-location line)))
	      (if (= (nkeys) 1)
		  (cache-ref (cache) location)
		  (gathering1 (collecting)
		    (dotimes (i (nkeys))
		      (gather1 (cache-ref (cache) (+ location i))))))))
	  ;;
	  ;; Given a line number, return the value stored at that line.
	  ;; If valuep is NIL, this returns NIL.  As with line-wrappers,
	  ;; an error is signalled if the line is reserved.
	  ;; 
	  (line-value (line)
	    (when (line-reserved-p line) (error "Line is reserved."))
	    (and (valuep)
		 (cache-ref (cache) (+ (line-location line) (nkeys)))))
	  ;;
	  ;; Given a line number, return true IFF that line has data in
	  ;; it.  The state of the wrappers stored in the line is not
	  ;; checked.  An error is signalled if line is reserved.
	  (line-full-p (line)
	    (when (line-reserved-p line) (error "Line is reserved."))
	    (not (null (cache-ref (cache) (line-location line)))))
	  ;;
	  ;; Given a line number, return true IFF the line is full and
	  ;; there are no invalid wrappers in the line, and the line's
	  ;; wrappers are different from wrappers.
	  ;; An error is signalled if the line is reserved.
	  ;;
	  (line-valid-p (line wrappers)
	    (when (line-reserved-p line) (error "Line is reserved."))
	    (let ((loc (line-location line)))
	      (dotimes (i (nkeys) t)
		(let ((wrapper (cache-ref (cache) (+ loc i))))
		  (when (or (null wrapper)
;***					(numberp wrapper)
					;Think of this as an optimized:
					; (and (zerop i)
					;      (= (nkeys) 1)
					;      (null (valuep))
					;      (numberp wrapper))
                            (invalid-wrapper-p wrapper))
                    (return nil))))))
	  ;;
	  ;; How many unreserved lines separate line-1 and line-2.
	  ;;
	  (line-separation (line-1 line-2)
	    (let ((diff (- line-2 line-1)))
	      (cond ((zerop diff) diff)
		    ((plusp diff) diff)
		    (t
		     (if (line-reserved-p 0)
			 (1- (+ (- (nlines) line-1) line-2))
			 (+ (- (nlines) line-1) line-2))))))
	  ;;
	  ;; Given a cache line, get the next cache line.  This will not
	  ;; return a reserved line.
	  ;; 
	  (next-line (line)
	    (if (= line (1- (nlines)))
		(if (line-reserved-p 0) 1 0)
		(1+ line)))
	  ;;
	  ;; Given a line which has a valid entry in it, this will return
	  ;; the primary cache line of the wrappers in that line.  We just
	  ;; call COMPUTE-PRIMARY-CACHE-LOCATION-FROM-LOCATION, this is an
	  ;; easier packaging up of the call to it.
	  ;; 
	  (line-primary (field line)
	    (location-line
	      (compute-primary-cache-location-from-location
		field (cache) (line-location line) (mask) (nkeys))))
	  ;;
	  ;;
	  (fill-line (line wrappers value)
	    (when (line-reserved-p line)
	      (error "Attempt to fill a reserved line."))
	    (let ((loc (line-location line)))
	      (cond ((= (nkeys) 1)
		     (setf (cache-ref (cache) loc) wrappers)
		     (when (valuep) (setf (cache-ref (cache) (1+ loc)) value)))
		    (t
		     (iterate ((i (interval :from 0))
			       (w (list-elements wrappers)))
		       (setf (cache-ref (cache) (+ loc i)) w))
		     (when (valuep) (setf (cache-ref (cache) (+ loc (nkeys))) value))))))
	  ;;
	  ;; Blindly copy the contents of one cache line to another.  The
	  ;; contents of the <to> line are overwritten, so whatever was in
	  ;; there should already have been moved out.
	  ;;
	  ;; For convenience in debugging, this also clears out the from
	  ;; location after it has been copied.
	  ;;
	  (copy-line (from to)
	    (if (line-reserved-p to)
		(error "Copying something into a reserved cache line.")
		(let ((from-loc (line-location from))
		      (to-loc (line-location to)))
		  (modify-cache (cache)
		    (dotimes (i (line-size))
		      (setf (cache-ref (cache) (+ to-loc i))
			    (cache-ref (cache) (+ from-loc i)))
		      (setf (cache-ref (cache) (+ from-loc i))
			    nil))))))
	  ;;
	  ;;
	  ;;
	  (transfer-line (from-cache from-line to-cache to-line)
	    (if (line-reserved-p to-line)
		(error "transfering something into a reserved cache line.")
		(let ((from-loc (line-location from-line))
		      (to-loc (line-location to-line)))
		  (modify-cache to-cache
		    (dotimes (i (line-size))
		      (setf (cache-ref to-cache (+ to-loc i))
			    (cache-ref from-cache (+ from-loc i))))))))
	  ))

(defmacro with-local-cache-functions ((cache) &body body &environment env)
  `(let ((.cache. ,cache))
     (declare (type simple-vector .cache.))
     (multiple-value-bind (.mask. .size. .line-size. .nlines.)
	 (compute-cache-parameters *nkeys* *valuep* .cache.)
       (declare (type fixnum .mask. .size. .line-size. .nlines.))
       (progn .mask. .size. .line-size. .nlines.)
       (labels ,(mapcar #'(lambda (fn) (assq fn *local-cache-functions*))
			(pickup-local-cache-functions body env))
	 ,@body))))

(defun pickup-local-cache-functions (body env)
  (let ((functions ())
	(possible-functions (mapcar #'car *local-cache-functions*)))
    (labels ((walk-function (form context env)
	       (declare (ignore env))
	       (when (and (eq context :eval)
			  (consp form)
			  (symbolp (car form)))
		 (let ((name (car form)))
		   (when (and (not (memq name functions))
			      (memq name possible-functions))
		     (pushnew name functions)
		     (walk (cddr (assq name *local-cache-functions*))))))
	       form)
	     (walk (body)
	       (walk-form `(progn . ,body) env #'walk-function)))
      (walk body)
      functions)))

)


;;;
;;; returns 4 values, <field> <cache> <mask> <size>
;;; It tries to re-adjust the cache every time it makes a new fill.  The
;;; intuition here is that we want uniformity in the number of probes needed to
;;; find an entry.  Furthermore, adjusting has the nice property of throwing out
;;; any entries that are invalid.
;;;
(defun fill-cache-internal (field cache nkeys valuep limit-fn wrappers value)
  (let ((*nkeys* nkeys)
	(*valuep* valuep)
	(*limit-fn* limit-fn))
    (with-local-cache-functions (cache)
      (flet ((4-values-please (f c)
	       (multiple-value-bind (mask size)
		   (compute-cache-parameters *nkeys* *valuep* c)
		 (values f c mask size))))
	(let ((easy-fill-p (fill-cache-p nil field cache wrappers value)))
	  (if easy-fill-p
	      (4-values-please field cache)
	      (multiple-value-bind (adj-field adj-cache)
		  (adjust-cache field cache wrappers value)
		(if adj-field
		    (4-values-please adj-field adj-cache)
		    (multiple-value-bind (exp-field exp-cache)
			(expand-cache field cache wrappers value)
		      (4-values-please exp-field exp-cache))))))))))

;;;
;;; returns T or NIL
;;;
(defun fill-cache-p (forcep field cache wrappers value)
  (with-local-cache-functions (cache)
    (let* ((primary (location-line (compute-primary-cache-location field (mask) wrappers))))
      (multiple-value-bind (free emptyp)
	  (find-free-cache-line primary field cache wrappers)
	(when (or forcep emptyp) (fill-line free wrappers value) t)))))

(defun fill-cache-from-cache-p (forcep field cache from-cache from-line)
  (with-local-cache-functions (from-cache)
    (let ((primary (line-primary field from-line)))
      (multiple-value-bind (free emptyp)
	  (find-free-cache-line primary field cache)
	(when (or forcep emptyp)
	  (transfer-line from-cache from-line cache free)
	  t)))))

(defun entry-in-cache-p (field cache wrappers value)
  (declare (ignore field value))
  (with-local-cache-functions (cache)
    (dotimes (i (nlines))
      (unless (line-reserved-p i)
	(when (equal (line-wrappers i) wrappers) (return t))))))

;;;
;;; Returns NIL or (values <field> <cache>)
;;; 
;;; This is only called when it isn't possible to put the entry in the cache
;;; the easy way.  That is, this function assumes that FILL-CACHE-P has been
;;; called as returned NIL.
;;;
;;; If this returns NIL, it means that it wasn't possible to find a wrapper
;;; field for which all of the entries could be put in the cache (within the
;;; limit).  
;;;
(defun adjust-cache (field cache wrappers value)
  (with-local-cache-functions (cache)
    (let ((ncache (get-cache (size))))
      (do ((nfield field (next-wrapper-field nfield)))
	  ((null nfield) (free-cache ncache) nil)
	(labels ((try-one-fill-from-line (line)
		   (fill-cache-from-cache-p nil nfield ncache cache line))
		 (try-one-fill (wrappers value)
		   (fill-cache-p nil nfield ncache wrappers value)))
	  (if (and (dotimes (i (nlines) t)
		     (when (and (null (line-reserved-p i))
				(line-valid-p i wrappers))
		       (unless (try-one-fill-from-line i) (return nil))))
		   (try-one-fill wrappers value))
	      (return (values nfield ncache))
	      (flush-cache-internal ncache)))))))

		       
;;;
;;; returns: (values <field> <cache>)
;;;
(defun expand-cache (field cache wrappers value)
  (declare (values field cache) (ignore field))
  (with-local-cache-functions (cache)
    (multiple-value-bind (ignore size)
	(compute-cache-parameters (nkeys) (valuep) (* (nlines) 2))
      (let* ((ncache (get-cache size))
	     (nfield (wrapper-field 'number)))
	(labels ((do-one-fill-from-line (line)
		   (unless (fill-cache-from-cache-p nil nfield ncache cache line)
		     (do-one-fill (line-wrappers line) (line-value line))))
		 (do-one-fill (wrappers value)
		   (multiple-value-bind (adj-field adj-cache)
		       (adjust-cache nfield ncache wrappers value)
		     (if adj-field
			 (setq nfield adj-field ncache adj-cache)
			 (fill-cache-p t nfield ncache wrappers value))))
		 (try-one-fill (wrappers value)
		   (fill-cache-p nil nfield ncache wrappers value)))
	  (dotimes (i (nlines))
	    (when (and (null (line-reserved-p i))
		       (line-valid-p i wrappers))
	      (do-one-fill-from-line i)))
	  (unless (try-one-fill wrappers value)
	    (do-one-fill wrappers value))
	  (values nfield ncache))))))


;;;
;;; This is the heart of the cache filling mechanism.  It implements the decisions
;;; about where entries are placed.
;;; 
;;; Find a line in the cache at which a new entry can be inserted.
;;;
;;;   <line>
;;;   <empty?>           is <line> in fact empty?
;;;
(defun find-free-cache-line (primary field cache &optional wrappers)
  (declare (values line empty?))
  (with-local-cache-functions (cache)
    (let ((limit (funcall (limit-fn) (nlines)))
	  (wrappedp nil))
      (when (line-reserved-p primary) (setq primary (next-line primary)))
      (labels (;;
	       ;; Try to find a free line starting at <start>.  <primary>
	       ;; is the primary line of the entry we are finding a free
	       ;; line for, it is used to compute the seperations.
	       ;;
	       (find-free (p s)
		 (do* ((line s (next-line line))
		       (nsep (line-separation p s) (1+ nsep)))
		      (())
		   (if (null (line-valid-p line wrappers)) ;If this line is empty or
		       (return (values line t))	           ;invalid, just use it.

		       (let ((osep (line-separation (line-primary field line) line)))
			 (if (and wrappedp (>= line primary))
			     ;;
			     ;; have gone all the way around the cache, time to quit
			     ;; 
			     (return (values line nil))
			     
			     (when (cond ((or (= nsep limit)) t)
					 ((= nsep osep) (zerop (random 2)))
					 ((> nsep osep) t)
					 (t nil))
			       ;;
			       ;; Try to displace what is in this line so that we
			       ;; can use the line.
			       ;;
			       (return (values line (displace line)))))))
		   
		   (if (= line (1- (nlines))) (setq wrappedp t))))
	       ;;
	       ;; Given a line, attempt to free up that line by moving its
	       ;; contents elsewhere. Returns nil when it wasn't possible to
	       ;; move the contents of the line without dumping something on
	       ;; the floor.  
	       ;; 
	       (displace (line)
		 (if (= line (1- (nlines))) (setq wrappedp t))
		 (multiple-value-bind (dline dempty?)
		     (find-free (line-primary field line) (next-line line))
		   (when dempty? (copy-line line dline) t))))
	
	(find-free primary primary)))))
