#!/bin/sh
export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo "run from MEDLEYDIR (with MAIKODIR ../maiko)"
    exit 1
fi

tag=$1
if [ -z "$tag" ] ; then
    tag=nitely-`date +%y%m%d`
fi

cd ../maiko/bin
export PATH=.:"$PATH"
osarch=`osversion`.`machinetype`

cd ../..

echo making maiko-$tag-$osarch.tgz

tar cfz medley/tmp/maiko-$tag-$osarch.tgz   \
    --exclude "make*" --exclude legacy      \
    maiko/bin                               \
    maiko/$osarch/lde*

cd medley

echo uploading

gh release upload --clobber $tag tmp/maiko-$tag-$osarch.tgz
