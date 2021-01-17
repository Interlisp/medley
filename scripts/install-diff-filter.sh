#!/bin/sh

## This script installs the `eolconv` git diff filter in order to render diffs
## of files with CR line terminators correctly. The filter is installed locally
## and only affects the medley repository.

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
EOLCONV="$SCRIPTPATH/eolconv.sh"
GITATTRIBUTES="$SCRIPTPATH/../.gitattributes"

chmod +x "$EOLCONV"
git config --local --add diff.creol.textconv "$EOLCONV"
echo "* diff=creol" >> "$GITATTRIBUTES"

## for good measure  
git config --local --add core.autocrlf false
