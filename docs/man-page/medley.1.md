% MEDLEY(1) | Start Medley Interlisp

---
adjusting: l
hyphenate: false
---

NAME
====

**medley** — starts up Medley Interlisp

SYNOPSIS
========

| **medley** \[ flags ... ] \[ *SYSOUT_FILE* ] \[ \-\- *PASS_ON_ARGS* ]

DESCRIPTION
===========

Starts Medley Interlisp in a window.

OPTIONS
=======

**MEDLEYDIR** is an environment variable set by Medley and used by many of the options described below.
MEDLEYDIR is the top level directory of the Medley installation that contains the specific medley script that
is invoked after all symbolic links are resolved.  In the standard global installation this will 
be /usr/local/interlisp/medley.  But Medley can be installed in multiple places on any given machine and
hence MEDLEYDIR is computed on each invocation of medley. 


Flags
-----

&nbsp;

-h, \-\-help
: Prints out a brief summary of the flags and arguments to medley.

-z, \-\-man
: Show the man page for medley

-f, \-\-full
: Start Medley from the standard "full" sysout. full.sysout includes a complete Interlisp and CommonLisp environment
with a standard set of development tools.  It does not include any of the applications built using Medley.
(See *SYSOUT_FILE* below for more information on starting sysouts.)

-l, \-\-lisp
: Start Medley from the standard "lisp" sysout.  lisp.sysout only includes the basic Interlisp and
CommonLisp environment.
(See *SYSOUT_FILE* below for more information on starting sysouts.)

-a, \-\-apps
: Start Medley from the standard "apps" sysout.  apps.sysout includes everything in full.sysout plus Medley
applications including Notecards, Rooms and CLOS.  It also includes pre-installed links to key Medley
documentation.
(See *SYSOUT_FILE* below for more information on starting sysouts.)

-e, \-\-interlisp (relevent only when \-\-apps is specified)
: Make the initial Exec window within Medley be an Interlisp Exec.  Default is to start in an XCL Exec.

-n, \-\-noscroll
: Ordinarily Medley displays scroll bars to enable the user to pan the Medley virtual display within the
Medley window.  This is true even when the entire virtual display fits within the window.  Specifying
\-\-noscroll turns off the scroll bars.  Note: If \-\-noscroll is specified and the virtual screen is larger
than the window, there will be no way to pan to the non-visible parts of the virtual display.

-g *WxH*, \-\-geometry *WxH*
: Sets the size of the X Window (or VNC window) that Medley runs in to be Width x Height. (Full X Windows
geomtery specification with +X+Y is not currently supported).  If \-\-geometry is not specified but \-\-screensize is,
then the window size will be determined based on the \-\-screensize values and the \-\-noscroll flag.  If neither
\-\-geometry nor \-\-screensize is provided, then the window size is set to 1440x900 if \-\-noscroll is set and 1462x922
if \-\-noscroll is not set.

-s *WxH*, \-\-screensize *WxH*
: Sets the size of the virtual display as seen from Medley's point of view.
The Medley window is an unscaled viewport onto this virtual display. If \-\-screensize is not specified but
\-\-geometry is, then the virtual display size will be set so that the entire virtual display fits into the given
window geometry.  If neither \-\-screensize nor \-\-geometry is provided, then the screen size is set to 1440x900.

-t *STRING*, \-\-title *STRING*
: Use STRING as title of Medley window.  Ignored when when the \-\-vnc flag is set or when running on Windows (Docker)
installations.

-d *:N*, \-\-display *:N*&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Not applicable to Windows (Docker) installations** \*\*
~ Use X display :N.  Defaults to the value of $DISPLAY.  This flag is ignored when the \-\-vnc flag is set as
well as on Windows (Docker) installations.

-v, \-\-vnc&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Applicable only to WSL installations** \*\*
: Use a VNC window running on the Windows side instead of an X window.
The VNC window will folllow the Windows desktop scaling setting allowing
for much more usable Medley on high resolution displays.  On WSL, X windows
do not scale well.  This flag is always set for WSL1 installations.

-i [*ID_STRING* | - | \-\-], \-\-id [*ID_STRING* | - | \-\-]
: Use ID_STRING as the id for this run of Medley, iunless ID_STRING is "-" or "\-\-". 
If ID_STRING is "-", then use the basename of $MEDLEYDIR as the id.
If ID_STRING is "\-\-", then use the basename of the parent directory of $MEDLEYDIR as the id.
Only one instance of Medley with a given id can run at a time.
The id is used to distinguish the virtual memory stores so that multiple
instances of Medley can run simultaneously.  Default id is "default".

-m *N*, \-\-mem *N*
: Set Medley to run in *N* MB of virtual memory.  Defaults to 256MB.

-p *FILE*, \-\-vmem *FILE*
: Use FILE as the Medley virtual memory (vmem) store.  FILE must be writeable by the current user.
Care must be taken not to use the same vmem FILE for two instances of Medley running simultaneously.
The \-\-id flag will not protect against vmem collisions when the \-\-vmem flag is used.
Default is to store the vmem in LOGINDIR/vmem/lisp_XXX.virtualmem, where XXX is the id of this
Medley run (see \-\-id flag above).  See \-\-logindir below for setting of LOGINDIR. On Windows (Docker) installations, *FILE* is specified in the Medley file system, not the host Windows file system.

-r \[*FILE* | -], \-\-greet \[*FILE* | -]
: Use FILE as the Medley greetfile, unless FILE is "-" in which case
Medley will start up without using a greetfile. The default Medley greetfile
is $MEDLEYDIR/greetfiles/MEDLEYDIR-INIT, except when the \-\-apps flag is used
in which case it is $MEDLEYDIR/greetfiles/APPS-INIT. On Windows (Docker) installations, *FILE* is
specified in the Medley file system, not the host Windows file system.

-x \[*DIR* | -], \-\-logindir \[*DIR* | -]&nbsp;&nbsp;&nbsp;&nbsp;\*\* **On Linux and WSL installations** \*\*
: Use DIR as LOGINDIR in Medley, unless DIR is "-", in which case use
\$MEDLEYDIR/logindir.  DIR (or \$MEDLEYDIR/logindir) must be writeable by the current user.
LOGINDIR defaults to \$HOME/il.  LOGINDIR is used by Medley as the working directory on start-up
and where it loads any "personal" initialization file from.

-x \[*DIR* | -], \-\-logindir \[*DIR* | -]&nbsp;&nbsp;&nbsp;&nbsp;\*\* **On Windows (Docker) installations** \*\*
: Map DIR in the Windows host file system to /home/medley/il in the Medley
file system (in the Docker container).  LOGINDIR is always /home/medley/il from Medley's standpoint.  The "-" value is not valid in this case.

-u, \-\-update&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Windows (Docker) installations only** \*\*
: Before running Medley, do a pull to retrieve the latest interlisp/medley docker image from Docker Hub.

-b, \-\-background&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Windows (Docker) installations only** \*\*
: Run Medley in background rather than foreground.

-p *PORT*, \-\-port *PORT*&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Windows (Docker) installations only** \*\*
: Use *PORT* as the port that VNC viewer uses to contact the VNC server within the Docker container.  Default is 5900.

-w \[*DISTRO* | -], \-\-wsl \[*DISTRO* | -]&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Windows (Docker) installations only** \*\*
: Run Medley in the context of the named WSL *DISTRO* instead of within Docker.  If *DISTRO* is "-", used the default WSL distro.  Equivalent to typing "wsl -d *DISTRO* medley ..." into a Command or Powershell window.


Other Options
-------------
&nbsp;

*SYSOUT_FILE*
: The pathname of the file to use as a sysout for Medley to start from.  If SYSOUT_FILE is not
provided and none of the flags (\-\-apps, \-\-full, \-\-lisp) is used, then Medley will start from
the saved virtual memory file from the previous session with the same ID_STRING as this run.
If no such virtual memory file exists, then Medley will start from the standard full.sysout
(equivalent to specifying the \-\-full flag).  On Windows (Docker) installations, *SYSOUT_FILE* is
specified in the Medley file system, not the host Windows file system.

*PASS_ON_ARGS*
: All arguments after the "\-\-" flag, are passed unaltered to lde via run-medley.


FILES
=====

\$HOME/il
:  Default Medley LOGINDIR

\$HOME/il/vmem/lisp.virtualmem
: Default virtual memory file

\$HOME/il/INIT(.LCOM)
: Default personal init file

\$MEDLEYDIR/greetfiles/MEDLEYDIR-INIT(.LCOM)
:   Default Medley greetfile


BUGS
====

See GitHub Issues: <https://github.com/Interlisp/medley/issues>

COPYRIGHT
=========

Copyright(c) 2023 by Interlisp.org
