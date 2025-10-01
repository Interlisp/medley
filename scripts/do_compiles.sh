#!/bin/sh
#
#  do_compiles.sh
#
#  Script to compile all files in MEDLEYDIR sources, one at a time each time in a fresh MEDLEY
#
#  FGH 2025-09-30
#
#  Copyright 2025 Interlisp.org
#

main() {
        MEDLEYDIR=$(cd "${SCRIPTDIR}/.." && pwd)
        export MEDLEYDIR
        SOURCESDIR="${MEDLEYDIR}/sources"
        logindir=/tmp/compiles
        mkdir -p "${logindir}"
        cmfile=${logindir}/compile.cm

        nextDribble

        for f in "${SOURCESDIR}"/*.LCOM "${SOURCESDIR}"/*.lcom
        do
          if [ "$f" = "${SOURCESDIR}/*.LCOM" ] || [ "$f" = "${SOURCESDIR}/*.lcom" ]
          then
            continue
          fi
          ff="$(basename "$f" | sed -e s-.lcom\$-- -e s-.LCOM\$--)"
          if grep "COMPILED-FILEd" "$f" 2> /dev/null
          then
            doCompile "$ff"  "IL:FAKE-COMPILE-FILE" "$f"
          else
            doCompile "$ff" "IL:TCOMPL" "$f"
          fi
        done

        #
        for f in ${SOURCESDIR}/*.DFASL ${SOURCESDIR}/*.dfasl
        do
          if [ "$f" = "${SOURCESDIR}/*.DFASL" ] || [ "$f" = "${SOURCESDIR}/*.dfasl" ]
          then
            continue
          fi
          ff="$(basename "$f" | sed -e s-\.dfasl\$-- -e s-\.DFASL\$--)"
          doCompile "$ff" "CL:COMPILE-FILE" "$f"
        done
}



doCompile() {


        findMaxVersion "$3"
        oldver=$?

	cat >"${cmfile}" <<-EOF
	"

	(PROGN
          (IL:MEDLEY-INIT-VARS 'IL:GREET)
          (IL:FILESLOAD ${MEDLEYDIR}/loadups/exports.all)
          (IL:ADVISE 'IL:ASKUSER :BEFORE '(RETURN (IL:QUOTE IL:F)))
          (IL:DRIBBLE '${DRIBBLE} T)
          (PRINT '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>)
          (PRINT '$1)
          (PRINT '$2)
          (IL:CNDIR '${MEDLEYDIR}/sources)
          ($2 '$1)
          (PRINT '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<)
          (IL:DRIBBLE)
          (IL:LOGOUT T)
	)

	"
	EOF

        /bin/sh "${MEDLEYDIR}/scripts/medley/medley.command"     \
             --config -                                          \
             --id $1                                             \
             --geometry 1024x768                                 \
             --noscroll                                          \
             --logindir "${logindir}"                            \
             --greet -                                           \
             --rem.cm "${cmfile}"                                \
             --full

        findMaxVersion "$3"
        newver=$?

        if [ $newver -eq $oldver ]
        then
          echo " " >> "${DRIBBLE}"
          echo !!!!!!!!!!!!!!!!!!!! FAIL "$3"  >> "${DRIBBLE}"
          echo !!!!!!!!!!!!!!!!!!!! FAIL "$3"
        fi

}


nextDribble() {

        export DRIBBLE="${MEDLEYDIR}/loadups/compiles.dribble"
        dest="${DRIBBLE}"
        if [ ! -e "$dest" ]
        then
          touch $dest
        fi

        findMaxVersion $dest

	if [ $max -eq 0 ]; then		# no current versions
	    mv $dest $dest.~1~		# change version to version 1
	    new=2
	else
	    if cmp -q $dest $dest.~$max~ >/dev/null 2>&1
	    then			# they're different
		max=`expr $max + 1`	# make newer version
		mv $dest $dest.~$max~
		new=`expr $max + 1`
	    else			# dest and dest.~nn~ are equal so
		rm $dest		# delete dest leave old version behind
		new=`expr $max + 1`
	    fi
	fi
        DRIBBLE="$dest.~$new~"

}


findMaxVersion() {
        dest="$1"
   	# find maximum version of dest
	max=0
	for vf in "$dest".~[1-9]*~
	do vn=`echo $vf | sed -e 's/^.*\.~\([1-9][0-9]*\)~$/\1/'`
	   if [ -f $dest.~$vn~ ]; then
	       if [ $max -lt $vn ]; then
		   max=$vn
	       fi
	   fi
	done
        if [ $max -eq 0 ]; then
           ln $dest $dest.~1~
           max=1
        fi
        return $max
}

# shellcheck disable=SC2164,SC2034
if [ -z "${SCRIPTDIR}" ]
then
	#
	#
	# Some functions to determine what directory this script is being executed from
	#
	#
	get_abs_filename() {
	  # $1 : relative filename
	  echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
	}

	# This function taken from
	# https://stackoverflow.com/questions/29832037/how-to-get-script-directory-in-posix-sh
	rreadlink() (

	  # Execute this function in a *subshell* to localize variables and the effect of `cd`.

	  target=$1
	  fname=
	  targetDir=
	  CDPATH=

	  # Try to make the execution environment as predictable as possible:
	  # All commands below are invoked via `command`, so we must make sure that `command`
	  # itself is not redefined as an alias or shell function.
	  # (Note that command is too inconsistent across shells, so we don't use it.)
	  # `command` is a *builtin* in bash, dash, ksh, zsh, and some platforms do not even have
	  # an external utility version of it (e.g, Ubuntu).
	  # `command` bypasses aliases and shell functions and also finds builtins 
	  # in bash, dash, and ksh. In zsh, option POSIX_BUILTINS must be turned on for that
	  # to happen.
	  { \unalias command; \unset -f command; } >/dev/null 2>&1
	  [ -n "$ZSH_VERSION" ] && options[POSIX_BUILTINS]=on # make zsh find *builtins* with `command` too.

	  while :; do # Resolve potential symlinks until the ultimate target is found.
	      [ -L "$target" ] || [ -e "$target" ] || { command printf '%s\n' "ERROR: '$target' does not exist." >&2; return 1; }
	      command cd "$(command dirname -- "$target")" # Change to target dir; necessary for correct resolution of target path.
	      fname=$(command basename -- "$target") # Extract filename.
	      [ "$fname" = '/' ] && fname='' # !! curiously, `basename /` returns '/'
	      if [ -L "$fname" ]; then
	        # Extract [next] target path, which may be defined
	        # *relative* to the symlink's own directory.
	        # Note: We parse `ls -l` output to find the symlink target
	        #       which is the only POSIX-compliant, albeit somewhat fragile, way.
	        target=$(command ls -l "$fname")
	        target=${target#* -> }
	        continue # Resolve [next] symlink target.
	      fi
	      break # Ultimate target reached.
	  done
	  targetDir=$(command pwd -P) # Get canonical dir. path
	  # Output the ultimate target's canonical path.
	  # Note that we manually resolve paths ending in /. and /.. to make sure we have a normalized path.
	  if [ "$fname" = '.' ]; then
	    command printf '%s\n' "${targetDir%/}"
	  elif  [ "$fname" = '..' ]; then
	    # Caveat: something like /var/.. will resolve to /private (assuming /var@ -> /private/var), i.e. the '..' is applied
	    # AFTER canonicalization.
	    command printf '%s\n' "$(command dirname -- "${targetDir}")"
	  else
	    command printf '%s\n' "${targetDir%/}/$fname"
	  fi
	)

	get_script_dir() {

	    # call this with $0 (from main script) as its (only) parameter
	    # if you need to preserve cwd, run this is a subshell since
	    # it can change cwd

	    # set -x

	    local_SCRIPT_PATH="$( get_abs_filename "$1" )";

	    while [ -h "$local_SCRIPT_PATH" ];
	    do
	        cd "$( dirname -- "$local_SCRIPT_PATH"; )";
	        local_SCRIPT_PATH="$( rreadlink "$local_SCRIPT_PATH" )";
	    done

	    cd "$( dirname -- "$local_SCRIPT_PATH"; )" > '/dev/null';
	    local_SCRIPT_PATH="$( pwd; )";

	    # set +x

	    echo "${local_SCRIPT_PATH}"
	}

	# end of script directory functions
	###############################################################################

        # figure out the script dir
        SCRIPTDIR="$(get_script_dir "$0")"
	export SCRIPTDIR

fi

main "$@"
