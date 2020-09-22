(RESETVARS
   ((IDLE.PROFILE (QUOTE (TIMEOUT NIL))))
    (DEL.PROCESS (QUOTE IDLE))
    (SETQQ DISPLAYFONTDIRECTORIES
            ("{DSK}~/lispcore/fonts/display/presentation/"
"{DSK}~/lispcore/fonts/display/publishing/"
"{DSK}~/lispcore/fonts/display/miscellaneous/" ))
    (SETQQ INTERPRESSFONTDIRECTORIES
            ("{DSK}~/lispcore/fonts/interpress/presentation/"
"{DSK}~/lispcore/fonts/interpress/publishing/"
"{DSK}~/lispcore/fonts/interpress/miscellaneous/" ))
    (SETQQ *DEFAULT-CLEANUP-COMPILER* BCOMPL)
    (SETQQ LOADUPDIRECTORIES
            ({dsk}~/lispcore/lafite/medley-2.01/
			 {dsk}~/lispcore/library/
			 {dsk}~/lispcore/internal/library/
			 
))
	(SETQ CH.DEFAULT.DOMAIN "MV") (SETQ CH.DEFAULT.ORGANIZATION "Envos")
  (* used to include after EDITBITMAL: MAILCLIENT NSMAIL LAFITE NEWNSMAIL)
  (LOADUP (QUOTE (MSPARSE MSANALYZE MASTERSCOPE 
						  GIVE-AND-TAKE CHANGECONTROL CHAT PUPCHAT NSCHAT TEDIT HRULE
				  TEDITCHAT READNUMBER EDITBITMAP MAILCLIENT NSMAIL LAFITE
				  NEWNSMAIL FILEBROWSER GRAPHER SPY AREDIT WHERE-IS COPYFILES
				  UNIXCOMM UNIXCHAT
				  POSTSCRIPTSTREAM UNIXPRINT MULTI-COMPILE)))
  (\DAYTIME0 \LASTUSERACTION)
  (ENDLOADUP))
STOP
