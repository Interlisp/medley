#!/bin/sh

######### Functions ########
check_exists () {
  f="$1"
  if [ -e "${f}" ]
  then
    echo "${f}"
  else
    echo "Warning: $f does not exist. $(basename ${f}) will not be included in release tars" 1>&2
    echo " "
  fi
}
######## End Functions #######


if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi
export MEDLEYDIR=`pwd`

if [ -z "$1" ] ; then
    tag=medley-$(date +%y%m%d)-$(date +%s)
else
    tag="$1"
fi
short_tag="${tag#medley-}"

dirname=$(basename "${MEDLEYDIR}")
if [ "${dirname}" = "medley" ]
then
  name_xform=" "
else
  uname | grep -q -i Linux
  if [ $? -eq 0 ]
  then
    name_xform="--xform s/^${dirname}/medley/"
  else
    name_xform="-s /^${dirname}/medley/"
  fi
fi

cd ..
release_dir="${dirname}"/releases/"${short_tag}"
mkdir -p "${release_dir}"

echo making releases/${short_tag}/$tag-loadups.tgz


tar -c -z -f "${release_dir}"/$tag-loadups.tgz                  \
    ${name_xform}                                               \
    "${dirname}"/loadups/lisp.sysout                            \
    "${dirname}"/loadups/full.sysout                            \
    $(check_exists "${dirname}/loadups/apps.sysout")            \
    "${dirname}"/loadups/*.dribble                              \
    "${dirname}"/loadups/whereis.hash                           \
    "${dirname}"/loadups/exports.all                            \
    $(check_exists "${dirname}/loadups/fuller.database")        ;

echo making releases/${short_tag}/$tag-runtime.tgz

tar -c -z -f "${release_dir}"/$tag-runtime.tgz                  \
    --exclude "*~"                                              \
    --exclude "*#*"                                             \
    --exclude exports.all                                       \
    --exclude "venuesysouts"                                   \
    ${name_xform}                                               \
    "${dirname}"/clos                                           \
    "${dirname}"/docs/dinfo                                     \
    "${dirname}"/docs/man-page/medley.1.gz                      \
    "${dirname}"/doctools                                       \
    "${dirname}"/greetfiles                                     \
    "${dirname}"/rooms                                          \
    "${dirname}"/medley                                         \
    "${dirname}"/run-medley                                     \
    "${dirname}"/scripts                                        \
    "${dirname}"/fonts/displayfonts                             \
    "${dirname}"/fonts/altofonts                                \
    "${dirname}"/fonts/adobe                                    \
    "${dirname}"/fonts/postscriptfonts                          \
    "${dirname}"/fonts/ipfonts                                  \
    "${dirname}"/library                                        \
    "${dirname}"/lispusers                                      \
    "${dirname}"/sources                                        \
    "${dirname}"/internal                                       \
    "${dirname}"/unicode                                        ;


echo "Done with release tars"
