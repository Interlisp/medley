
To set up to run medley on Windows:

You need either Docker for Desktop or WSL2.

If you have Docker you can just docker run interlisp/medley
use a VNC client to connect to localhost

If you want to run under WSL:

Get a windows X server called Xming, the default options will do:

     https://sourceforge.net/projects/xming/

Make Maiko following the instructions there, and 
copy lde ldex from linux.x86_64 into your path (/usr/local/bin)

export MEDLEYDIR=/mnt/c/path-to-medley-directory
export HOME=/mnt/c/path-to-windows-home
export DISPLAY=:0
export LDEINIT="$MEDLEYDIR"/greetfiles/local-init

lde -screen 1440x800 -g 1440x800 -d your-machine-ip:0 -bw 0 -t "Medley Interlisp" medley/loadups/xfull35.sysout &
