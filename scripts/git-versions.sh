#!/bin/sh

#missing features:
#  should take a directory and work for all of the files
#  should check to see if there are already ~nn~ files in the directory
#   maybe if they are checked in, then start at nn+1?
#   else fail
#  should check to see if file hasn't been committed
#    stash it first, check out previous versions, pop the stash
#  should never make hardlink if there is only 1
#  Maybe only do this for Lisp sources (and LCOMs? TEdit files? Not sysouts?)
#  should coordinate with fix-links


file="$1"

if [ -d "$file" ]; then
    echo cannot do directories "$file"
    exit 1
fi

if [ ! -f "$file" ]; then
    echo no such file "$file"
    exit 1
fi

if [ ! -z "$file.~"*"~" ]; then
    echo file already has versions "$file.~"*"~"
    exit 1
fi

n=1
 
for commit in `git log --since=2020-11-16 --remove-empty --reverse --format="%h" "$file"`
do git checkout $commit "$file" && ln "$file" "$file.~"$n"~" && n=`expr $n + 1`
done

if [ $n -eq 2 ]; then
    rm "$file".~1~
fi
