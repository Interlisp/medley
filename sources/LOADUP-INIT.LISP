(* "make init files; this file is loaded as a 'greet' file by scripts/loadup-init.sh")

(CNDIR (MEDLEYDIR "tmp"))
(MOVD 'NILL 'PAGEFULLFN)
(LOAD (MEDLEYDIR "sources" "MAKEINIT.LCOM"))
(PROGN (MAKEINITGREET)
       (LOGOUT T))
