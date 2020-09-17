;;; pdf-report.lisp
;;
;; Author: Eric Marsden <emarsden@laas.fr>
;; Time-stamp: <2004-03-09 emarsden>
;;
;;
;; When loaded into CMUCL, this should generate a report comparing the
;; performance of the different CL implementations which have been
;; tested. Reads the /var/tmp/CL-benchmark* files to obtain data from
;; previous runs. Requires the cl-pdf library. 

(in-package :cl-user)

(eval-when (:load-toplevel :execute)
  (require :asdf)
  (asdf:oos 'asdf:load-op :uffi)
  (ext:load-foreign "/usr/lib/libz.so")
  (asdf:oos 'asdf:load-op :cl-pdf)
  (asdf:oos 'asdf:load-op :cl-typesetting))

(load #p"defpackage.lisp")
(load #p"support.lisp")
(load #p"tests.lisp")


(in-package :cl-bench)


(defun histogram-maker (title label-names results)
  (lambda (box x y)
    (pdf:in-text-mode
     (pdf:move-text x y)
     (pdf:set-font (pdf:get-font "Helvetica") 11)
     (pdf:show-text title))
    (pdf:draw-object
     (make-instance 'pdf:histogram
                    :x x :y (- y 95)
                    :width 90 :height 90
                    :label-names label-names
                    :labels&colors '(("ignore" (0.0 0.0 1.0)))
                    :series (list results)
                    :y-axis-options '(:min-value -0.5 :title "seconds")
                    :background-color '(0.9 0.9 0.9)))))



;; FIXME annotate each benchmark with estimated allocation volume & peak storage requirement
(defun bench-analysis (&optional (filename #p"/tmp/cl-bench.pdf"))
  (let (content data groups implementations benchmarks impl-scores impl-labels)
    (dolist (f (directory "/var/tmp/CL-benchmark*.*"))
      (ignore-errors
        (with-open-file (f f :direction :input)
          (let ((*read-eval* nil))
            (push (read f) data)))))
    (setf data (sort data #'string< :key #'car))
    (setf implementations (mapcar #'car data))
    (loop :for b :in *benchmarks*
          :do (pushnew (benchmark-group b) groups))
    (setf impl-scores (make-list (length implementations)
				 :initial-element 0))
    (setf impl-labels (loop :for i :from 0 :below (length implementations)
                            :collect (string (code-char (+ i (char-code #\A))))))
    (setf benchmarks (reverse (mapcar #'first (cdr (first data)))))

    (let ((*break-on-signals* 'condition)
          (header (typeset::compile-text ()
                     (typeset::paragraph (:h-align :centered
                                          :font "Times-Italic" :font-size 10)
                      "cl-bench performance benchmarks")
                    (typeset:hrule :dy 1/2)))
          (footer (lambda (pdf:*page*)
                    (typeset::compile-text (:font "Helvetica" :font-size 9)
                      (typeset:hrule :dy 1/2)
                      (typeset::hbox (:align :center :adjustable-p t)
                        (typeset::put-string "2004-03-09")
                        :hfill
                        (typeset::put-string
                         (format nil "page ~d"
                                 (1+ (position pdf:*page* (typeset::pages pdf:*document*))))))))))    
    (typeset::with-document (:author "Éric Marsden"
                             :title "cl-bench performance results")
      (dolist (group groups)
          (setq content
                (typeset::compile-text (:first-line-indent 0)
                  (typeset:paragraph (:font "Times-Italic" :font-size 16)
                     (typeset:put-string (concatenate 'string (string group) " group")))
                  (typeset::vspace 10)
                  (typeset:hrule :dy 1)
                  (typeset::vspace 40)
                  (typeset::paragraph (:first-line-indent 0)
                  (dolist (bm (remove-if-not (lambda (b) (eql (benchmark-group b) group)) *benchmarks*))
                    (let* ((bn (benchmark-name bm))
                           (results (loop :for i :in implementations
                                          :collect (let* ((id (cdr (assoc i data :test #'string=)))
                                                          (ir (third (assoc bn id :test #'string=))))
                                                     (if (numberp ir) (float ir) -0.02)))))
                      ;; (typeset::hspace 10)
                      (typeset::user-drawn-box
                       :inline t :dx 130 :dy 150
                       :stroke-fn (histogram-maker bn impl-labels results))
                      (typeset::hspace 20)))
                  :eop)))
          (typeset::draw-pages content :margins '(72 72 72 72) :header nil :footer footer))
      (setq content
            ;; index of implementation names
            (typeset::compile-text (:first-line-indent 0)
                (typeset::paragraph (:font-size 16) "Implementations")
                (typeset::vspace 10)
                (typeset::hrule :dy 1)
                (typeset::vspace 10)
                (dotimes (i (length implementations))
                 (typeset::paragraph (:font "Times-Roman" :font-size 12)
                   (typeset::put-string (format nil "~A: ~A~%~%" (nth i impl-labels) (nth i implementations))))
                  :eol)
                :eop :eop))
      (typeset::draw-pages content :margins '(72 72 72 72) :header nil :footer footer)
      (pdf:write-document filename)))))



;; (defun bench-analysis (&optional (filename #p"/tmp/cl-bench.pdf"))
;;   (let (data groups implementations benchmarks impl-scores impl-labels)
;;     (dolist (f (directory "/var/tmp/CL-benchmark*.*"))
;;       (ignore-errors
;;         (with-open-file (f f :direction :input)
;;           (let ((*read-eval* nil))
;;             (push (read f) data)))))
;;     (setf data (sort data #'string< :key #'car))
;;     (setf implementations (mapcar #'car data))
;;     (loop :for b :in *benchmarks*
;;           :do (pushnew (benchmark-group b) groups))
;;     (setf impl-scores (make-list (length implementations)
;; 				 :initial-element 0))
;;     (setf impl-labels (loop :for i :from 0 :below (length implementations)
;;                             :collect (string (code-char (+ i (char-code #\A))))))
;;     (setf benchmarks (reverse (mapcar #'first (cdr (first data)))))
;; 
;;     ;; FIXME possibly group graphs one group per page
;;     ;;
;;     ;; add numbers on bars
;;     ;;
;;     ;; annotate each benchmark with estimated allocation volume & peak storage requirement
;;     (pdf:with-document (:author "Éric Marsden"
;;                         :title "cl-bench performance results")
;;       (let ((helvetica (pdf:get-font "Helvetica"))
;;             (helvetica-bold (pdf:get-font "Helvetica-Bold"))
;;             (helvetica-oblique (pdf:get-font "Helvetica-Oblique"))
;;             (times (pdf:get-font "Times-Roman"))
;;             (page 0)
;;             (per-page 0)
;;             (page-name ""))
;;         (dolist (group groups)
;;           (incf page)
;;           (setf page-name (format nil "page ~d" page))
;;           (pdf:with-page ()
;;             (pdf:register-page-reference page-name)
;;             (pdf:with-outline-level (group page-name)
;;               ;; group name
;;               (pdf:in-text-mode
;;                (pdf:set-font helvetica-bold 16.0)
;;                (pdf:move-text 100 700)
;;                (pdf:draw-text (string group)))
;;               ;; version number
;;               (pdf:in-text-mode
;;                (pdf:set-font helvetica-oblique 8)
;;                (pdf:move-text 10 10)
;;                (pdf:draw-text (format nil "cl-bench version ~A" *version*)))
;;               (setf per-page 1)
;;               (dolist (bm (remove-if-not (lambda (b) (eql (benchmark-group b) group)) *benchmarks*))
;;                 (format *debug-io* "Group ~A, benchmark ~A~%" group bm)
;;                 (let* ((bn (benchmark-name bm))
;;                        (results (loop :for i :in implementations
;;                                       :collect (let* ((id (cdr (assoc i data :test #'string=)))
;;                                                       (ir (third (assoc bn id :test #'string=))))
;;                                                  (if (numberp ir) (float ir) -0.02))))
;;                        (ypos (- 640 (* 150 per-page))))
;;                   ;; with-column-layout
;;                   ;; test title
;;                   (incf per-page)
;;                   `(pdf:in-text-mode
;;                     (pdf:set-font helvetica-bold 16.0)
;;                     (pdf:move-text 100 ,ypos)
;;                     (pdf:draw-text bn))
;;                   ;; optional extra description
;; ;;                   (when (and b (benchmark-long b))
;; ;;                     (pdf:in-text-mode
;; ;;                      (pdf:set-font helvetica 12)
;; ;;                      (pdf:move-text 100 520)
;; ;;                      (pdf:draw-text (benchmark-long b))))
;;                   ;; y-axis title
;; ;;                   (pdf:with-saved-state
;; ;;                       (pdf:translate 65 350)
;; ;;                     (pdf:rotate 90)
;; ;;                     (pdf:in-text-mode
;; ;;                      (pdf:set-font helvetica 10)
;; ;;                      (pdf:draw-text "seconds")))
;;                   (pdf:draw-object
;;                    (make-instance 'pdf:histogram
;;                                   :x 100 :y ypos
;;                                   :width 100 :height 100
;;                                   :label-names impl-labels
;;                                   :labels&colors '(("ignore" (0.0 0.0 1.0)))
;;                                   :series (list results)
;;                                   :y-axis-options '(:min-value -0.5 :title "seconds")
;;                                   :background-color '(0.9 0.9 0.9)))
;;                   #+nil
;;                   (pdf:in-text-mode
;;                    (pdf:move-text 100 250)
;;                    (pdf:set-font times 12.0)
;;                    (dotimes (i (length implementations))
;;                      (pdf:move-text 0 -14)
;;                      (pdf:draw-text (format nil "~A: ~A"
;;                                             (nth i impl-labels)
;;                                             (nth i implementations)))))))))))
;;       (pdf:write-document filename))))


(bench-analysis)
(quit)

;; EOF
