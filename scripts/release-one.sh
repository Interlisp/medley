#!/bin/sh
export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo "run from MEDLEYDIR (with MAIKODIR ../maiko)"
    exit 1
fi

tag=$1

cd ../maiko/bin
export PATH=.:"$PATH"
osarch=`osversion`.`machinetype`

cd ../..

tar cfz medley/tmp/maiko-$tag-$osarch.tgz   \
    --exclude "make*" --exclude legacy      \
    maiko/bin                               \
    maiko/$osarch/lde*

cd medley

gh release upload --clobber $tag tmp/maiko-$tag-$osarch.tgz
