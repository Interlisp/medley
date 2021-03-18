#!/bin/sh
export MEDLEYDIR=`pwd`

if [ ! -x run-medley ] ; then
    echo "run from MEDLEYDIR (with MAIKODIR ../maiko)"
    exit 1
fi

tag=$1
# add one os/arch
cd ../maiko/bin
export PATH=.:"$PATH"
osarch=`osversion`.`machinetype`
cd ../..
tar cfz medley/tmp/maiko-$osarch.tar.gz maiko/$osarch/lde*
cd medley
gh release upload $tag tmp/maiko-$osarch.tar.gz
