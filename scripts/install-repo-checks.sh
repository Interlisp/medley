#!/bin/sh

# install checks for repository, meant to run post-checkout

# For now, this just checks for orphaned versions.


rm -f .git/hooks/post-checkout
cp scripts/post-checkout .git/hooks/post-checkout &&
    chmod -x .git/hooks/post-checkout &&
    echo copy made: &&
    ls -l .git/hooks/post-checkout &&
    exit 0

exit 1
