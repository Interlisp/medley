#!/bin/bash
###############################################################################
#
#    build_app.sh: build app bundle for installing Medley Interlisp on MacOS
#
#    2023-02-23 Frank Halasz
#
#    Copyright 2023 by Interlisp.org
#
###############################################################################

APPNAME=Medley
APPBUNDLE=tmp/${APPNAME}.app
APPBUNDLECONTENTS=${APPBUNDLE}/Contents
APPBUNDLEEXE=${APPBUNDLECONTENTS}/MacOS
APPBUNDLERESOURCES=${APPBUNDLECONTENTS}/Resources
APPBUNDLEICON=${APPBUNDLECONTENTS}/Resources

tarball_dir=tmp/tarballs

#  Make sure we are in the right directory
if [ ! -f ./app/Info.plist ];
then
  echo "Can't find ./app/Info.plist file."
  echo "Incorrect cwd?"
  echo "Should be in medley/installers/macos"
  echo "Exiting"
  exit 1
fi


#  If running as a github action or -t arg, then skip downloading the tarballs
if ! [[ -n "${GITHUB_WORKSPACE}" || "$1" = "-t" ]];
then
  #  First, make sure gh is available and we are logged in to github
  if [ -z "$(which gh)" ];
  then
    echo "Can't find gh"
    echo "Exiting."
    exit 2
  fi
  gh auth status 2>&1 | grep --quiet --no-messages "Logged in to github.com"
  if [ $? -ne 0 ];
  then
    echo "Not logged into github."
    echo "Exiting."
    exit 3
  fi
  # then clear out the ./tmp directory
  rm -rf ./tmp
  mkdir ./tmp
  # then download the maiko and medley tarballs
  mkdir -p ${tarball_dir}
  echo "Fetching maiko and medley release tarballs"
  TAG=$(gh release list --repo interlisp/maiko | head -n 1 | awk "{print \$1 }")
  gh release download ${TAG} \
                      --repo interlisp/maiko \
                      --dir ${tarball_dir} \
                      --pattern "*darwin*.tgz"
  TAG=$(gh release list --repo interlisp/medley | head -n 1 | awk "{print \$1 }")
  gh release download ${TAG} \
                      --repo interlisp/medley \
                      --dir ${tarball_dir} \
                      --pattern "*-loadups.tgz" \
                      --pattern "*-runtime.tgz"
  gh repo clone interlisp/notecards notecards -- --depth 1
  (cd notecards; git archive --format=tgz --output=../notecards.tgz --prefix=notecards/ main)
  mv notecards.tgz ${tarball_dir}
  rm -rf notecards
fi

# Figure out release tags from tarball names
pushd ${tarball_dir} >/dev/null 2>/dev/null
medley_release=$(echo medley-*-loadups.tgz | sed "s/medley-\(.*\)-loadups.tgz/\1/")
maiko_release=$(echo maiko-*-darwin.x86_64.tgz | sed "s/maiko-\(.*\)-darwin.x86_64.tgz/\1/")
#debs_filename_base="medley-full-${medley_release}_${maiko_release}"
popd >/dev/null 2>/dev/null

#
#  Create bundle dirs
#
rm -rf ${APPBUNDLE}
mkdir ${APPBUNDLE}
mkdir ${APPBUNDLE}/Contents
mkdir ${APPBUNDLE}/Contents/MacOS
mkdir ${APPBUNDLE}/Contents/Resources
#
#  Create icons and put in bundle
#
rm -rf tmp/${APPNAME}.iconset
mkdir -p tmp/${APPNAME}.iconset
sips -z 16 16     images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_16x16.png >/dev/null 2>&1
sips -z 32 32     images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_16x16@2x.png >/dev/null 2>&1
sips -z 32 32     images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_32x32.png >/dev/null 2>&1
sips -z 64 64     images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_32x32@2x.png >/dev/null 2>&1
sips -z 128 128   images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_128x128.png >/dev/null 2>&1
sips -z 256 256   images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_128x128@2x.png >/dev/null 2>&1
sips -z 256 256   images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_256x256.png >/dev/null 2>&1
sips -z 512 512   images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_256x256@2x.png >/dev/null 2>&1
sips -z 512 512   images/${APPNAME}Icon.png --out tmp/${APPNAME}.iconset/icon_512x512.png >/dev/null 2>&1
cp images/${APPNAME}Icon.png tmp/${APPNAME}.iconset/icon_512x512@2x.png
iconutil -c icns -o tmp/${APPNAME}.icns tmp/${APPNAME}.iconset
cp tmp/${APPNAME}.icns ${APPBUNDLEICON}/
rm -r tmp/${APPNAME}.iconset
rm tmp/${APPNAME}.icns
#
#  Update and copy in "control" files
#
sed -e "s/--VERSION_TAG--/${medley_release}.${maiko_release}.0/g" \
    < app/Info.plist \
    > ${APPBUNDLECONTENTS}/Info.plist
cp app/PkgInfo ${APPBUNDLECONTENTS}/
#
#  Untar the maiko and medley releases into the bundle
#
il_dir=${APPBUNDLE}/Contents/MacOS
mkdir -p ${il_dir}
tar -x -z -C ${il_dir} \
          -f "${tarball_dir}/maiko-${maiko_release}-darwin.universal.tgz"
tar -x -z -C ${il_dir} \
          -f "${tarball_dir}/medley-${medley_release}-runtime.tgz"
tar -x -z -C ${il_dir} \
          -f "${tarball_dir}/medley-${medley_release}-loadups.tgz"
tar -x -z -C ${il_dir} \
          -f "${tarball_dir}/notecards.tgz"
#
#  Handle run_medley needing separate directories for each arch
#
pushd ${il_dir}/maiko >/dev/null 2>&1
ln -s darwin.universal darwin.aarch64
ln -s darwin.universal darwin.x86_64
popd >/dev/null 2>&1
#
#  Handle medley shell vs medley.command to make launching Medley easier
#
ln ${il_dir}/medley/scripts/medley/medley.sh ${il_dir}/medley/scripts/medley/medley.command
pushd ${il_dir}/medley >/dev/null 2>&1
rm medley
ln -s scripts/medley/medley.command medley
popd >/dev/null 2>&1

######################################################################################################
#
#   pkgbuild --component Medley.app --install-location /tmp Medley-base.pkg
#   productbuild --distribution Distribution.xml Medley.pkg
#
#
#
