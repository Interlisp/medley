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

-c [*FILE* | -], \-\-config [*FILE* | -]
: Use *FILE* as the config file for this run of Medley. See information on *CONFIG FILE* below.

    If the given value is "-",
then suppress the use of a config file for this run of Medley. 

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

-u, \-\-continue
:  Nullify any prior setting of the sysout file (e.g., from the config file) - causing Medley to start from
the virtual memory file resulting from the previous invocation (with the same values for --id and --logindir),
if any.  If there is no matching virtual memory file, Medley will start from the full.sysout (see -f/--full above).

    Equivalent to "-y -".

    (See *SYSOUT FILE* section below.) 

-y [*SYSOUT_FILE* | -], \-\-sysout [*SYSOUT-FILE* | -]
: Start Medley from the specified *SYSOUT-FILE*.  This is an alternative to specifying the *SYSOUT-FILE*
as the last argument on the command line (but before any *PASS_ON_ARGS*).  It can be used to specify the
*SYSOUT-FILE* in the config file (see information on *CONFIG FILE* below). 

    If the given value is "-", then
any prior setting of the sysout file (e.g., from the config file) is nullified (see -u/--continue above).

    (See *SYSOUT FILE* section below.) 

-e [+ | -], \-\-interlisp [+ | -]
: If value is "+" or no value, make the initial Exec window within Medley be an Interlisp Exec.
If value is "-", make the initial Exec window be the default XCL Exec.

    This flag applies only when the --apps flag is used.

-n [+ | -], \-\-noscroll [+ | -]
: Medley ordinarily displays scroll bars to enable the user to pan the Medley virtual display within the
Medley window.  This is true even when the entire virtual display fits within the window.

    Specifying
"-n +" (--noscroll +) turns off scroll bars.  Specifying "-n -" (--scroll -) turns on scroll bars.
Specifying -n (--noscroll) with no value is equivalent to specifying "--noscroll +".

    Default is scroll bars off. 

    Note: If scroll bars are off and the virtual screen is larger
than the window, there will be no way to pan to the non-visible parts of the virtual display.

-g [*WxH* | -], \-\-geometry [*WxH* | -]
: Sets the size of the X Window (or VNC window) that Medley runs in to be Width x Height. (Full X Windows
geomtery specification with +X+Y is not currently supported).

    If a value of "-" is given, geometry is set to the default value.

    If \-\-geometry is not specified but \-\-screensize is,
then the window size will be determined based on the \-\-screensize values and the \-\-noscroll flag.  If neither
\-\-geometry nor \-\-screensize is provided, then the window size is set to 1440x900 if \-\-noscroll is set and 1462x922
if \-\-noscroll is not set.

    (Also see note below under *CONFIG FILE* on the use of geometry and screensize
in config files.)

-s [*WxH* | -], \-\-screensize [*WxH* | -]
: Sets the size of the virtual display as seen from Medley's point of view. The Medley window is an unscaled viewport onto this virtual display. 

    If a value of "-" is given, screensize is set to the default value.

    If \-\-screensize is not specified but
\-\-geometry is, then the virtual display size will be set so that the entire virtual display fits into the given
window geometry.  If neither \-\-screensize nor \-\-geometry is provided, then the screen size is set to 1440x900.

    (Also see note below under *CONFIG FILE* on the use of geometry and screensize in config files.)

-ps [*N* | -], --pixelscale [*N* | -]&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Applicable only when display is SDL-based (e.g., on Windows/Cygwin)** \*\*
: Sets the pixel scaling factor to *N*, an integer

    If value of "-" is given, the pixel scale factor is set to its default of 1.

-t [*STRING* | -], \-\-title [*STRING* | -]
: Use *STRING* as title of Medley window.

    If *STRING* includes the character sequence "%i", then the value of the id string (see --id flag below)
prefixed by ":: " will be substituited for the "%i".  Example: if the id is "run_45" and *STRING* is "Medley Interlisp %i", then the actual window
title will be "Medley Interlisp :: run_45". 

    If the value of "-" is given, sets the title to its default value ("Medley Interlisp %i").

    This flag is ignored when when the \-\-vnc flag is set.

-d [*:N* | -], \-\-display [*:N* | -]
: Use X display *:N*.

    If value is "-", reset display to its default value. Default value is the value of $DISPLAY.
 
    On platforms that support both SDL and X Windows, set the value of -d (--display) to "SDL" to select using SDL instead of X Windows.  

    This flag is ignored on the Windows/Cygwin platform and when the \-\-vnc flag is
set on Windows System for Linux.

-v [+ | -] , \-\-vnc [+ | -]&nbsp;&nbsp;&nbsp;&nbsp;\*\* **Applicable only to WSL installations** \*\*
: If value is "+" or no value is given, then use a VNC window running on the Windows side instead of an X window.  If value is "-", then do not
use a VNC window, relying instead on a standard X Window.

    A VNC window will folllow the Windows desktop scaling setting allowing
for much more usable Medley on high resolution displays.  On WSL, X windows
do not scale well.

    This flag is always set for WSL1 installations.

-i [*ID_STRING* | - | \-\-], \-\-id [*ID_STRING* | - | \-\-]
: Use *ID_STRING* as the id for this run of Medley, unless the given value is "-", "\-\-", or "\-\-\-".

    Only one instance of Medley can be run simultaneously for any given id.

    *ID-STRING* can consist of any alphanumeric
character plus the underscore (_) character, ending (optionally) in a "+" character.  If *ID_STRING* ends with a "+"
(including just a singleton "+"),
then Medley will add a number to the id to make it unique among currently running Medley intsances.

    If the given value is "-", then the id will be (re)set to "default" (e.g., if it was previously set in the
config file).  If it is "\-\-", then id will be set to the basename of $MEDLEYDIR.
If ID_STRING is "\-\-\-", then id will be set to the basename of the parent directory of $MEDLEYDIR.

    Default id is "default".

-m [*N* | -], \-\-mem [*N* | -]
: Set Medley to run in *N* MB of virtual memory.  Defaults to 256MB.

   If a value of "-" is given, resets
to default value.

-p [*FILE* | -], \-\-vmem [*FILE* | -]
: Use *FILE* as the Medley virtual memory (vmem) store.  *FILE* must be writeable by the current user.

    Care must be taken not to use the same vmem FILE for two instances of Medley running simultaneously.
The \-\-id flag will not protect against vmem collisions when the \-\-vmem flag is used.

    If the value "-" is given, then resets the vmem file to the default.

    Default is to store the vmem in LOGINDIR/vmem/lisp_III.virtualmem, where III is the id of this
Medley run (see \-\-id flag above).  See \-\-logindir below for setting of LOGINDIR. 

-r \[*FILE* | -], \-\-greet \[*FILE* | -]
: Use *FILE* as the Medley greetfile.

    If the given value is "-",  Medley will start up without using a greetfile.

    The default Medley greetfile
is $MEDLEYDIR/greetfiles/MEDLEYDIR-INIT, except when the \-\-apps flag is used
in which case it is $MEDLEYDIR/greetfiles/APPS-INIT.

    On Windows/Cygwin installations, *FILE* is
specified in the Medley file system, not the host Windows file system.

-cm \[*FILE* | -], \-\-rem.cm \[*FILE* | -]
: Use *FILE* as the REM&#46;CM file that Medley reads and executes at startup - after any greet files.  Usually used only for loadups and other maintenance operations .

    If the given value is "-",  Medley will start up without using REM&#46;CM file.

    There is no default Medley REM&#46;CM file.

    On Windows/Cygwin installations, *FILE* is
specified in the Medley file system, not the host Windows file system.

-x \[*DIR* | - | --], \-\-logindir \[*DIR* | - | --]
: Use *DIR* as LOGINDIR in Medley.  *DIR* must be writeable by the current user.

    LOGINDIR is used by Medley as the working directory on start-up
and where it loads any "personal" initialization file from. 

    If the given value is "-", then reset LOGINDIR to its default value.
If the given value is "--", uses \$MEDLEYDIR/logindir as LOGINDIR.

    LOGINDIR defaults to \$HOME/il.

    On Windows/Cygwin installations, *FILE* is
specified in the Medley file system, not the host Windows file system.

-nh *Host:Port:Mac:Debug*, \-\-nethub *Host:Port:Mac:Debug*
: Set the parameters for using Nethub XNS networking.  *Host* is the full domain name of the nethub host.  *Port* is the port on *Host* that nethub is using.
*Mac* is the Mac address that this instance of Medley should use when contacting the nethub host.  *Debug* is the level of nethub debug information 
that should be printed on stdout (value is 0, 1, or 2).  A *Host* value is required and serves to turn nethub functionality on.  *Port*, *Mac* and *Debug*
parameters are optional and will default if left off.

    If any of the parameters have a value of "-", any previous setting (e.g., in a config file)
for the parameter will be reset to the default value - which in the case of *Host* is the null string, turning nethub functionality off.

-nf, -NF, --nofork
: No fork.  Relevant only to the Medley loadup workflow.

-prog *EXE*, --maikoprog *EXE*
: Use *EXE* as the basename of the Maiko executable.  Relevant only to the Medley loadup workflow.

--maikodir *DIR*
: Use *DIR* as the directory containing the Maiko emulator.  For testing purposes only.

-cc \[*FILE* | -], \-\-repeat \[*FILE* | -]
: Run Medley once.  And then as long as *FILE* exists and is greater then zero length, repeatedly run Medley using *FILE* as the REM&#46;CM file that Medley reads and executes at startup.  Each run of Medley can change the contents of *FILE* to effect the subsequent run of Medley.  To end the cycle, Medley needs to delete *FILE*.  WIthin Medley, *FILE* can be found as the value of the environment variable LDEREPEATCM.

    On Windows/Cygwin installations, *FILE* is
specified in the Medley file system, not the host Windows file system.

-am, --automation
: Useful only when using --vnc (and always on WSL1).  When calling medley as part of an automation script, often Medley
will run for a very short time (< a couple of seconds).  This can cause issues with medley code that detects Xvnc server failures.
Setting this flag notifies Medley that very short Medley sessions are possible and the Xvnc error detection needs to be adjusted accordingly.

-br [*BRANCH* | -], \-\-branch [*BRANCH* | -]
: By default, sysout files are loaded from the MEDLEYDIR/loadups directory.
If "\-\-branch *BRANCH*" is specified, then by default sysout files are loaded from the
MEDLEYDIR/loadups/branches/BRANCH directory.  The sysouts in these directories are created using
a loadups script with the \-\-branch flag set.  See the loadup man page.
If *BRANCH* is "-", then the name of the active git branch for MEDLEYDIR (if any) is used as
*BRANCH*. 



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
: All arguments after the "\-\-" flag, are passed unaltered to the Maiko emulator.


CONFIG FILE
===========
A config file can be used to "pre-specify" any of the above command line arguments.
The config file consists of command line arguments (flags or flag-value pairs), *one per line*.
These arguments are read from the config file and prepended to the arguments actually given on
the command line.  Since later arguments override earlier arguments, any argument actually given
on the command line will override a conflicting argument given in the config file.

Unless specified using the -c (--config) argument, the default config file will be $MEDLEYDIR/.medley_config,
if it exists, and $HOME/.medley_config, otherwise.

Specifying, "-c -" or "--config -" on the command line will suppress the use of config files for the
current run of Medley.

*Note:* care must be taken when using -g (--geometry) and/or -s (--screensize) arguments in config files.
If only one of these is specified, then the other is conputed.  But if both are specified, then the specified
dimensions are used as given.  Unexpected results can arise if one is specified in the config file 
but the other is specified on the command line. In this case, the two specified dimensions will be used as given.
It will not be the case, as might be expected, that the dimension given in the config file will be overridden
by a dimension computed from the dimension given on the command line.


OTHER FILES
===========

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

Copyright(c) 2023-2024 by Interlisp.org
