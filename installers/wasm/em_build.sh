#!/bin/sh
###############################################################################
#
#    em_build.sh - script to package the Medley file system into a series of
#        Emscripten preload-file packages and to packe these packages
#        together with a emscriptem Maiko and the medley.html startup
#        page to make a emscripten Medley release tar.
#
#    Frank Halasz 2024-02-07
#
#    Copyright 2024 by Interlisp.org
#
###############################################################################

# functions to discover what directory this script is being executed from
get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

get_script_dir() {

    # call this with ${BASH_SOURCE[0]:-$0} as its (only) parameter

    # set -x

    local SCRIPT_PATH="$( get_abs_filename "$1" )";

    CWD="$( pwd )"

    while [ -h "$SCRIPT_PATH" ];
    do
        cd "$( dirname -- "$SCRIPT_PATH"; )";
        SCRIPT_PATH="$( readlink -f -- "$SCRIPT_PATH"; )";
    done

    cd "$( dirname -- "$SCRIPT_PATH"; )" > '/dev/null';
    SCRIPT_PATH="$( pwd; )";

    cd "${CWD}"

    # set +x

    echo "${SCRIPT_PATH}"
}

#
#  Check for emscriptem and find em tools directory
#
if [ -z "$(which em-config)" ]
then
  echo "Error: Cannot find em-config.  This means that either Emscripten is not installed"
  echo "or .../emsdk/upstream/emscriptem has not been added to PATH."
  echo "Exiting. Please remedy and retry."
  exit 10
fi
EM_TOOLSDIR="$(em-config EMSCRIPTEN_ROOT)/tools"

#
#  Find where this script is executing from
#
SCRIPTDIR=$(get_script_dir "$0")

#
#  Create the subdirs (build and tar) where the output of this script are placed
#
mkdir -p "${SCRIPTDIR}"/build
mkdir -p "${SCRIPTDIR}"/tar
#
#  Establish where Medley is
#
cd "${SCRIPTDIR}"
cd ../..
export MEDLEYDIR="$(pwd)"
#
#  Establish where Maiko is
#
cd "${MEDLEYDIR}"
if [ -d "../maiko" ]
then
  cd ../maiko
  MAIKODIR="$(pwd)"
elif [ -d "../../maiko" ]
then
  cd ../../maiko
  MAIKODIR="$(pwd)"
elif [ -d "./maiko" ]
then
  cd ./maiko
  MAIKODIR="$(pwd)"
else
  echo "Error: Cannot find maiko directory"
  echo "Exiting"
  exit 11
fi
if [ ! -d "${MAIKODIR}/emscripten.wasm_nl" ]
then
  echo "Error: empscripten.wasm_nl directory missing from ${MAIKODIR}"
  echo "Exiting"
  exit 12
fi
#
#  Establish where Notecards is.  If can't find, set NOAPPS flag.
#
cd "${MEDLEYDIR}"
if [ -d "../notecards" ]
then
  cd ../notecards
  NCDIR="$(pwd)"
elif [ -d "../../notecards" ]
then
  cd ../../notecards
  NCDIR="$(pwd)"
else
  echo "Notecards directory not found"
  echo "Apps file system will not be created"
  NOAPPS="true"
fi
#
#   Separate the sources, lcoms and tedit files
#
copy_lcoms () {
  mkdir -p $1
  find . -type d -exec mkdir -p $1/{} \;
  find .			\
      \(			\
        -iname '*.lcom' 	\
        -o			\
	-iname '*.dfasl'	\
      \)			\
      -exec cp -p {} $1/{} \;	\
  ;
}

copy_docs () {
  mkdir -p $1
  find . -type d -exec mkdir -p $1/{} \;
  find .			\
      \(			\
        -iname '*.tedit' 	\
        -o			\
	-iname '*.ted'		\
        -o			\
	-iname '*.pdf'		\
        -o			\
	-iname '*.txt'		\
      \)			\
      -exec cp -p {} $1/{} \;	\
  ;
}

copy_sources () {
  mkdir -p $1
  find . -type d -exec mkdir -p $1/{} \;
  find .			\
      ! -iname '*~*~' 		\
      ! -iname '*.lcom'		\
      ! -iname '*.dfasl'	\
      ! -iname '*.tedit'	\
      ! -iname '*.ted'		\
      ! -iname '*.pdf'		\
      ! -iname '*.txt'		\
      ! -type d			\
      -exec cp -p {} $1/{} \;	\
  ;
}

TMP_DIR=/tmp/tmp-$$

#
# for medleyfs
#
MEDLEYFS_LCOMS=${TMP_DIR}/lcoms/medleyfs
MEDLEYFS_SOURCES=${TMP_DIR}/sources/medleyfs
MEDLEYFS_DOCS=${TMP_DIR}/docs/medleyfs
mkdir -p ${MEDLEYFS_LCOMS}
mkdir -p ${MEDLEYFS_SOURCES}
mkdir -p ${MEDLEYFS_DOCS}

MEDLEYFS_DIRS="greetfiles internal sources library lispusers doctools"

for dir in ${MEDLEYFS_DIRS}
do
  cd "${MEDLEYDIR}"/${dir}
  copy_lcoms ${MEDLEYFS_LCOMS}/${dir}
  copy_docs ${MEDLEYFS_DOCS}/${dir}
  copy_sources ${MEDLEYFS_SOURCES}/${dir}
done

cp -rp "${MEDLEYDIR}"/docs ${MEDLEYFS_DOCS}
mkdir -p ${MEDLEYFS_LCOMS}/docs
mv ${MEDLEYFS_DOCS}/docs/dinfo ${MEDLEYFS_LCOMS}/docs

cp -rp "${MEDLEYDIR}"/fonts ${MEDLEYFS_LCOMS}
cp -rp "${MEDLEYDIR}"/unicode ${MEDLEYFS_LCOMS}

mkdir -p ${MEDLEYFS_SOURCES}/loadups
cp -rp "${MEDLEYDIR}"/loadups/whereis.hash ${MEDLEYFS_SOURCES}/loadups/whereis.hash

#
# for apps fs
#
if [ -z "${NOAPPS}" ]
then
    APPSFS_LCOMS=${TMP_DIR}/lcoms/appsfs
    APPSFS_SOURCES=${TMP_DIR}/sources/appsfs
    APPSFS_DOCS=${TMP_DIR}/docs/appsfs
    mkdir -p ${APPSFS_LCOMS}
    mkdir -p ${APPSFS_SOURCES}
    cd "${MEDLEYDIR}"/rooms
    copy_lcoms ${APPSFS_LCOMS}/rooms
    copy_docs ${APPSFS_DOCS}/rooms
    copy_sources ${APPSFS_SOURCES}/rooms
    cd ${NCDIR}
    copy_lcoms ${APPSFS_LCOMS}/notecards
    copy_docs ${APPSFS_DOCS}/notecards
    copy_sources ${APPSFS_SOURCES}/notecards
    mv ${APPSFS_SOURCES}/notecards/notefiles ${APPSFS_LCOMS}/notecards
fi
#
#  Package the files
#
cd "${SCRIPTDIR}"
${EM_TOOLSDIR}/file_packager							\
    build/medleyfs_lcoms.data 							\
    --js-output=build/medleyfs_lcoms.js 					\
    --preload 									\
	"${MEDLEYFS_LCOMS}"@medley						\
    --no-node									\
    --no-force 									\
    --lz4 									\
    --use-preload-cache 							\
    --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
    2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

${EM_TOOLSDIR}/file_packager							\
    build/medleyfs_sources.data 						\
    --js-output=build/medleyfs_sources.js 					\
    --preload 									\
	"${MEDLEYFS_SOURCES}"@medley						\
    --no-node									\
    --no-force 									\
    --lz4 									\
    --use-preload-cache 							\
    --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
    2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

${EM_TOOLSDIR}/file_packager							\
    build/medleyfs_docs.data 						\
    --js-output=build/medleyfs_docs.js 					\
    --preload 									\
	"${MEDLEYFS_DOCS}"@medley						\
    --no-node									\
    --no-force 									\
    --lz4 									\
    --use-preload-cache 							\
    --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
    2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

${EM_TOOLSDIR}/file_packager							\
    build/lisp_sysout.data 							\
    --js-output=build/lisp_sysout.js 						\
    --preload 									\
        "${MEDLEYDIR}"/loadups/lisp.sysout@medley/loadups/lisp.sysout 		\
	"${MEDLEYDIR}"/greetfiles/MEDLEYDIR-INIT.LCOM@usr/local/lde/site-init.lisp\
    --no-node									\
    --no-force 									\
    --lz4 									\
    --use-preload-cache 							\
    --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
    2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

${EM_TOOLSDIR}/file_packager							\
    build/full_sysout.data 							\
    --js-output=build/full_sysout.js 						\
    --preload 									\
        "${MEDLEYDIR}"/loadups/full.sysout@medley/loadups/full.sysout 		\
	"${MEDLEYDIR}"/greetfiles/MEDLEYDIR-INIT.LCOM@usr/local/lde/site-init.lisp\
    --no-node									\
    --no-force 									\
    --lz4 									\
    --use-preload-cache 							\
    --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
    2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

if [ -z "${NOAPPS}" ]
then
  ${EM_TOOLSDIR}/file_packager							\
      build/apps_sysout.data 							\
      --js-output=build/apps_sysout.js 						\
      --preload 								\
          "${MEDLEYDIR}"/loadups/apps.sysout@medley/loadups/apps.sysout 	\
	  "${MEDLEYDIR}"/greetfiles/APPS-INIT.LCOM@usr/local/lde/site-init.lisp	\
          "${MEDLEYDIR}"/greetfiles/MEDLEYDIR-INIT.LCOM@usr/local/lde/MEDLEYDIR-INIT.LCOM\
      --no-node									\
      --no-force								\
      --lz4 									\
      --use-preload-cache 							\
      --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
      2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

  ${EM_TOOLSDIR}/file_packager							\
      build/appsfs_lcoms.data 							\
      --js-output=build/appsfs_lcoms.js						\
      --preload 								\
          "${APPSFS_LCOMS}"/rooms@medley/rooms			 		\
          "${APPSFS_LCOMS}"/notecards@notecards					\
      --no-node									\
      --no-force								\
      --lz4 									\
      --use-preload-cache 							\
      --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
      2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

  ${EM_TOOLSDIR}/file_packager							\
      build/appsfs_sources.data							\
      --js-output=build/appsfs_sources.js					\
      --preload 								\
          "${APPSFS_SOURCES}"/rooms@medley/rooms		 		\
          "${APPSFS_SOURCES}"/notecards@notecards				\
      --no-node									\
      --no-force								\
      --lz4 									\
      --use-preload-cache 							\
      --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
      2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

  ${EM_TOOLSDIR}/file_packager							\
      build/appsfs_docs.data							\
      --js-output=build/appsfs_docs.js					\
      --preload 								\
          "${APPSFS_DOCS}"/rooms@medley/rooms		 		\
          "${APPSFS_DOCS}"/notecards@notecards				\
      --no-node									\
      --no-force								\
      --lz4 									\
      --use-preload-cache 							\
      --indexedDB-name=MEDLEY_PRELOAD_CACHE					\
      2>&1 | grep -v FORCE_FILESYSTEM | grep -v compress

fi
#
#  Add Maiko to the build subdirs
#
cd "${SCRIPTDIR}"
cp -p "${MAIKODIR}"/emscripten.wasm_nl/* build
#
#  Gzip all of the file so far
#
cd "${SCRIPTDIR}"/build
for file in *
do
   gzip --best -c "${file}" >"${file}.gz"
done
#
#   Add medley.html to the build subdirs
#
cd "${SCRIPTDIR}"
cp -p medley.html build
if [ -n "${NOAPPS}" ]
then
  sed -i -e 's/params.has("apps")/false/' build/medley.html
fi
#
#  Create a tar of the build directory's contents
#
cd "${SCRIPTDIR}"/build
tar -c -z -f "${SCRIPTDIR}"/tar/medley-full-emscripten.tgz *
#
#  Done
#
rm -rf "${TMP_DIR}"
echo "Done with Medley emscripten build"
exit 0
