#!/bin/bash
###############################################################################
#
#    build_deb.sh: build .deb files for installing Medley Interlisp on Linux 
#                  and WSL
#
#    2023-01-10 Frank Halasz
#
#    Copyright 2023 by Interlisp.org
#
###############################################################################
#

tarball_dir=tmp/tarballs

#  Make sure we are in the right directory
if [ ! -f ./control ];
then
  echo "Can't find ./control file."
  echo "Incorrect cwd?"
  echo "Should be in medley/installers/deb"
  echo "Exiting"
  exit 1
fi


#  If not running as a github action, then download the tarballs
if [ -z "${GITHUB_WORKSPACE}" ];
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
  gh release download --repo interlisp/maiko --dir ${tarball_dir} --pattern "*.tgz"
  gh release download --repo interlisp/medley --dir ${tarball_dir} --pattern "*.tgz"
fi

# Figure out release tags from tarball names
pushd ${tarball_dir} >/dev/null 2>/dev/null
medley_release=$(echo medley-*-loadups.tgz | sed "s/medley-\(.*\)-loadups.tgz/\1/")
maiko_release=$(echo maiko-*-linux.x86_64.tgz | sed "s/maiko-\(.*\)-linux.x86_64.tgz/\1/")
popd >/dev/null 2>/dev/null

# For each arch create a deb file
for arch_base in x86_64^amd64 armv7l^armhf aarch64^arm64
do
  arch=${arch_base%^*}
  debian_arch=${arch_base#*^}
  pkg_dir=tmp/pkg/${arch}
  #
  # set up the pkg directories for this arch using the release tarballs
  #
  mkdir -p ${pkg_dir}
  mkdir -p ${pkg_dir}/DEBIAN
  sed \
      -e "s/--ARCH--/${debian_arch}/" \
      -e "s/--RELEASE--/${medley_release}_${maiko_release}/" \
      <control >${pkg_dir}/DEBIAN/control
  #
  il_dir=${pkg_dir}/usr/local/interlisp
  mkdir -p ${il_dir}
  tar -x -z -C ${il_dir} \
            -f "${tarball_dir}/maiko-${maiko_release}-linux.${arch}.tgz"
  tar -x -z -C ${il_dir} \
            -f "${tarball_dir}/medley-${medley_release}-runtime.tgz"
  tar -x -z -C ${il_dir} \
            -f "${tarball_dir}/medley-${medley_release}-loadups.tgz"
  #
  # create the deb file for this arch
  #
  mkdir -p debs
  dpkg-deb --build ${pkg_dir} debs/medley-${medley_release}_${maiko_release}-${arch}.deb
done


