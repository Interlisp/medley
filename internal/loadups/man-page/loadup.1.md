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


**\<MEDLEYDIR>/scripts/loadup-all.sh** \[ flags ... ] 


**\<MEDLEYDIR>/scripts/loadups/loadup-all.sh** \[ flags ... ] 


DESCRIPTION
===========

Runs all or part of the **loadup** procedure for Medley Interlisp.  The loadup procedure is used to create the standard sysout files from which you can start a Medley session as well as other standard files that are useful in running Medley.  After cloning Medley from GitHub or after making significant changes to the Medley source, you need to run the loadup procedure to (re)create these standard files.

The complete loadup procedure happens in 5 sequential stages with each stage depending on successful completion
of the previous stage.  There are two other non-sequential stages (Aux and DB), which depend only on the completion
of Stage 4 (full.sysout).

You need not run all 5 stages, depending on what sysout files you need to create for your work.
The target files created in each stage are copied into a loadups directory (\<MEDLEYDIR>/loadups).
The *medley* run script and other Medley tools look for these files in the loadups directory.

The 5 sequential stages and their main products are:

>1. **Init:**  create an *init.dlinit* sysout file.  This init.dlinit file is used internally for Stage 2 and is not copied into the loadups directory.

>2. **Mid:** create an *init-mid.sysout*.  This init-mid.sysout is used only internally for Stage 3 and is not copied into the loadups directory.

>3. **Lisp:** create *lisp.sysout*.  Lisp.sysout has a minimal set of Medley's functionality loaded and can be used as the basis for running a stripped-down Medley session.  Lisp.sysout is copied into the loadups directory.

>4. **Full:** create *full.sysout*.  Full.sysout has all of the "standard" set of Medley functionality loaded and is the primary sysout used for running Medley sessions.  Full.sysout is copied into the loadups directory.

>5. **Apps:**:  create *apps.sysout*.  Apps.sysout includes everything in full.sysout plus the Medley applications Buttons, CLOS, Rooms, and Notecards.


The two independent stages that can be run if the first 4 sequential stages complete successfully are:

>+ **Aux:**: create the *whereis.hash* and *exports.all* files.  These are databases that are commonly used when working on Medley source code.  They are copied into the loadups directory.
>+ **DB:**: creates the *fuller.database* file.  Fuller.database is a Mastercope database created by analyzing all of the source code included in full.sysout. (Stage 4)  Fuller.database is copied into the loadups directory.


Loadup does all of its work in a work directory (\<MEDLEYDIR>loadups/build).  The target files are copied from this work directory to the loadups directory if the loadup is successful.  Each stage of the loadup also creates a dribble file containing the terminal output from within the Medley environment.  These dribble files are not copied to the loadups directory, but remain available in the work directory after the loadup completes.


Only one instance (per \<MEDLEIDIR>) of loadup can be run at a time.  (The lock file is in the work directory and is named ***lock***.  It can be removed in case of an uncontrolled failure of the loadup procedure.)

Note: **MEDLEYDIR** is an environment variable set by the loadup script.  It is set to the top level directory of the Medley installation that contains the specific loadup script that
is invoked after all symbolic links are resolved.  In the standard global installation this will 
be /usr/local/interlisp/medley.  But Medley can be installed in multiple places on any given machine and
hence MEDLEYDIR is computed on each invocation of loadup. 

OPTIONS
=======
-z, \-\-man, \-man
: Print this manual page on the screen.

-t STAGE, \-\-target STAGE, -target STAGE
: Run the sequential loadup procedure until the STAGE is complete, starting from the files created by the previously run STAGE specified in the --start option.

>STAGE can be one of the following:
 
>>i, init, 1: Run the loadup sequence through Stage 1 (init.dlinit).  Init.dlinit is *not* copied into the loadups directory. 

>>m, mid, 2: Run the loadup sequence through Stage 2 (init-mid.sysout).  Init-mid.sysout is *not* copied into the loadups directory. 
 
>>l, lisp, 3: Run the loadup sequence through Stage 3 (lisp.sysout).  Lisp.sysout is copied into the loadups directory. 
 
>>f, full, 4: Run the loadup sequence through Stage 4 (full.sysout).  Full.sysout is copied into the loadups directory.
 
>>a, apps, 5: Run the loadup sequence through Stage 5 (apps.sysout).  Apps.sysout is copied into the loadups directory.

-s STAGE \-\-start STAGE, -start STAGE
:  Start the loadup process using the files previously created by STAGE.  These files are looked for first in the loadups directory or, if not found there, in the work directory.  It is an error if the files created by      						STAGE cannot be found.

>STAGE can be one of the following:
 
>>s, scratch, 0 : Start the loadup process from the beginning.  This is the default.

>> i, init, 1 : Start the loadup process using the files created by Stage 1 (init.dlinit).

>>m, mid, 2 : Start the loadup process using the files created by Stage 2 (init-mid.sysout).

>>l, lisp, 3 : Start the loadup process using the files created by Stage 3 (lisp.sysout)
 
>>f, full, 4 : Start the loadup process using the files created by Stage 4 (full.sysout).

-x, \-\-aux, -aux
: Run the Aux loadup stage, creating the *whereis.hash* and *exports.all* files.  If loadup completes successfully, these files are copied into loadups.   

-b, \-\-db, \-db
: Run the DB loadup stage, creating the *fuller.database* file.  If this stage complete successfully, these files are copied into loadups.

-i, \-\-init, -init, -1
: Synonym for "--target init"

-m, \-\-mid, -mid, -2
: Synonym for "--target mid"

-l, \-\-lisp, -lisp, -3
: Synonym for "--target lisp"

-f, \-\-full. -full, -4
: Synonym for "--target full"

-a, \-\-apps, -apps, -5
: Synonym for "--target apps"

-d DIR \-\-maikodir DIR, -maikodir DIR
:  Use DIR as the directory from which to execute lde (Miko) when running Medley in the loadup process.  If this flag is not present, the value of the environment variable MAIKODIR will be used instead.  And if MAIKODIR does not exist, then the default Maiko directory search within Medley will be used.

DEFAULTS
====
The defaults for the Options context-dependent and somewhat complicated due to the goal of maintaining compatibility with legacy loadup scripts.  All of the following defaults rules hold independent of the --maikodir (-d) option.

1.  If there are no options specified (except for --maikodir), then the options default to:<br>```--target full --start 0 --aux```

2. If neither --start nor --target are specified but either -aux or -db or both are, then --start defaults to *full* and --target is irrelevant.

3. If --start is specified and --target is not, then --target defaults to *full*

4. If --target is specified and --start is not, then --start defaults to *0*

EXAMPLES
====
```./loadup -full -s lisp``` or ```./loadup --target full --start lisp ```:  run loadup thru Stage 4 (full.sysout) starting from existing Stage 3 outputs (lisp.sysout).

```loadup -5 --aux```: run loadup from the beginning thru Stage 5 (apps.sysout) then run the Aux "stage" to create *whereis.hash* and *exports.all*

```loadup -db```: just run the DB "stage" starting from an existing full.sysout; do not run any of the sequential stages.

```loadup --maikodir ~/il/newmaiko```:   run loadup sequence from beginning to full plus the loadup Aux stage, while using *~/il/newmaiko* as the location for the lde executables when running Medley.

```loadup -full```: run loadup sequence from beginning thru full.  (Do not run the Aux stage unlike in the case of the legacy loadup-full.sh)

BUGS
====

See GitHub Issues: <https://github.com/Interlisp/medley/issues>

COPYRIGHT
=========

Copyright(c) 2025 by Interlisp.org
