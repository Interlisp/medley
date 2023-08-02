#!/bin/sh

export MEDLEYDIR=`pwd`
if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

if [ -z "$(which gh)" ]; then
    echo "Error: this script requires gh (github cli) to be installed. Exiting."
    exit 1
fi

gh auth status 2>&1 | grep -i -q "Logged in to github.com"
if [ $? -ne 0 ]; then
    echo 'Error: this script requires you to be logged into github.  Use "gh auth login" to do so. Exiting.'
    exit 1
fi

if [ "$1" = "-d" ]; then
    draft="-d"
    shift
else
    draft=""
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
gh release create $tag -F releases/${short_tag}/release-notes.md -p -t $tag ${draft}

echo uploading
gh release upload $tag releases/${short_tag}/$tag-loadups.tgz releases/${short_tag}/$tag-runtime.tgz --clobber

echo "Done with release ${tag}"

