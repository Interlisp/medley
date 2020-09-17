;;; setup file for running cl-bench in Corman CL


(defun corman-compile-all-files ()
  (dolist (f (directory "files/*.lisp"))
    (compile-file f :print nil)))

(defun corman-load-and-run ()
  (dolist (f (directory "files/*.fasl"))
    (load f))
  (bench-run))




;; EOF
