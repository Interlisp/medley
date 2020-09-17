(with-open-file (r "results.sorted" :direction :output :if-exists :supersede)
  (loop for (number result) in
        (sort 
         (with-open-file (s "results" :direction :input)
           (loop for line = (read-line s nil 'eof)
                 until (eq line 'eof)
                 for (number next) = (multiple-value-list (parse-integer line :junk-allowed t))
                 for result = (read-from-string line nil 'eof :start (1+ next))
                 collect (list number result)))
         #'>
         :key #'second)
        do (format r "~@3A ~5,2F~%" number result)))

(with-open-file (s "results" :direction :input)
           (loop for line = (read-line s nil 'eof)
                 until (eq line 'eof)
                 for (number next) = (multiple-value-list (parse-integer line :junk-allowed t))
                 for result = (read-from-string line nil 'eof :start (1+ next))
                 if (<= 1.0 result)
                 collect (list number result)))

(with-open-file (s "results" :direction :input)
           (loop for line = (read-line s nil 'eof)
                 until (eq line 'eof)
                 for (number next) = (multiple-value-list (parse-integer line :junk-allowed t))
                 for result = (read-from-string line nil 'eof :start (1+ next))
                 count result into c
                 sum result into x
                 finally (return (float (/ x c)))))
