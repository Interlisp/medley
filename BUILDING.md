# How to Build Medley and make a Release

# Using GitHub actions

In the GitHub medley repository (Interlisp/medley) go to the Actions tab.

It will list the available GitHub actions.
Select: **Build/Push Release & Docker**. 

In the middle of the screen there is a box labeled "Workflow Runs".
There should be a row in it that states 'This workflow has a workflow_dispatch event trigger' with a drop down menu (it really looks more like a button) on the right side labeled 'Run workflow'.  Select that and you'll get a form allowing you to select the branch (I've only used Master) and enter the release name.  Enter a name or leave it empty and press the green 'Run workflow' button. The workflow should queue up and run.  

Build/Push Release & Docker first builds Maiko and Medley, pushes a Medley release to the Interlisp/medley repo Releases, then makes a Docker image.

The files in .github/workflows/ contain the details.
<!-- 
The workflow pulls the latest Maiko image from Docker Hub and the Release Assets from the latest Medley release, generally defined as medley-YYMMDD.  The Medley Docker image adds in Tight VNC Server and retrieves the two tarballs associated with a release, one containing the sysouts and the other the other needed files source, fonts, etc.  The contents are uncompressed and loaded into the Medley directory structure.
-->

# Building Medley for yourself

The actual building itself is done with various shell scripts, found in the `scripts` directory in the medley repository. Most of the scripts have a minimal sanity check that they are being run from the medley repository.

Historically, building the medley image (called a "sysout") was called "doing a loadup".  Back in the day, a loadup took the better part of a day, and no one would do the whole thing -- there was no automation.

## Prerequisites

In these instructions, there is an assumption that the loadup scripts can find other repositories. All of the loadup scripts have to find `lde` and `ldex` or `ldisdl` and also `ldeinit`.

Loadups use the run-medley script, which looks for Maiko (actually the lde & ldeinit executables) as follows:

1. lde (ldeinit) on PATH
2. In the `<osversion>.<machinetype>` subdirectory of the directory specified by the $MAIKODIR environment variable
3. In the `<osversion>.<machinetype>` subdirectory of the directory specified by $MEDLEYDIR/../maiko/
4. In the `<osversion>.<machinetype>` subdirectory of the directory specified by $MEDLEYDIR/maiko/

where $MEDLEYDIR is the directory from which you called the loadup script.

## Make everything

The shell command:
```
time ./scripts/loadup-all.sh -apps && time ./scripts/loadup-db.sh
```
does everything; on a fast machine it takes 4-6 minutes, most of which is spent in the `loadup-db.sh` step. Without the `loadup-db.sh` step, it runs in 22 seconds on a fast system.

## How loadup-all.sh works

You don't need to know this unless you want to change some of the low-level files involved.

The script "loadup-all.sh" itself involes scripts used for different steps in the loadup -- basically loadup-all calls the scripts in this order:

* `loadup-init.sh` 
* `loadup-mid-from-init.sh`
* `loadup-lisp-from-mid.sh` 
* `loadup-full-from-lisp.sh`
* `loadup-aux.sh`
* `loadup-apps-from-full.sh`
* `loadup-db.sh`
* `copy-all.sh`

These are explained in reverse order:

### `copy-all.sh`: copy files from build directory to loadups

Most of the scripts build things in a temporary directory and, if the entire process succeeds, copies the results to the `loadups` directory. The environment variable `LOADUP-OUTDIR`, if set, is used, otherwise a sub-directory of /tmp.

`copy-db.sh` and `copy-full.sh` are provided if you've only done partial loadups.

`cpv` is a script that copies a file from one place to another while maintaining Medley version numbering.

### `loadup.db`: build `fuller.database`

This step was added to make a Masterscope database of "everything". The result is a file `fuller.database`. This was an artifact of an attempt to build some diagnostic tools to help understand what was going on in Medley.  There is a 4 step process in the `GATHER-INFO` function in the file `MEDLEY-UTILS` in the `internal` subdirectory of the medley repository that ends with creating a masterscope database after loading all of the source files for every file that is part of the loadup, plus a few additional LispUsers files listed in variables that are part of `MEDLEY-UTILS`.

There are some problems that `GATHER-INFO` results hint at, but haven't been explored systematically.

Masterscope has some gaps and bugs so `fuller.database` isn't as useful as it could be. For example, Masterscope 'show paths' was written assuming you had only anlayzed the parts you were working on, and so the results of `SHOW PATHS` are too big to be useful.

## `loadup-aux.sh`: rebuild two files used for Medley development

`exports.all` is a collection of external declarations from a set of files in the medley/sources directory that are marked as being exported within those sources. Low level system declarations that aren't needed by most users. The files that need exports.all are generally loaded by loading `SYSEDIT`, which sets up a couple of preferences and then loads `exports.all`. 

`whereis.hash` is an index file mapping function, variable, record declarations and other components to the file name containing that definition. It is the result of scanning the directories in the medley repository, including lispusers and library and internal etc. (but not obsolete?).

### `loadup-apps-from-full.sh:`build `apps.sysout`

`apps.sysout` includes some other components that are part of online.interlisp.org experience. 

### `loadup-full-from-lisp.sh`: Build a `full.sysout` and

`full.sysout` Includes what we hope is a useful subset of Interlisp library and lispusers components as well as our modernization components.


### Build a `lisp.sysout` in 4 scripts:

### `loadup-lisp-from-mid.sh` build `lisp.sysout`

`lisp.sysout` is what most 1990s customers started with. This step starts with `init-mid.sysout` and runs `sources/LOADUP-LISP`.

### `loadup-mid-from-init.sh` build `mid.sysout`

This step uses a Maiko that has been compiled with the `init` option. It reads the `init.dlinit` and initializes the package system and runs the EXPRESSIONS from the files that were "loaded" by MAKEINIT, and writes out `init-mid.sysout`.

### `loadup-init.sh`: build `mid.sysout`

This step (called `MAKEINIT`) runs a Lisp program (using a `starter` sysout) that reads in Lisp sources for the bootstrap loader, walks through the code renaming the low-level memory management functions to work on a file instead of in memory. These renamed functions are written to a file (called I-NEW), and I-NEW is then compiled and loaded in and run to 'virtually' load the core set of files in an initial memory image (called INIT.SYSOUT). It then does another (theoretically unnecessary) pass of reading in INIT.SYSOUT using a different renaming of variables used originally for remote debugging (called TELERAID) and moving some pages around to make room for Dandelion IO Processor boot code. 

While this step requires an Interlisp implementation, it isn't necessarily a Medley implementation. If  you want to change the instruction set or modify any data structures that are reflected in both the Lisp code and Maiko, you can run this part in an older Interlisp. Theoretically.

