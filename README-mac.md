# Running Medley Interlisp on a Mac.

Running on MacOS requires an X server, and building on a Mac requires X client libraries. An X-server for x86 can be freely obtained at https://www.xquartz.org/. For the new arm64 MacOS 11, you'll need https://x.org which you can get via MacPorts or Brew.


### Middle-mouse tweak

if you don't have a 3-button mouse (wheel = middle mouse)
you can enable FN-left to be middle. Run in a terminal:

```sh
defaults write org.macosforge.xquartz.X11 enable_fake_buttons -boolean true
defaults write org.macosforge.xquartz.X11 fake_button2 fn
defaults write org.macosforge.xquartz.X11 fake_button3 none
```

To turn the settings back to the original default values do:

```sh
defaults write org.macosforge.xquartz.X11 enable_fake_buttons -boolean false
defaults delete org.macosforge.xquartz.X11 fake_button2
defaults delete org.macosforge.xquartz.X11 fake_button3
```

