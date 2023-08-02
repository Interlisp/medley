#!/bin/sh

export MEDLEYDIR=`pwd`
if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

if [ -z "$1" ] ; then
    tag=medley-$(date +%y%m%d)-$(date +%s)
else
    tag="$1"
fi
short_tag="${tag#medley-}"

scripts/release-make-tars.sh "${tag}"

echo making release
sed s/'$tag'/$tag/g < release-notes.md > releases/${short_tag}/release-notes.md
gh release create $tag -F releases/${short_tag}/release-notes.md -p -t $tag

echo uploading
gh release upload $tag releases/${short_tag}/$tag-loadups.tgz releases/${short_tag}/$tag-runtime.tgz --clobber

echo done

