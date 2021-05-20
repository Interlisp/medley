#!/bin/sh -vx

#missing features:
#  should take a directory and work for all of the files
#  deletes any existing versions !!!
#   then checks out any file.~nn~ files
#   maybe if they are checked in, then start at nn+1 
#  should check to see if file hasn't been committed
#    stash it first, check out previous versions, pop the stash
#  should never make hardlink if there is only 1
#  Maybe only do this for Lisp sources (and LCOMs? TEdit files? Not sysouts?)
#  should coordinate with fix-links and trimming repo size

file="$1"

if [ -d "$file" ]; then
    echo cannot do directories "$file"
    exit 1
fi

if [ ! -f "$file" ]; then
    echo no such file "$file"
    exit 1
fi

rm -f "$file".~[1-9]*~

n=1

for commit in `git log --remove-empty --reverse --format="%h" --  "$file.~[1-9]*~"` 
do git checkout $commit "$file.~[1-9]*~"
   for version in "$file".~[1-9]*~
   do
       vn=`echo $version | grep --only-matching '\\.~[1-9][0-9]*~' | grep --only-matching '[1-9][0-9]*'`
       if [ $vn -ge $n ]; then
	   n=`expr $vn + 1`
       fi
   done
done
   
for commit in `git log --remove-empty --reverse --format="%h" "$file"`
do git checkout $commit "$file" && ln "$file" "$file.~"$n"~" && n=`expr $n + 1`
done

if [ $n -eq 2 ]; then
   rm -f "$file".~1~
fi
