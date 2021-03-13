(* "make init files; this file is loaded as a 'greet' file by scripts/loadup-init.sh")

(CNDIR (MEDLEYDIR "tmp"))
(DRIBBLE "init.dribble")
(MOVD 'NILL 'PAGEFULLFN)
(LOAD (MEDLEYDIR "sources" "MAKEINIT.LCOM"))
(MAKEINITGREET)
(DRIBBLE)
(LOGOUT T)
STOP

