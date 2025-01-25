#/bin/sh
# $1 is a versioned file name

ver="$1"
base="${ver%%.~[1-9]*~}"
if [ ! -f "$base" ]; then 
    echo "Orphaned version: $ver but no $base"
fi

