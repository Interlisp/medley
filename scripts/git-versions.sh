#!/bin/sh

#missing features:
# [ ] should take a directory and work for all of the files
# [*] deletes any existing versions !!!
#       then checks out any file.~nn~ files
# [ ] should check to see if file hasn't been committed
#     stash it first, check out previous versions, pop the stash
# [ ] should never make hardlink if there is only 1
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

# first find commits with explicit veeersions
for commit in `git log --remove-empty --reverse --format="%h" -- "$file.~[1-9]*~"` 
do git checkout $commit "$file.~[1-9]*~"
   for version in "$file".~[1-9]*~
   do
       vn=`echo $version | grep --only-matching '\\.~[1-9][0-9]*~' | grep --only-matching '[1-9][0-9]*'`
       if [ $vn -ge $n ]; then
	   # update $n to version $vn
	   n=`expr $vn + 1`
       fi
   done
done

for commit in `git log --remove-empty --reverse --format="%h" "$file"`
do git checkout $commit "$file"
   fcv=`tr '\r' '\n' <$file | tr -d '\001-\006' | head -n 2 | grep --only-matching '\\.;[1-9][0-9]* ' | grep --only-matching '[1=9][0-9]*'`
   if [ ! -z $fcv ]; then
       if [ $fcv -gt $n ]; then
	   echo update $n to $fcv version
	   n=`expr $fcv`
       else
	   # $n not updated to $fcv file version
       fi
       # no version found in $file $n
   fi
   ln "$file" "$file.~"$n"~" && n=`expr $n + 1`
done

if [ $n -eq 2 ]; then
   rm -f "$file".~1~
fi
