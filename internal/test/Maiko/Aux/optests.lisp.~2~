;;; Random opcode tests

(in-package "XCL-USER")

(defun copy.n.test (use-ufn)
  "Tests a case of the COPY.N opcode. Both (COPY.N.TEST NIL) and (COPY.N.TEST T) should return :OK"
  (if use-ufn
      (progn ((il:opcodes il:copy) 2 1 :ok -1 -2) ; the COPY compensates for a POP
             (funcall (il:\\getufnentry 'il:copy.n) 4))
    ((il:opcodes il:copy.n 4) 2 1 :ok -1 -2)))

(defun store.n.test (use-ufn)
  "Tests a case of the STORE.N opcode. Both (STORE.N.TEST NIL) and (STORE.N.TEST T) should return the list (5 4 t 2 1)"
  (if use-ufn
      (progn ((il:opcodes il:copy) 5 4 3 2 1)
             (funcall (il:\\getufnentry 'il:store.n) t 4))
    ((il:opcodes il:store.n 4) 5 4 3 2 1 t))
  ((il:opcodes il:applyfn) 5 'list))

(defun pop.n.test (use-ufn)
  "Tests a case of the STORE.N opcode. Both (POP.N.TEST NIL) and (POP.N.TEST T) should return 2"
  (if use-ufn
      (progn ((il:opcodes il:copy) 4 3 2 1 0)
             (funcall (il:\\getufnentry 'il:pop.n) 2))
    ((il:opcodes il:pop.n 2) 4 3 2 1 0)))

