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
# set -x

tarball_dir=tmp/tarballs

#  Make sure we are in the right directory
if [ ! -f ./control-linux ];
then
  echo "Can't find ./control file."
  echo "Incorrect cwd?"
  echo "Should be in medley/installers/deb"
  echo "Exiting"
  exit 1
fi

# template for artifacts file names should be passed down in the ENV variable: ARTIFACTS_FILENAME_TEMPLATE
if [ -z "${ARTIFACTS_FILENAME_TEMPLATE}" ];
then
  ARTIFACTS_FILENAME_TEMPLATE="medley-full-@@PLATFORM@@-@@ARCH@@-@@MEDLEY.RELEASE@@_@@MAIKO.RELEASE@@"
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
  gh release download --repo interlisp/maiko --dir ${tarball_dir} --pattern "*.tgz"
  TAG=$(gh release list --repo interlisp/medley | head -n 1 | awk "{print \$1 }")
  gh release download ${TAG} --repo interlisp/medley --dir ${tarball_dir} --pattern "*.tgz"
  gh repo clone interlisp/notecards notecards -- --depth 1
  (cd notecards; git archive --format=tgz --output=../notecards.tgz --prefix=notecards/ main)
  mv notecards.tgz ${tarball_dir}
  rm -rf notecards
fi

# Figure out release tags from tarball names
pushd ${tarball_dir} >/dev/null 2>/dev/null
medley_release=$(echo medley-*-loadups.tgz | sed "s/medley-\(.*\)-loadups.tgz/\1/")
maiko_release=$(echo maiko-*-linux.x86_64.tgz | sed "s/maiko-\(.*\)-linux.x86_64.tgz/\1/")
popd >/dev/null 2>/dev/null


# For linux and wsl create packages for each arch
for wslp in linux wsl2 wsl1
do
  # For each arch create a deb file
  for arch_base in x86_64^amd64 armv7l^armhf aarch64^arm64
  do
    if [ "${arch_base}" = armv7l^armhf ]
    then
      if [ "${wslp}" = wsl1 ] || [ "${wslp}" = wsl2 ]
      then
        continue
      fi
    fi
    arch=${arch_base%^*}
    debian_arch=${arch_base#*^}
    pkg_dir=tmp/pkg/${wslp}-${arch}
    #
    # Set up the pkg directories for this arch using the release tarballs
    #
    #    Copy in the right control file, modifying as needed
    rm -rf ${pkg_dir}
    mkdir -p ${pkg_dir}
    mkdir -p ${pkg_dir}/DEBIAN
    sed \
      -e "s/--ARCH--/${debian_arch}/" \
      -e "s/--RELEASE--/${medley_release}_${maiko_release}/" \
      <control-${wslp} >${pkg_dir}/DEBIAN/control
    #
    il_dir=${pkg_dir}/usr/local/interlisp
    MEDLEYDIR=${il_dir#${pkg_dir}}/medley
    #    Maiko and Medley files to il_dir (/usr/local/interlisp)
    mkdir -p ${il_dir}
    if [ "${wslp}" = wsl1 ]
    then
      tar -x -z -C ${il_dir} \
                -f "${tarball_dir}/maiko-${maiko_release}-wsl1.${arch}.tgz"
    else
      tar -x -z -C ${il_dir} \
                -f "${tarball_dir}/maiko-${maiko_release}-linux.${arch}.tgz"
    fi
    tar -x -z -C ${il_dir} \
              -f "${tarball_dir}/medley-${medley_release}-runtime.tgz"
    tar -x -z -C ${il_dir} \
              -f "${tarball_dir}/medley-${medley_release}-loadups.tgz"
    tar -x -z -C ${il_dir} \
              -f "${tarball_dir}/notecards.tgz"
    # Copy the medley man page into place
    man_dir="${pkg_dir}/usr/local/man/man1"
    mkdir -p "${man_dir}"
    cp -p "${il_dir}/medley/docs/man-page/medley.1.gz" "${man_dir}"
    #     Configure postinst and postrm scripts and put in place in DEBIAN dir
    sed -e "s>--MEDLEYDIR-->${MEDLEYDIR}>g" <postinst >${pkg_dir}/DEBIAN/postinst
    chmod +x ${pkg_dir}/DEBIAN/postinst
    sed -e "s>--MEDLEYDIR-->${MEDLEYDIR}>g" <postrm >${pkg_dir}/DEBIAN/postrm
    chmod +x ${pkg_dir}/DEBIAN/postrm
    #     For wsl scripts, include the vncviewer.exe
    if [ "${wslp}" = wsl1 ] || [ "${wslp}" = wsl2 ]
    then
      if [ "${arch}" = x86_64 ]
      then
        pushd ./tmp >/dev/null
        rm -rf vncviewer64-1.12.0.exe
        wget -q https://sourceforge.net/projects/tigervnc/files/stable/1.12.0/vncviewer64-1.12.0.exe
        popd >/dev/null
        mkdir -p ${il_dir}/wsl
        cp -p tmp/vncviewer64-1.12.0.exe ${il_dir}/wsl/vncviewer64-1.12.0.exe
      fi
    fi
    #
    #  Make sure all files are owned by root
    #
    sudo su <<< "chown --recursive root:root ${il_dir}"
    #
    #  Create tar file for this arch
    #
    filename="$(echo ${ARTIFACTS_FILENAME_TEMPLATE} | sed -e "s#@@PLATFORM@@#${wslp}#" -e "s#@@ARCH@@#${arch}#" -e "s#@@MEDLEY.RELEASE@@#${medley_release}#" -e "s#@@MAIKO.RELEASE@@#${maiko_release}#" )"
    mkdir -p tars
    echo "Creating tar file tars/${filename}.tgz"
    tar -C ${il_dir} -czf tars/${filename}.tgz .
    #
    # Create the deb file for this arch
    #
    mkdir -p debs
    deb_filepath="debs/${filename}.deb"
    rm -rf "${deb_filepath}"
    dpkg-deb --build -Zxz "${pkg_dir}" "${deb_filepath}"
    #
  done
done

################################################################################################################
################################################################################################################
