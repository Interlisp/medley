#!/bin/sh

# restore old versions from git repo
# For use after a rm-versions or in a newly cloned repo
# not guaranteed to return the SAME version as before
# but it tries when it can.
# version numbers follow git history


# LC_ALL is needed for tr
export LC_ALL=C 

file="$1"

# If given a directory, restore all versions from that directory
# There's a suble difference, bcause glob expansion won't try
# to reversion .git .github at top level.

if [ -d "$file" ]; then
    for dir in "$file/"*[a-zA-Z0-9]
    do echo restoring versions "$dir" && \
	    find "$dir" -type f -iname "*[a-z0-9]" -exec "$0" {} \;
    done
    exit 0
fi


if [ ! -f "$file" ]; then
    echo no such file "$file"
    exit 1
fi

# file already has versions?
# if you want to delete and restore instead
# rm -f "$file".~[1-9]*~

for vfn in "$file".~[1-9]*~
do if [ -f "$vfn" ]; then
       echo "Already has versions: " $vfn && \
	   exit 1
   fi
done

#stash file and remember status
# if file has no changes, this does nothing

stash=`git stash push -- $file 2>&1`

# n is the next version available
n=1

# find commits with explicit old versions
# In most cases there will be only one commit
# these versions are restored, and n is set to 1+max of them
# this is specific to our situation where we checked in some
# ~nn~ versions and then .gitignore *~ was set 

for commit in `git log --remove-empty --reverse --format="%h" -- "$file.~[1-9]*~"` 
do git checkout -q $commit "$file.~[1-9]*~" 2>/dev/null && \
   for version in "$file".~[1-9]*~
   do  vn=`echo $version | sed 's/^.*\.~\([1-9][0-9]*\)~$/\1/'`
       if [ ! -z $vn ]; then
	   vn=`expr $vn + 1`  
	   if [ $n -lt $vn ]; then
	       n=$vn
	   fi
       fi
   done
done

# save for later
base=`basename "$file" .LCOM`
base=`basename "$base" .DFASL`


# Now restore versions from git history. This process just starts with
# the n from the previous calculation and would go up by 1, but it
# also prefers to restore files to their FILECREATED version
# number. It does this by looking for {DSK}...root.~nn~ and using nn
# as the version number if it isn't too small It then makes a hard
# link (each time for each commit)

for commit in `git log --remove-empty --reverse --format="%h" "$file"`
do git checkout -q $commit "$file"
   fcv=`tr '\r' '\n' <"$file" | head -n 6 | grep -ai --max-count=1 --only-matching '{DSK}.*'"$base"'\.\?;[1-9][0-9]*'`
   fcv=`echo $fcv | sed 's/^.*;\([1-9][0-9]*\)$/\1/'`
   if [ ! -z $fcv ]; then
       if [ $fcv -gt $n ]; then
	   n=$fcv
       fi
   fi
   ln "$file" "$file.~"$n"~" && n=`expr $n + 1`
done

# if the 'stash' at the beginning did something, restore the stashed file

case $stash in
    "error*" | "No local changes*") 
	;;
    "*")
	git stash pop -- "$file" && \
	ln $file "$file.~"$n"~" && n=`expr $n + 1`
    ;;
esac

# if the result is only one version ;1 remove it
# Otherwise, make sure no versions are staged
if [ $n -eq 2 ]; then
    rm -f "$file".~1~
else
    git restore --staged "$file.~[1-9]*~" 2>/dev/null        
fi
	
