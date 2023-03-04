#!/bin/bash
###############################################################################
#
#    build_artifacts.sh: build the artifacts for installing Medley Interlisp on
#                  MacOS.  Basically just calls build_app.sh and build_dmg.sh.
#                  based on Medley.app built by build_app.sh
#
#    2023-03-03 Frank Halasz
#
#    Copyright 2023 by Interlisp.org
#
###############################################################################

#
# Figure out what directory this script is being executed from
#
get_abs_filename() {
  # $1 : relative filename
  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
}

get_script_dir() {

    # call this with ${BASH_SOURCE[0]:-$0} as its (only) parameter

    # set -x

    local SCRIPT_PATH="$( get_abs_filename "$1" )";

    pushd . > '/dev/null';

    while [ -h "$SCRIPT_PATH" ];
    do
        cd "$( dirname -- "$SCRIPT_PATH"; )";
        SCRIPT_PATH="$( readlink -f -- "$SCRIPT_PATH"; )";
    done

    cd "$( dirname -- "$SCRIPT_PATH"; )" > '/dev/null';
    SCRIPT_PATH="$( pwd; )";

    popd  > '/dev/null';

    # set +x

    echo "${SCRIPT_PATH}"
}

SCRIPTDIR=$(get_script_dir "${BASH_SOURCE[0]:-$0}")

#
#  cd to the dir we are executing from and call
#    build_app.sh and the build_dmg.sh
#
cd ${SCRIPTDIR}
t=""
c=""
if [[ "$1" = "-t" || "$2" = "-t" ]]; then t="-t"; fi
if [[ "$1" = "-c" || "$2" = "-c" ]]; then c="-c"; fi
./build_app.sh "${t}"
./build_dmg.sh "${c}" 2>&1 | tee /tmp/output$$
tail -q -n 1 /tmp/output$$


###############################################################################
