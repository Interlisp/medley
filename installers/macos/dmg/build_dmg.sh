#!/bin/bash
#hdiutil create -srcFolder dmg -o Medley.dmg -volname Medley_Install -format UDRW
#http://stackoverflow.com/questions/96882/how-do-i-create-a-nice-looking-dmg-for-mac-os-x-using-command-line-tools

set -o verbose #echo onset +o verbose #echo off

APP_NAME="Medley.app"
VOL_NAME="Medley_Install"
DMG_PATH=tmp/${VOL_NAME}
SRC_DIR=tmp/dmg_src
BG_NAME=Install_Message.png
WIN_WIDTH=700
WIN_HEIGHT=500

#
#  Cleanup anything leftover from last run
#
rm -rf ${SRC_DIR}
mkdir -p ${SRC_DIR}
rm -f ${DMG_PATH}.dmg
rm -f ${DMG_PATH}.temp.dmg

#
#  Assemble source directory for DMG
#
ditto tmp/${APP_NAME} ${SRC_DIR}/${APP_NAME}
SetFile -a B ${SRC_DIR}/Medley.app
ditto scripts/medley_add2path ${SRC_DIR}/medley_add2path
ditto images/${BG_NAME} ${SRC_DIR}/.background/${BG_NAME}
#
#  Create initial dmg image
#
hdiutil create -srcfolder ${SRC_DIR} -volname ${VOL_NAME} -fs HFS+ \
               -fsargs "-c c=64,a=16,e=16" -format UDRW ${DMG_PATH}.temp.dmg
device=$(\
          hdiutil attach -readwrite -noverify -noautoopen "${DMG_PATH}".temp.dmg \
          | egrep '^/dev/' | sed 1q | awk '{print $1}' \
        )

#
# cd to the new dmg
#
pushd /Volumes/${VOL_NAME} >/dev/null 2>&1

#
#  Add symbolic link for medley script and icon for addpath
#
ln -s Medley.app/Contents/MacOS/medley/scripts/medley/medley.command medley
if [ -z "$(which fileicon)" ];
then
  brew install fileicon
fi
fileicon set medley_add2path images/A2P_icon128.png

#
# Dress up the appearance using Applescript
#
ROW1=300
ROW2=550
COL1=86
COL2=286
COL3=486
osascript <<EOT
  tell application "Finder"
    tell disk "${VOL_NAME}"
      open
      set current view of container window to icon view
      set toolbar visible of container window to false
      set statusbar visible of container window to false
      set old_bounds to bounds of container window
      set l to item 1 of old_bounds
      set t to item 2 of old_bounds 
      set r to l + ${WIN_WIDTH}
      set b to t + ${WIN_HEIGHT} 
      set the bounds of container window to {l, t, r, b}
      set theViewOptions to the icon view options of container window
      set arrangement of theViewOptions to snap to grid
      set icon size of theViewOptions to 128
      set background picture of theViewOptions to file ".background:${BG_NAME}"
      set appHome to path to applications folder from system domain
      make new alias file at container window to appHome with properties {name:"Applications"}
      set appHome to path to applications folder from user domain
      make new alias file at container window to appHome with properties {name:"My Applications"}
      set appHome to path to home folder from user domain
      make new alias file at container window to appHome with properties {name:"My Home Folder"}
      delay 1
      set position of item "${APP_NAME}" of container window to     {${COL1}, ${ROW1}}
      set position of item "medley" of container window to          {${COL2}, ${ROW1}}
      set position of item "add2path" of container window to        {${COL3}, ${ROW1}}
      set position of item "Applications" of container window to    {${COL1}, ${ROW2}}
      set position of item "My Applications" of container window to {${COL2}, ${ROW2}}
      set position of item "My Home Folder" of container window to  {${COL3}, ${ROW2}}
    end tell
  end tell
EOT

#
# return to original dir
#
popd >/dev/null 2>&1

#  Detach the tmp dmg and convert it to final (compressed, ro) dmg
hdiutil detach ${device}
sync
hdiutil convert "${DMG_PATH}".temp.dmg -format UDZO -imagekey zlib-level=9 -o ${DMG_PATH}.dmg
rm -rf "${DMG_PATH}".temp.dmg
