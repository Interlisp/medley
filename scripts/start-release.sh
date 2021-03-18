#!/bin/sh
export MEDLEYDIR=`pwd`
if [ ! -x run-medley ] ; then
    echo run from MEDLEYDIR
    exit 1
fi

tag=$1
cd ..

tar cfz medley/tmp/medley-$tag.tar.gz \
    medley/docs/dinfo \
    medley/greetfiles/SIMPLE-INI*[TM] \
    medley/run-medley \
    medley/loadups/lisp.sysout medley/loadups/full.sysout \
    medley/fonts/displayfonts \
    medley/loadups/whereis.hash \
    medley/library/*[A-Za-z] \
    medley/internal/library/*[A-Za-z]  \
    medley/lispusers/*[A-Za-z] \
    medley/sources/*[A-Z]

cd medley

gh release create $tag -F release-notes.md -p -t $tag
gh release upload $tag tmp/medley-$tag.tar.gz --clobber

./scripts/release-one.sh $tag
