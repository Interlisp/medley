# medley 
This repo is for the overall Lisp environment for Medley Interlisp.

A sub-project is [Interlisp/maiko](https://github.com/Interlisp/maiko) which is the implementation of the Lisp virtual machine. If you want to run on some other platform that we haven't tried, you just need to port/build Maiko.

Newcomers to Medley Interlisp should check out [Blake McBride's Introduction to Medley](https://github.com/Interlisp/medley-intro)

We've made great process in sorting out what we have (some dusty corners notwithstanding) and are gearing up to fix problems as they are found.

### [Building Medley Interlisp](https://github.com/Interlisp/medley/wiki/Building-Medley-Interlisp)
### [Running Medley Interlisp]((https://github.com/Interlisp/medley/wiki/Running-Medley-Interlisp)
### [Using Medley Interlisp](https://github.com/Interlisp/medley/wiki/Using-Medley-Interlisp)

## Naming conventions and directory structure

File Names and Extensions: Most Interlisp source file names are
UPPERCASE and Interlisp didn't use file extensions for its source
files. Note .TEDIT or .TXT file is probably documentation
for the package of same name, at least in the library,
internal/library, lispusers.

The current repo has both Lisp sources and compiled .LCOM and .DFASL
files, because some files don't compile in a vanilla lisp.sysout .

Each directory should have a README.md, but briefly
- basics -- old sysouts needed (for now) for rebuilding new sysouts
- docs -- Documentation files (either PDFs or online help)
- fonts -- raster fonts (or font widths) in various resolutions for display, postscript, interpress, press formats
- greetfiles -- should have any necessary setup of directories Lisp should look in for load
- internal -- These _were_ internal to Venue
- library  -- packages that were supported (30 years ago)
- lispusers -- packages that were only half supported (ditto)
- loadups   -- has sysouts and other builds
- makesysout -- files for making new sysouts for various configurations, based on basics
- patches -- ""
- sunloadup --  support information for making a new lisp.sysout from scratch
- sources   -- sources for Interlisp and Common Lisp implementations
- unicode  -- data files for support of XCCS to and from Unicode mappings

plus
   Dockerfile, and scripts for building and running medley
