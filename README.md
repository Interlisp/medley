# medley 
This repo is for the overall Lisp environment for Medley Interlisp.

A sub-project is Interlisp/maiko which is the emulator of the Lisp virtual machine. 

At the moment we're still in the process of sorting out what we have and insuring we start with a solid base.

File Names and Extensions: Most Interlisp source file names are
UPPERCASE and Interlisp didn't use file extensions for its source
files.  (note that any .TEDIT or .TXT file is probably documentation
for the package of same name, at least in the library,
internal/library, lispusers)

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


