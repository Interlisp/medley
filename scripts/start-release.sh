#!/bin/sh
export MEDLEYDIR=`pwd`
if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

tag=$1

cd ..

tar cfz medley/tmp/medley-$tag.tgz                        \
    --exclude-backups --exclude="*.PDF"                   \
    medley/docs/dinfo                                     \
    medley/greetfiles/SIMPLE-INIT                         \
    medley/run-medley                                     \
    medley/loadups                                        \
    medley/fonts/displayfonts  medley/fonts/altofonts     \
    medley/library/                                       \
    medley/internal/library                               \
    medley/lispusers/                                     \
    medley/sources/

cd medley
gh release create $tag -F release-notes.md -p -t $tag
gh release upload $tag tmp/medley-$tag.tgz --clobber

./scripts/release-one.sh $tag
