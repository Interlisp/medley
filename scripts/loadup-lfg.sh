#!/bin/sh

main() {

        export APP_DIR="${LFG_DIR}"
        export APP_LOADUPSDIR="${LFG_LOADUPSDIR}"
        export APP_WORKDIR="${LFG_WORKDIR}"

        get_medleydir "$@"

        loadup_start

	cat >"${cmfile}" <<-"EOF"
	"

	(PROGN
	   (IL:MEDLEY-INIT-VARS 'IL:GREET)
	   (IL:DRIBBLE (IL:PACKFILENAME 'HOST '{DSK} 'DIRECTORY (IL:UNIX-GETENV 'APP_WORKDIR) 'NAME 'lfg.dribble))
	   (IL:DOFILESLOAD
               '((SYSLOAD)
                 (FROM VALUEOF (IL:PACKFILENAME 'HOST '{DSK} 'DIRECTORY (IL:UNIX-GETENV 'APP_DIR)))
                 LFG-LOADUP
                )
           )
           (IL:LOADUP-LFG)
           (IL:PUTASSOC 'IL:LFG
                        (LIST (IL:UNIX-GETENV 'MEDLEY_COMMIT_ID))
                        (CADR (ASSOC 'IL:MEDLEY IL:SYSOUTCOMMITS)))
           (IL:PUTASSOC 'IL:LFG (LIST (IL:UNIX-GETENV 'APP_COMMIT_ID)) IL:SYSOUTCOMMITS)
	   (IL:ENDLOADUP)
	   (IL:DRIBBLE)
	   (IL:MAKESYS
	       (IL:PACKFILENAME 'HOST '{DSK} 'DIRECTORY (IL:UNIX-GETENV 'APP_WORKDIR) 'NAME 'lfg.sysout)
	       :LFG
           )
	)
	(IL:LOGOUT T)

	"
	EOF

	run_medley "${full_sysout}"

        loadup_finish "lfg.sysout" "lfg.dribble"

}

get_medleydir() {

	while [ $# -gt 0 ]
        do
          case "$1" in
            -m | -medley | --medley)
              export MEDLEYDIR="$2"
              if [ -z "$2" ]
              then
                echo "Error: The -m (-medley, --medley) flag requires a path to a full.sysout file as an argument"
                echo "Exiting"
                exit 1
              fi
              shift
              ;;
            *)
              echo "Warning unknown argument: $1.  Ignored"
              ;;
          esac
          shift
        done

        if [ -z "${MEDLEYDIR}" ]
        then
          echo "Error: MEDLEYDIR not specified either thru environment variable or thru command line argument"
          echo "Exiting"
          exit 1
        fi

        full_sysout="${MEDLEYDIR}/loadups/full.sysout"
        if [ ! -f "${full_sysout}" ]
        then
          echo "Error: cannot find the Medley full.sysout file (${full_sysout})"
          echo "It either doesn't exist or is a directory"
          echo "Exiting"
          exit 1
        fi

        . "${MEDLEYDIR}/scripts/loadup-app-setup.sh"

}


# shellcheck disable=SC2164,SC2034
if [ -z "${LOADUP_SCRIPTDIR}" ]
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
        LOADUP_SCRIPTDIR="$(get_script_dir "$0")"
	export LOADUP_SCRIPTDIR

fi

main "$@"
