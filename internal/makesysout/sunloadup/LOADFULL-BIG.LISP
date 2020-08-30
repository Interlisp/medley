(RESETVARS
   ((IDLE.PROFILE (QUOTE (TIMEOUT NIL))))
    (DEL.PROCESS (QUOTE IDLE))
    (SETQQ DISPLAYFONTDIRECTORIES
            ("{DSK}/mo/release/fonts/display/presentation/"
"{DSK}/mo/release/fonts/display/publishing/"
"{DSK}/mo/release/fonts/display/miscellaneous/" ))
    (SETQQ INTERPRESSFONTDIRECTORIES
            ("{DSK}/mo/release/fonts/interpress/presentation/"
"{DSK}/mo/release/fonts/interpress/publishing/"
"{DSK}/mo/release/fonts/interpress/miscellaneous/" ))
    (SETQQ *DEFAULT-CLEANUP-COMPILER* BCOMPL)
    (SETQQ LOADUPDIRECTORIES
            ({dsk}~/4-byte-lib/ {dsk}~/4-byte-intlib/
			 {dsk}/king/export/lispcore/lafite/parc-94/
			 {dsk}/king/export/lispcore/library/
			 {dsk}/king/export/lispcore/internal/library/
))
  (* used to include after EDITBITMAL: MAILCLIENT NSMAIL LAFITE NEWNSMAIL)
  (* used to include MAILCLIENT before NSMAIL )
  (LOADUP (QUOTE (MSANALYZE MSPARSE MASTERSCOPE GIVE-AND-TAKE CHANGECONTROL CHAT PUPCHAT NSCHAT TEDIT HRULE
				  TEDITCHAT READNUMBER EDITBITMAP NSMAIL LAFITE
				  NEWNSMAIL FILEBROWSER GRAPHER SPY AREDIT WHERE-IS COPYFILES
				  UNIXCOMM UNIXCHAT
				  POSTSCRIPTSTREAM UNIXPRINT)))
  (\DAYTIME0 \LASTUSERACTION)
  (ENDLOADUP))
STOP
