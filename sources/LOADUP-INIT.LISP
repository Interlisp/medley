(* "make init files; this file is loaded as a 'greet' file by scripts/loadup-init.sh")

(CNDIR (MEDLEYDIR "tmp"))
(MOVD 'NILL 'PAGEFULLFN)
(LOAD (MEDLEYDIR "sources" "MAKEINIT.LCOM"))
(PROGN (DRIBBLE "init.dribble")
       (MAKEINITGREET)
       (DRIBBLE)
       (LOGOUT T))
