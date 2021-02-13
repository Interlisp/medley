(* "make init files")

(CNDIR (MEDLEYDIR "tmp"))

(LOAD (MEDLEYDIR "sources" "MAKEINITGREET.LCOM"))
(PROGN (DRIBBLE "makeinit.dribble")
       (BKSYSBUF " ")
       (MAKEINITGREET)
       (DRIBBLE)
       (LOGOUT T))
