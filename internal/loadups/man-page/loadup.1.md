% loadup(1) | Run the Medley loadup procedure

---
adjusting: l
hyphenate: false
---

NAME
====

**loadup** — runs a loadup procedure for Medley Interlisp

SYNOPSIS
========

**\<MEDLEYDIR>/loadup** \[ flags ... ]
OR
**\<MEDLEYDIR>/scripts/loadup-all.sh** \[ flags ... ] 
OR
**\<MEDLEYDIR>/scripts/loadups/loadup-all.sh** \[ flags ... ] 


DESCRIPTION
===========

Runs all or part of the **loadup** procedure for Medley Interlisp.  The loadup procedure is used to create the standard sysout files from which you can start a Medley session as well as other standard files that are useful in running Medley.  After cloning Medley from GitHub or after making significant changes to the Medley source, you need to run the loadup procedure to (re)create these standard files.

The complete loadup procedure happens in 5 sequential stages with each stage depending on successful completion of the previous stage.  

You need not run all 5 stages, depending on what sysout files you need to create for your work.  The target files created in each stage are copied into a loadups directory (\<MEDLEYDIR>/loadups).  The *medley* run script and other Medley tools look for these files in the loadups directory.  

The 5 sequential stages and their main products are:
	1.  **Init:**  create an *init.dlinit* sysout file.  This init.dlinit file is used internally for Stage 2 and is not copied into the loadups directory.
	2. **Mid:** create an *init-mid.sysout*.  This init-mid.sysout is used only internally for Stage 3 and is not copied into the loadups directory.
	3. **Lisp:** create *lisp.sysout*.  Lisp.sysout has a minimal set of Medley's functionality loaded and can be used as the basis for running a stripped-down Medley session.  Lisp.sysout is copied into the loadups directory.
	4. **Full:** create *full.sysout*.  Full.sysout has all of the "standard" set of Medley functionality loaded and is the primary sysout used for running Medley sessions.  Full.sysout is copied into the loadups directory.
	5. **Apps:**:  create *apps.sysout*.  Apps.sysout includes everything in full.sysout plus the Medley applications Buttons, CLOS, Rooms, and Notecards.

In addition to these 5 sequential stages, there are two independent stages that can be run if the first 4 sequential stages complete successfully.
	A. **Aux:**: create the *whereis.hash* and *exports.all* files.  These are databases that are commonly used when working on Medley source code.  They are copied into the loadups directory.
	B. **DB:**: creates the *fuller.database* file.  Fuller.database is a Mastercope database created by analyzing all of the source code included in full.sysout. (Stage 4)  Fuller.database is copied into the loadups directory.

Loadup does all of its work in a work directory (\<MEDLEYDIR>loadups/build).  The target files are copied from this work directory to the loadups directory if the loadup is successful.  Each stage of the loadup also creates a dribble file containing the terminal output from within the Medley environment.  These dribble files are not copied to the loadups directory, but remain available in the work directory after the loadup completes.

Only one instance (per \<MEDLEIDIR>) of loadup can be run at a time.  (The lock file is in the work directory and is named ***lock***.  It can be removed in case of an uncontrolled failure of the loadup procedure.)

Note: **MEDLEYDIR** is an environment variable set by the loadup script.  It is set to the top level directory of the Medley installation that contains the specific loadup script that
is invoked after all symbolic links are resolved.  In the standard global installation this will 
be /usr/local/interlisp/medley.  But Medley can be installed in multiple places on any given machine and
hence MEDLEYDIR is computed on each invocation of loadup. 

OPTIONS
=======




Flags
-----

&nbsp;

-i, \-\-init, -init, -1
: Run loadup through Stage 1, creating the init.dlinit file.  Init.dlinit is *not* copied into the loadups directory.

-m, \-\-mid, -mid, -2
: Run loadup through Stage 2, creating the init-mid.sysout.  Init-mid.sysout is *not* copied into the loadups directory.

-l, \-\-lisp, -lisp, -3
: Run loadup through Stage 3, creating lisp.sysout.  If loadup completes successfully, lisp.sysout is copied into the loadups directory.

-f, \-\-full. -full, -4
: Run loadup thru Stage 4, creating full.sysout.  If loadup completes successfully full.sysout is copied into the loadups directory.  If loadup starts at Stage 2 (see below), the new lisp.sysout is also copied into loadups.

This is the default.

-a, \-\-apps, -apps, -5
: Run loadup thru Stage 5, creating the apps.sysout.  If loadup completes successfully, apps.sysout is copied into the loadups directory.

-x, \-\-aux, -aux
: Run the Aux loadup stage, creating the *whereis.hash* and *exports.all* files.  If loadup completes successfully, these files are copied into loadups.   

This is the default whenever Stage 4 (full.sysout) is being created.

-n, \-\-noaux, -noaux
: No not run the Aux loadup stage, creating the *whereis.hash* and *exports.all* files.  If loadup completes successfully, these files are copied into loadups.   

This is the default if Stage 4 (full.sysout) is not being created.

-b, \-\-db, \-db
: Run the DB loadup stage, creating the fuller.database file.  If this stage complete successfully, these files are copied into loadups.

-s [STAGE] \-\-start [STAGE], -start [STAGE}
:  Start the loadup process using the files previously created by STAGE.  These files are looked for first in the loadups directory or, if not found there, in the work directory.  It is an error if the files created by STAGE cannot be found.
STAGE can be one of the following:
  
  ***s, scratch, 0*** : Start the loadup process from the beginning.  This is the default.
  ***i, init, 1***: Start the loadup process using the files created by Stage 1 (init.dlinit).
   ***m, mid, 2***: Start the loadup process using the files created by Stage 2 (init-mid.sysout).
    ***l, lisp, 3***: Start the loadup process using the files created by Stage 3 (lisp.sysout)
     ***f, full, 4***: Start the loadup process using the files created by Stage 4 (full.sysout).

-d [DIR] \-\-maikodir [DIR], -maikodir [DIR}
:  Use DIR as the directory from which to execute lde (Miko) when running Medley in the loadup process.  If this flag is not present, the value of the environment variable MAIKODIR will be used instead.  And if MAIKODIR does not exist, then the default Maiko directory search within Medley will be used.

Examples
====
***./loadup -f s l *** :  run loadup thru Stage 4 (full.sysout) starting from Stage 3 outputs (lisp.sysout).  By default, this will also run the Aux stage.

***loadup -apps*** : run loadup from the beginning thru Stage 5 (apps.sysout).  By default, this will also run the Aux stage.

***loadup -apps -noaux*** : run loadup from the beginning thru Stage 5 (apps.sysout).  Do not run run the Aux stage.

***loadup*** :   run loadup from the beginning thru Stage 4 (full.sysout) as well as the Aux stage.

***loadup***: 



BUGS
====

See GitHub Issues: <https://github.com/Interlisp/medley/issues>

COPYRIGHT
=========

Copyright(c) 2025 by Interlisp.org
