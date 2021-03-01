# Medley 




This repository is for the Lisp environment of [Medley Interlisp](https://Interlisp.org).

We've made great process in sorting out what we have (some dusty corners notwithstanding), but there's quite a bit more work to do. Please report problems!

See [Medley Interlisp Wiki](https://github.com/Interlisp/medley/wiki/) for an overview, and other pointers.

A sub-project is [Interlisp/maiko](https://github.com/Interlisp/maiko), which is the implementation (in C) of the Medley virtual machine. 


## Instructions for Building and Running

### Setting up X

Medley Interlisp needs an X-Server to manage its display. Most Linux desktops have one. There are a number of free open source X-servers for windows. Mac users should head over to [XQuartz.org](https://xquartz.org/releases) -- be sure to pick a version if you have a newer Mac.

If you have a high-resolution display, note that much of the graphics was designed for a low-resolution display, so an X-server that does "pixel doublilng" is best. (E.g., Raspberry Pi does pixel doubling on 4K displays.) It also presumes you have a 3-button mouse; the scroll-wheel on some mice act as one with some difficulty.) XQuartz Preferences/Input has "Emulate three button mouse" option.


### Running Medley Interlisp

The `run-medley` script in this repo sets up some convenient defaults. Running Medley can be done by typing:
```
$ cd medley
$ ./run-medley
```

Or, if you wish to start Medley up with a different SYSOUT:

```
$ cd medley
$ ./run-medley <SYSOUT-file-name>
```

Once the system comes up, give it a few seconds to initialize.

The first time the system is run it loads the system image that comes
with the system.  When you exit the system (or "do a `SaveVM`" menu
option) the state of your machine is saved in a file named
`~/lisp.virtualmem`.  Subsequent system startups load the
`~/lisp.virtualmem` image by default.

### Exiting The System

The system may be exited from the Interlisp prompt by typing:

```
(LOGOUT)
```

Or from the Common Lisp prompt with:
```
(IL:LOGOUT)
```
When you logout of the system, Medley automatically creates a binary
dump of your system located in your home directory named
`lisp.virtualmem`. The next time you run the system, if you don't
specify a specific image to run, Medley restores that image so that
you can continue right where you left off.

* [Using Medley Interlisp](https://github.com/Interlisp/medley/wiki/Using-Medley-Interlisp)


## Naming conventions and directory structure

File Names and Extensions: Most Interlisp source file names are
UPPERCASE and Interlisp didn't use file extensions for its source
files. A .TEDIT or .TXT file is probably documentation
for the package of same name, at least in the library,
internal/library, lispusers.

The current repo has both Lisp sources and compiled .LCOM and .DFASL
files, because some files don't compile in a vanilla lisp.sysout .

Each directory should have a README.md, but briefly

- docs -- Documentation files (either PDFs or online help)
- fonts -- raster fonts (or font widths) in various resolutions for display, postscript, interpress, press formats
- greetfiles -- various configuration setups
- internal -- These _were_ internal to Venue; now internal/library and internal/test
- library  -- packages that were supported (30 years ago)
- lispusers -- packages that were only half supported (ditto)
- loadups   -- has sysouts and other builds
- patches -- for cases where reloading doesn't wor
- scripts  -- some scripts for fixing up things
- sunloadup --  support information for making a new lisp.sysout from scratch
- sources   -- sources for Interlisp and Common Lisp implementations
- unicode  -- data files for support of XCCS to and from Unicode mappings

plus
   Dockerfile, and scripts for building and running medley
