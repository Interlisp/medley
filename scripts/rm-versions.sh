#!/bin/sh

file="$1"

# if given a directory, clean up all sub directories
# script is tuned for not descending into top level .git hidden
# subfiles/directories.

# This can be done more simply by
#    find . -name "*~" -exec rm {} \;
# but this script will work for a single named file
# and leave other files alone
if [ -d "$file" ]; then
    for dir in "$file/"*[a-zA-Z0-9]
    do echo removing versions from "$dir" && \
	    find "$dir" -type f -iname "*[a-z0-9]" -exec "$0" {} \;
    done
    exit 0
fi

if [ ! -f "$file" ]; then
    echo no such file "$file"
    exit 1
fi

# remove old versions
rm -f "$file".~[1-9]*~
