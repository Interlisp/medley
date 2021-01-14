#!/bin/bash

## This script installs the `eolconv` git diff filter in order to render diffs
## of files with CR line terminators correctly. The filter is installed locally
## and only affects the medley repository.

SCRIPT_DIR="`dirname "$0"`"
EOLCONV="$SCRIPT_DIR/eolconv.sh"
GITATTRIBUTES="$SCRIPT_DIR/../.gitattributes"

chmod +x "$EOLCONV"
git config --local --add diff.creol.textconv "$EOLCONV"
echo "[A-Z]* diff=creol" >> "$GITATTRIBUTES"
