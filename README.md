# Medley 

The [Medley Interlisp Project](https://interlisp.org) aims to preserve, revive, and modernize the [Interlisp](https://interlisp.org) software development environment for rapid prototyping, research and Artificial Intelligence created at Xerox PARC since the 1970s.

This repository is for the Lisp environment of the [Medley](https://interlisp.org) release of Interlisp. Other repositories hold additional subsystems and applications such as [Maiko](https://github.com/Interlisp/maiko), the implementation (in C) of the Medley virtual machine, the [LOOPS](https://github.com/Interlisp/loops) object-oriented extension of Interlisp, and the [NoteCards](https://github.com/Interlisp/notecards) hypermedia system.

[Install and Run](https://interlisp.org/software/install-and-run) covers ways to install and start up Medley on Linux systems, MacOS, Windows (with or without WSL), and in a web browser.

[Using Medley](https://interlisp.org/software/using-medley/) has an overview and pointers to documentation.

The [Glossary](https://interlisp.org/history/glossary) defines system-specific terms such as "loadup" and "sysout".

## Releases

While there are installers for popular platforms, this section may be useful in some circumstances.

### Getting releases 

Get the Maiko release [here](https://github.com/Interlisp/maiko/releases). You'll need the .tgz file corresponding to your operating system and processor. For Windows with WSL or Intel Linux, use `linux.x86_64`; for Macs use `darwin.x86_64` for Intel and `darwin.aarch64` for Mac silicon. Windows without WSL uses `cygwin` instead.

Or, build your own maiko (the binaries `lde`, `ldex` OR `ldesdl`, and `ldeinit`).
You can also build for other architectures

The medley release image and sources come in two parts, found [here](https://github.com/Interlisp/medley/releases)
1. The "loadups" (download `medley-`_YYMMDD-XXXXX_`-loadups.tgz`)
2. The "runtime" (download `medley-`_YYMMDD-XXXXX_`-runtime.tgz`)

where _YYMMDD_ is the date and _XXXXX_ is the GitHub commit ID.

The "runtime" isn't needed if you've cloned the (medley) repo--you have all the files. The "runtime" has extra fonts, unicode tables, and source code that aren't part of the loadups but may be called on.

### Unpacking releases

From a shell/terminal window:

1. Choose a directory _parent_ where you want to install medley and maiko. 
2. Unpack the medley loadups file

* `cd ` _parent_
* `tar xvzf medley-`_YYMMDD-XXXXX_`-loadups.tgz`

3. Unpack the medley runtime OR clone the Medley repo
   (the "medley runtime" is just a subset of the whole repo)
   
* `tar xvzf medley-`YYMMDD`-runtime.tgz` 

   OR
   ```
   git clone https://github.com/Interlisp/medley
   ```
   
4. Unpack the maiko file for your operating system and CPU type, e.g.,

   ```
   tar xvzf maiko-210823.linux.x86_64.tgz
   ```

5. This should leave you with two directories, `medley` and `maiko`.

### Setting up X

In many configurations, Medley uses an X-Server to manage its display. Most Linux desktops have one. Windows 11 with WSL includes an X-Server. For Windows 10 with WSL2, there are a number of open-source X servers; for example vcxsrv.

Mac users should get [XQuartz from XQuartz.org](https://xquartz.org/releases).

Medley manages the display entirely, doesn't use X fonts and manages it's own window system.

If you have a high-resolution display, note that much of the graphics was designed for a low-resolution display, so an X-server that does "pixel doubling" is best. (E.g., Raspberry Pi does pixel doubling on 4K displays.)

Medley presumes you have a 3-button mouse; the scroll-wheel on some mice acts as one, with some difficulty. Go into XQuartz Preferences/Input and check "Emulate three button mouse" option.

### Running Medley Interlisp

The primer [Medley Interlisp for the Newcomer](https://primer.interlisp.org) eases new users into the Interlisp environment. It assumes no prior knowledge of Lisp and covers the user interface, programming and debugging, windows and graphics, and more. We recommend consulting this document to learn how to run and use the system.

### Exiting The System

The system may be exited from the Interlisp prompt by typing:

```
(LOGOUT)
```

Or from the Common Lisp prompt with:
```
(IL:LOGOUT)
```
When you log out of the system, Medley automatically creates a binary
dump of your system located in your home directory named
`lisp.virtualmem`. The next time you run the system, if you don't
specify a specific image to run, Medley restores that image so that
you can continue right where you left off.

* [Using Medley Interlisp](https://interlisp.org/doc/info/Using.html)

## Naming conventions and directory structure

File Names and Extensions: Most Interlisp source file names are
UPPERCASE and Interlisp didn't use file extensions for its source
files. A .TEDIT or .TXT file is probably documentation
for the package of the same name, at least in the library and lispusers
directories.

The current repo has both Lisp sources and compiled .LCOM and .DFASL
files.

Each directory should have a README.md, but briefly

* BUILDING.md -- instructions on how to make your own loadups
* clos -- early implementation of Common Lisp Object System
* CLTL2 -- files submitted to bring Medley up to the conformance to "Common Lisp, the Language" 2nd edition. Not enough to conform to the ANSI standard lisp.
* docs -- Documentation files (in TEdit format, PDFs, or online help
* fonts -- raster fonts (or font widths) in various resolutions for display, postscript, interpress, press formats
* greetfiles -- various configuration setups
* internal -- These _were_ internal to Venue
* library  -- packages that were supported (30 years ago)
* lispusers -- User contributed packages that were only half supported (ditto)
* loadups   -- has sysouts and other builds plus a few remnants
* obsolete  -- files we should remove from the repo
* rooms -- implementation of ROOMS window/desktop manager
* run-medley -- script to enhance the options of running medley
* scripts  -- some scripts for fixing up things, building and running medley
* sources   -- sources for Interlisp and Common Lisp implementations
* unicode  -- data files for support of XCCS to and from Unicode mappings
