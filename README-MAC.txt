To get Medley to run on a mac:

Copy this directory to your system.
Edit bin/medley to set MEDLEYDIR where you put it.

(not sure if *fonts belong in fonts)

You need a ~/.Xresources file with the line
    ldex.screen: 1408x832

or whatever value is in the geometry.


The display size is an interaction between the .Xresources file and
the -geometry parameter. The values are good for a Macbook Air, so the
whole Lisp display is visible in the window. You can change it for a
bigger display.

Set up a directory for your lisp init (e.g. /Users/Yourname/lisp)

The site greeting file LOCAL-INIT is in current/

Everything is relevant to the medley dir, and that is set in the
command file so that it is exposed inside lisp.

A function in the site greeting file (LOCAL-INIT) fixes meta key.

Make sure that the site greeting file loads the patches (especially
USERNAMEPATCH), otherwise you won't get your personal greet.

Work on rebuilding:

Ron has been able to recreate a make-init and build an INIT.DLINIT,
and Nick has built an ldeinit.  But it doesn't yet do what it is
supposed to do.  There is a brief description of what to do in the
liscore/sunloadup that we got, but what looks like a more
comprehensive description is in a Tedit file written in Japanese.  We
don't know how to get the text out to send to google translate.  And
even if I could get the text, I'm not sure that the old character
encoding can be deciphered.

Middle mouse button:

if you don't have a 3-button mouse (wheel = middle mouse)
you can enable FN-left to be middle. run in terminal window

 defaults write org.macosforge.xquartz.X11 enable_fake_buttons -boolean true
 defaults write org.macosforge.xquartz.X11 fake_button2 fn
 defaults write org.macosforge.xquartz.X11 fake_button3 none

To turn the settings back to the original default values do:

 defaults write org.macosforge.xquartz.X11 enable_fake_buttons -boolean false
 defaults delete org.macosforge.xquartz.X11 fake_button2
 defaults delete org.macosforge.xquartz.X11 fake_button3


