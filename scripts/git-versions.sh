#!/bin/sh

#missing features:
# [ ] should take a directory and work for all of the files
# [*] deletes any existing versions Is that OK???
#       then checks out any file.~nn~ files
# [ ] should check to see if file hasn't been committed
#     if so, it should stash it first, check out previous versions, pop the stash
#  should coordinate with medley-fix-links and trimming repo size

# only ASCII
export LC_ALL=C 

file="$1"

if [ -d "$file" ]; then
    for dir in "$file/"*
    do echo expanding "$dir"
	find "$dir" -type f -iname "*[a-z0-9]" -exec $0 {} \;
    exit 0
fi

if [ ! -f "$file" ]; then
    echo no such file "$file"
    exit 1
fi

base=`basename "$file" .LCOM`
base=`basename "$base" .DFASL`

rm -f "$file".~[1-9]*~

n=1

# first find commits with explicit versions
for commit in `git log --remove-empty --reverse --format="%h" -- "$file.~[1-9]*~"` 
do git checkout -q $commit "$file.~[1-9]*~" 2>/dev/null
done
# should only be one commit but just in case

for version in "$file".~[1-9]*~
do  vn=`echo $version | grep --only-matching '\.~[1-9][0-9]*~' | grep --only-matching '[1-9][0-9]*'`
    vn=`expr $vn + 1`  
    if [ $n -lt $vn ]; then
	n=$vn
    fi
done

for commit in `git log --remove-empty --reverse --format="%h" "$file"`
do git checkout -q $commit "$file"
   fcv=`tr '\r' '\n' <"$file" | tr -d '\001-\006' | head -n 2 | grep -a --only-matching '{DSK}.*'"$base"'\.\?;[1-9][0-9]*'  | grep --only-matching ';[1-9][0-9]*'`
   fcv=`echo $fcv | grep --only-matching '[1-9][0-9]*'`
   if [ ! -z $fcv ]; then
       if [ $fcv -gt $n ]; then
	   n=$fcv
       fi
   fi
   ln "$file" "$file.~"$n"~" && n=`expr $n + 1`
done


if [ $n -eq 2 ]; then
    rm -f "$file".~1~
fi

git restore --staged "$file.~[1-9]*~" 2>/dev/null    




