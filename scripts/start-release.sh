#!/bin/sh
export MEDLEYDIR=`pwd`
if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

tag=$1

cd ..

echo making medley zip 

tar cfz medley/tmp/medley-$tag.tgz                        \
    --exclude-backups --exclude="*.PDF"                   \
    medley/docs/dinfo                                     \
    medley/greetfiles/SIMPLE-INIT                         \
    medley/run-medley                                     \
    medley/scripts                                        \
    medley/loadups                                        \
    medley/fonts/displayfonts  medley/fonts/altofonts     \
    medley/fonts/postscriptfonts medley/fonts/ipfonts     \
    medley/library/                                       \
    medley/internal/library                               \
    medley/lispusers/                                     \
    medley/sources/

cd medley

echo making release
sed s/'$tag'/$tag/g < release-notes.md > tmp/release-notes.md
gh release create $tag -F tmp/release-notes.md -p -t $tag

echo uploaded tmp/medley-$tag.tgz

gh release upload $tag tmp/medley-$tag.tgz --clobber

./scripts/release-one.sh $tag
