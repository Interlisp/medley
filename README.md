# Medley 

This repository is for the Lisp environment of [Medley Interlisp](https://Interlisp.org).

We've made great process in sorting out what we have (some dusty corners notwithstanding), but there's quite a bit more work to do. Please report problems!

See [Medley Interlisp Wiki](https://github.com/Interlisp/medley/wiki/) for an overview, and other pointers.

A sub-project is [Interlisp/maiko](https://github.com/Interlisp/maiko), which is the implementation (in C) of the Medley virtual machine.

## Using releases

There are separate releases of medley and maiko.  Just get the latest version of each.

Alternatively, you can pick up the medley release, and build your own maiko (which is delivered as binaries `lde` `ldex` and `ldeinit`.) We can build for other OS arch pairs depending on what is available for GitHub actions.

Get the Maiko release [here](https://github.com/Interlisp/maiko/releases). You'll need the one corresponding to your operating system and processor (for Windows with WSL or Intel linux, use `linux.x86_64`; for Macs use `darwin.x86_64` for Intel and `darwin.aarch64` for M1.)

The medley release comes in two parts, found [here](https://github.com/Interlisp/medley/releases)
1. The "loadups" (download `medley-`YYMMDD`-loadups.tgz`)
2. The "runtime" (download `medley-`YYMMDD`-runtime.tgz`)

To download both using the 'gh' GitHub command line:
```
   gh release download -R Interlisp/medley -p "*"
```

 (from a shell/terminal window):

1. Unpack the medley loadups file
   ```
   tar -xvfz medley-211015-loadups.tgz
   ```

2. Unpack the medley runtime OR clone the Medly repo
   (the "medley runtime" is just a subset of the whole repo)
   
   ```
   git clone https://github.com/Interlisp/medley
   ```
   OR
   ```
   tar -xvfz medley-211015-runtime.tgz
   ```
   
3. Unpack the maiko file for your operating system and CPU type, e.g.,

   ```
   tar -xvfz maiko-210823.linux.x86_64.tgz
   ```

3. This should leave you with two directories, `medley` and `maiko`.

### Setting up X

Medley Interlisp needs an X-Server to manage its display. Most Linux desktops have one. Windows 11 with WSL includes an X-Server. For Windows 10 with WSL2, there are a number of open-source X servers; for example vcxsrv.

Mac users should get [XQuartz from XQuartz.org](https://xquartz.org/releases).

Medley manages the display entirely, doesn't use X fonts and manages it's own window system.

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
