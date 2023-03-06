#!/bin/bash
###############################################################################
#
#    build_dmg.sh: build dmg for installing Medley Interlisp on MacOS
#                  based on Medley.app built by build_app.sh
#
#    2023-03-03 Frank Halasz
#
#    Copyright 2023 by Interlisp.org
#
#    Based on code found at:
#    http://stackoverflow.com/questions/96882/how-do-i-create-a-nice-looking-dmg-for-mac-os-x-using-command-line-tools 
#
###############################################################################

#set -o verbose #echo onset +o verbose #echo off

#
#  Set Parameters
#
APP_NAME="Medley.app"
VOL_NAME="Medley_Install"
DMG_NAME=medley-full-VERSION-macos-universal.dmg
BG_NAME=Install_Message.png
WIN_WIDTH=700
WIN_HEIGHT=850

#
#  Set pathnames
#
CWD=$(pwd)
TMP_DIR=${CWD}/tmp
RESULTS_DIR=${CWD}/artifacts
APP_PATH=${RESULTS_DIR}/${APP_NAME}
DMG_PATH=${RESULTS_DIR}/${VOL_NAME}
SRC_DIR=${TMP_DIR}/dmg_src
IMAGES_DIR=${CWD}/images
SCRIPTS_DIR=${CWD}/scripts

#
#  Make sure we are in the right directory
#
if [ ! -e ${APP_PATH} ];
then
  echo "Can't find the app: ${APP_NAME}."
  echo "Incorrect cwd?  Should be in medley/installers/macos."
  echo "Or build_app.sh not yet run?"
  echo "Exiting"
  exit 1
fi

#
#  Copy over files from build app etc to dmg proto-directory
#
if [ ! "$1" = "-c" ]
then
  #
  #  Cleanup anything leftover from last run
  #
  rm -rf ${SRC_DIR}
  mkdir -p ${SRC_DIR}

  #
  #  Assemble source directory for DMG
  #
  ditto ${APP_PATH} ${SRC_DIR}/${APP_NAME}
  SetFile -a B ${SRC_DIR}/${APP_NAME}
  ditto ${SCRIPTS_DIR}/medley_add2path ${SRC_DIR}/medley_add2path
  ditto ${IMAGES_DIR}/${BG_NAME} ${SRC_DIR}/.background/${BG_NAME}
fi

#
#  Create initial dmg image
#
if [ -e "/Volumes/${VOL_NAME}" ];
then
  hdiutil detach /Volumes/${VOL_NAME}
fi
rm -f ${DMG_PATH}.temp.dmg
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
fileicon set medley_add2path ${IMAGES_DIR}/A2P_icon128.png

#
# Dress up the appearance using Applescript
#
ROW1=375
ROW2=650
COL1=139
COL2=350
COL3=561
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
      set position of item "medley_add2path" of container window to {${COL3}, ${ROW1}}
      set position of item "Applications" of container window to    {${COL1}, ${ROW2}}
      set position of item "My Applications" of container window to {${COL2}, ${ROW2}}
      set position of item "My Home Folder" of container window to  {${COL3}, ${ROW2}}
      close
    end tell
  end tell
EOT

#
# Add icon to dmg
#
fileicon set /Volumes/${VOL_NAME} ${IMAGES_DIR}/Install_icon128.png

#
# return to original dir
#
popd >/dev/null 2>&1

#
#  Detach the tmp dmg and convert it to final (compressed, ro) dmg
#
hdiutil detach ${device}
sync
rm -f ${DMG_PATH}.dmg
hdiutil convert "${DMG_PATH}".temp.dmg -format UDZO -imagekey zlib-level=9 -o ${DMG_PATH}.dmg
rm -rf "${DMG_PATH}".temp.dmg

#
#  Extract version info from app Info.plist & rename dmg using version
#
sed_script='{/CFBundleVersion/!d;N;s/^.*<string>\(.*\)<\/string>/\1/;s/.0$//;s/\./_/;p;}'
version=$(sed -ne "${sed_script}" ${SRC_DIR}/${APP_NAME}/Contents/Info.plist)
mv ${DMG_PATH}.dmg ${RESULTS_DIR}/${DMG_NAME/VERSION/${version}}

#
#  Done
#
echo "DMG build completed."
base_name=${DMG_NAME/VERSION/${version}}
base_name=${base_name%.dmg}
echo "=====${base_name}"


###############################################################################
