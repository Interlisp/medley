;;; richards.lisp -- operating system simulation code
;;
;; Time-stamp: <2003-12-30 emarsden>


;; ======================================================================
;; Newsgroups: comp.lang.smalltalk
;; Distribution: comp
;; Subject: Smalltalk vs. C(++) performance
;; 
;; As some have pointed out, it is difficult to compare the runtime
;; performance of Smalltalk programs with the performance of equivalent C
;; programs.  One reason for this is that for most non-trivial programs
;; there is no equivalent program written in the other language (because
;; it would be a non-trivial effort to write it).
;; 
;; The "best" benchmark I know of is the Richards benchmark, an operating
;; system simulation.  It is written in an object-oriented style, uses
;; polymorphism, and is reasonably non-trivial (700 lines).  It's
;; probably not the world's greatest benchmark, but better than 
;; micro-benchamrks, and it is available in Smalltalk, Self, T (an
;; object-oriented version of Scheme) and C++.
;; 
;; [Historical note: the Richards benchmark was originally written in
;; BCPL by Mark Richards.  Many thanks to L. Peter Deutsch for the
;; Smalltalk version.]
;; 
;; Disclaimer: Richards is *not* a typical application: it is relatively
;; small and contains no graphics or other user interaction.  Thus it may
;; not reflect the relative performance of Your Own Real-World (TM)
;; Application, but I think it tests the efficiency of the basic language
;; mechanisms fairly well.


(in-package :cl-bench.richards)


(eval-when (:compile-toplevel :load-toplevel :execute)
  (defconstant deviceA 5)
  (defconstant deviceB 6)
  (defconstant devicePacketKind 1)
  (defconstant handlerA 3)
  (defconstant handlerB 4)
  (defconstant idler 1)
  (defconstant noWork nil)
  (defconstant noTask nil)
  (defconstant worker 2)
  (defconstant workPacketKind 2))

(defvar taskList noTask)
(defvar currentTask nil)
(defvar currentTaskIdentity nil)
(defvar taskTable (make-array 6 :initial-element noTask))
(declaim (simple-vector taskTable))
(defvar tracing nil)
(defvar layout 0)
(defvar queuePacketCount 0)
(defvar holdCount 0)
(declaim (fixnum layout queuePacketCount holdCount))

(declaim (inline make-taskControlBlock make-packet make-deviceTaskDataRecord
		 make-handlerTaskDataRecord make-idleTaskDataRecord
		 make-workerTaskDataRecord wait))

(defstruct (taskControlBlock (:constructor make-taskControlBLock ()))
  packetPending taskWaiting taskHolding link identity
  (priority 0 :type fixnum)
  input state handle)

(defstruct (packet (:constructor make-packet ()))
  link identity
  (kind 0 :type fixnum)
  (datum 0 :type fixnum) 
  (data '#() :type simple-vector))

(defstruct (deviceTaskDataRecord (:constructor make-deviceTaskDataRecord ()))
  pending)

(defstruct (handlerTaskDataRecord (:constructor make-handlerTaskDataRecord ()))
  workIn deviceIn)

(defstruct (idleTaskDataRecord (:constructor make-idleTaskDataRecord ()))
  (control 0 :type fixnum)
  (count 0 :type fixnum))

(defstruct (workerTaskDataRecord (:constructor make-workerTaskDataRecord ()))
  (destination 0 :type fixnum)
  (count 0 :type fixnum))

(defun wait ()
  (setf (taskControlBlock-taskWaiting currentTask) t)
  currentTask)

;; #+cmu
;; (declaim (ext:freeze-type taskControlBlock packet deviceTaskDataRecord
;; 			  handlerTaskDataRecord idleTaskDataRecord
;; 			  workerTaskDataRecord))
;; #+cmu
;; (declaim (ext:start-block richards))

(defun deviceTaskDataRecord-run (self work)
  (let ((functionWork work))
    (if (eq noWork functionWork)
	(progn
	 (setq functionWork (deviceTaskDataRecord-pending self))
	 (if (eq noWork functionWork)
	     (wait)
	   (progn
	    (setf (deviceTaskDataRecord-pending self) noWork)
	    (queuePacket functionWork))))
      (progn
       (setf (deviceTaskDataRecord-pending self) functionWork)
       (if tracing (trace-it (packet-datum functionWork)))
       (holdSelf)))))

(defun handlerTaskDataRecord-run (self work)
  (if (eq noWork work)
      nil
    (if (= workPacketKind (packet-kind work))
	(workInAdd self work)
      (deviceInAdd self work)))
  (let ((workPacket (handlerTaskDataRecord-workIn self)))
    (if (eq noWork workPacket)
	(wait)
      (let ((count (packet-datum workPacket)))
	(if (> count 4)
	    (progn
	     (setf (handlerTaskDataRecord-workIn self)
		   (packet-link workPacket))
	     (queuePacket workPacket))
	  (let ((devicePacket (handlerTaskDataRecord-deviceIn self)))
	    (if (eq noWork devicePacket)
		(wait)
	      (progn
	       (setf (handlerTaskDataRecord-deviceIn self)
		     (packet-link devicePacket))
	       (setf (packet-datum devicePacket)
		     (svref (packet-data workPacket) (- count 1)))
	       (setf (packet-datum workPacket) (+ count 1))
	       (queuePacket devicePacket)))))))))

(defun idleTaskDataRecord-run (self work)
  (declare (ignore work))
  (setf (idleTaskDataRecord-count self)
	(- (idleTaskDataRecord-count self) 1))
  (if (= 0 (idleTaskDataRecord-count self))
      (holdSelf)
    (if (= 0 (logand (idleTaskDataRecord-control self) 1))
	(progn
	 (setf (idleTaskDataRecord-control self)
	       (floor (idleTaskDataRecord-control self) 2))
	 (release deviceA))
      (progn
       (setf (idleTaskDataRecord-control self)
	     (logxor (floor (idleTaskDataRecord-control self) 2)
		     53256))
       (release deviceB)))))

(defun workerTaskDataRecord-run (self work)
  (if (eq noWork work)
      (wait)
    (progn
     (setf (workerTaskDataRecord-destination self)
	   (if (= handlerA (workerTaskDataRecord-destination self))
	       handlerB
	     handlerA))
     (setf (packet-identity work) (workerTaskDataRecord-destination self))
     (setf (packet-datum work) 1)
     (do ((i 0 (+ i 1)))
	 ((> i 3) nil)
       (declare (fixnum i))
	 (setf (workerTaskDataRecord-count self)
	       (+ (workerTaskDataRecord-count self) 1))
	 (if (> (workerTaskDataRecord-count self) 256)
	     (setf (workerTaskDataRecord-count self) 1))
	 (setf (svref (packet-data work) i)
	       (the fixnum
		    (+ (char-code #\A)
		       (- (workerTaskDataRecord-count self) 1)))))
     (queuePacket work))))

(defun appendHead (packet queueHead)
  (setf (packet-link packet) noWork)
  (if (eq noWork queueHead)
      packet
    (let ((mouse queueHead))
      (let ((link (packet-link mouse)))
	(do ()
	    ((eq noWork link) nil)
	    (setq mouse link)
	    (setq link (packet-link mouse)))
	(setf (packet-link mouse) packet)
	queueHead))))

(defun initialize-globals ()
  (setq taskList noTask)
  (setq currentTask nil)
  (setq currentTaskIdentity nil)
  (setq taskTable (make-array 6 :initial-element noTask))
  (setq tracing nil)
  (setq layout 0)
  (setq queuePacketCount 0)
  (setq holdCount 0))

(defun richards (&optional (iterations 1000000))
  (initialize-globals)
  (createIdler idler 0 noWork (running (make-taskControlBlock)))
  (let ((workQ))
    (setq workQ (createPacket noWork worker workPacketKind))
    (setq workQ (createPacket workQ worker workPacketKind))
    (createWorker worker 1000 workQ (waitingWithPacket))

    (setq workQ (createPacket noWork deviceA devicePacketKind))
    (setq workQ (createPacket workQ deviceA devicePacketKind))
    (setq workQ (createPacket workQ deviceA devicePacketKind))
    (createHandler handlerA 2000 workQ (waitingWithPacket))
    
    (setq workQ (createPacket noWork deviceB devicePacketKind))
    (setq workQ (createPacket workQ deviceB devicePacketKind))
    (setq workQ (createPacket workQ deviceB devicePacketKind))
    (createHandler handlerB 3000 workQ (waitingWithPacket))
    
    (createDevice deviceA 4000 noWork (waiting))
    (createDevice deviceB 5000 noWork (waiting)))
  (dotimes (i iterations) (schedule))
  (values))

(defun schedule ()
  (setq currentTask taskList)
  (do ()
      ((eq noTask currentTask) nil)
    (if (isTaskHoldingOrWaiting currentTask)
	(setq currentTask (taskControlBlock-link currentTask))
	(progn
	 (setq currentTaskIdentity (taskControlBlock-identity currentTask))
	 (if tracing (trace-it currentTaskIdentity))
	 (setq currentTask (runTask currentTask))))))

(defun findTask (identity)
  (declare (fixnum identity))
  (let ((tk (svref taskTable (- identity 1))))
    (if (eq noTask tk) (error "findTask failed"))
    tk))

(defun holdSelf ()
  (setq holdCount (+ holdCount 1))
  (setf (taskControlBlock-taskHolding currentTask) t)
  (taskControlBlock-link currentTask))

(defun queuePacket (packet)
  (let ((tk (findTask (packet-identity packet))))
    (if (eq noTask tk)
	noTask
	(progn
	 (setq queuePacketCount (+ queuePacketCount 1))
	 (setf (packet-link packet) noWork)
	 (setf (packet-identity packet) currentTaskIdentity)
	 (addInput tk packet currentTask)))))

(defun release (identity)
  (let ((tk (findTask identity)))
    (if (eq noTask tk)
	noTask
	(progn
	 (setf (taskControlBlock-taskHolding tk) nil)
	 (if (> (taskControlBlock-priority tk)
		(taskControlBlock-priority currentTask))
	     tk
	     currentTask)))))

(defun trace-it (id)
  (setq layout (- layout 1))
  (if (>= 0 layout)
      (progn
       (format t "~%")
       (setq layout 30)))
  (format t "~a " id))

(defun createDevice (identity priority work state)
  (let ((data (create-deviceTaskDataRecord)))
    (createTask identity priority work state data)))

(defun createHandler (identity priority work state)
  (let ((data (create-handlerTaskDataRecord)))
    (createTask identity priority work state data)))

(defun createIdler (identity priority work state)
  (let ((data (create-idleTaskDataRecord)))
    (createTask identity priority work state data)))

(defun createWorker (identity priority work state)
  (let ((data (create-workerTaskDataRecord)))
    (createTask identity priority work state data)))

(defun createTask (identity priority work state data)
  (let ((tk (create-taskControlBlock
	     taskList identity priority work state data)))
    (setq taskList tk)
    (setf (svref taskTable (- identity 1)) tk)))

(defun createPacket (link identity kind)
  (create-packet link identity kind))

(defun running (tcb)
  (setf (taskControlBlock-packetPending tcb) nil)
  (setf (taskControlBlock-taskWaiting tcb) nil)
  (setf (taskControlBlock-taskHolding tcb) nil)
  tcb)

(defun waiting ()
  (let ((tcb (make-taskControlBlock)))
    (setf (taskControlBlock-packetPending tcb) nil)
    (setf (taskControlBlock-taskWaiting tcb) t)
    (setf (taskControlBlock-taskHolding tcb) nil)
    tcb))

(defun waitingWithPacket ()
  (let ((tcb (make-taskControlBlock)))
    (setf (taskControlBlock-packetPending tcb) t)
    (setf (taskControlBlock-taskWaiting tcb) t)
    (setf (taskControlBlock-taskHolding tcb) nil)
    tcb))

(defun isTaskHoldingOrWaiting (tcb)
  (or (taskControlBlock-taskHolding tcb)
      (and (not (taskControlBlock-packetPending tcb))
	   (taskControlBlock-taskWaiting tcb))))

(defun isWaitingWithPacket (tcb)
  (and (taskControlBlock-packetPending tcb)
       (and (taskControlBlock-taskWaiting tcb)
	    (not (taskControlBlock-taskHolding tcb)))))

(defun packetNowPending (tcb)
  (setf (taskControlBlock-packetPending tcb) t)
  (setf (taskControlBlock-taskWaiting tcb) nil)
  (setf (taskControlBlock-taskHolding tcb) nil)
  tcb)

(defun create-taskControlBlock
  (link identity priority initialWorkQueue initialState privateData)
  (let ((r (make-taskControlBlock)))
    (setf (taskControlBlock-link r) link)
    (setf (taskControlBlock-identity r) identity)
    (setf (taskControlBlock-priority r) priority)
    (setf (taskControlBlock-input r) initialWorkQueue)
    (setf (taskControlBlock-packetPending r)
	 (taskControlBlock-packetPending initialState))
    (setf (taskControlBlock-taskWaiting r)
	 (taskControlBlock-taskWaiting initialState))
    (setf (taskControlBlock-taskHolding r)
	 (taskControlBlock-taskHolding initialState))
    (setf (taskControlBlock-handle r) privateData)
    (setf (taskControlBlock-state r) nil)
    r))

(defun addInput (tcb packet oldTask)
  (if (eq noWork (taskControlBlock-input tcb))
      (progn
       (setf (taskControlBlock-input tcb) packet)
       (setf (taskControlBlock-packetPending tcb) t)
       (if (> (taskControlBlock-priority tcb)
	      (taskControlBlock-priority oldTask))
	   tcb
	   oldTask))
      (progn
       (setf (taskControlBlock-input tcb)
	    (appendHead packet (taskControlBlock-input tcb)))
       oldTask)))

(defun runTask (tcb)
  (let ((message nil))
    (if (isWaitingWithPacket tcb)
	(progn
	  (setq message (taskControlBlock-input tcb))
	  (setf (taskControlBlock-input tcb) (packet-link message))
	  (if (eq noWork (taskControlBlock-input tcb))
	      (running tcb)
	    (packetNowPending tcb)))
      (setq message noWork))
    (run (taskControlBlock-handle tcb) message)))

(defun run (self work)
  (typecase self
	    (deviceTaskDataRecord (deviceTaskDataRecord-run self work))
	    (handlerTaskDataRecord (handlerTaskDataRecord-run self work))
	    (idleTaskDataRecord (idleTaskDataRecord-run self work))
	    (workerTaskDataRecord (workerTaskDataRecord-run self work))))

(defun create-packet (link identity kind)
  (let ((p (make-packet)))
    (setf (packet-link p) link)
    (setf (packet-identity p) identity)
    (setf (packet-kind p) kind)
    (setf (packet-datum p) 1)
    (let ((v (make-array 4 :initial-element 0)))
      (setf (packet-data p) v))
    p))

(defun create-deviceTaskDataRecord ()
  (let ((tk (make-deviceTaskDataRecord)))
    (setf (deviceTaskDataRecord-pending tk) noWork)
    tk))

(defun create-handlerTaskDataRecord ()
  (let ((tk (make-handlerTaskDataRecord)))
    (setf (handlerTaskDataRecord-workIn tk) noWork)
    (setf (handlerTaskDataRecord-deviceIn tk) noWork)
    tk))

(defun deviceInAdd (tk packet)
  (setf (handlerTaskDataRecord-deviceIn tk)
       (appendHead packet (handlerTaskDataRecord-deviceIn tk)))
  tk)

(defun workInAdd (tk packet)
  (setf (handlerTaskDataRecord-workIn tk)
       (appendHead packet (handlerTaskDataRecord-workIn tk)))
  tk)

(defun create-idleTaskDataRecord ()
  (let ((tk (make-idleTaskDataRecord)))
    (setf (idleTaskDataRecord-control tk) 1)
    (setf (idleTaskDataRecord-count tk) 10000)
    tk))

(defun create-workerTaskDataRecord ()
  (let ((tk (make-workerTaskDataRecord)))
    (setf (workerTaskDataRecord-destination tk) handlerA)
    (setf (workerTaskDataRecord-count tk) 0)
    tk))

;; EOF
