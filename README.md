# medley 
This repo is for the overall Lisp environment for Medley / Interlisp-D / Xerox Common Lisp.
A sub-project is Interlisp/maiko which is the emulator of the Lisp virtual machine. 

NOTES:

At the moment we're still in the process of sorting out what we have and insuring we start with a solid base.

File Names and Extensions: Most Interlisp source file names are UPPERCASE and Interlisp didn't use file extensions for its source directories.
(note that any .TEDIT or .TXT file is probably documentation for the package of same name, at least in the library, internal/library, lispusers)
The current repo has only Lisp sources with .LCOM and .DFASL in .gitignore. But many files don't compile in a vanilla lisp.sysout ;
there is a file of external declarations (EXPORTS.ALL) and something called ABC that has some other record package declarations.




a) get the binaries lde ldex for your machine (darwin.x86_64 (mac) linux.x86_64 (linux, use VirtualBox for windows, linux.arm??)
b) 'run-medley -xfull' should run the xfull sysout in the 'loadups' directory

Each directory should have a README.md, but briefly
docs -- Documentation files (either PDFs or online help)
fonts -- raster fonts in various resolutions for display, postscript, interpress, press formats)
initfiles -- should have any necessary setup of directories Lisp should look in for load
internal -- These _were_ internal to Venue
library  -- packages that were supported (30 years ago)
lispusers -- packages that were only half supported (ditto)
loadups   -- has sysouts and other builds
sources   -- sources for Interlisp and Common Lisp implementations)

Note that Interlisp and Common Lisp functions have different compilers, but it's all freely intermixed.


