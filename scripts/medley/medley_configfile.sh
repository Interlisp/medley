#!only-to-be-sourced
# shellcheck shell=sh
###############################################################################
#
#    medley_configfile.sh - script for processing the config file for the
#                           medley.sh script.
#
#   !!!! This script is meant to be SOURCEd from the scripts/medley.sh script.
#   !!!! It should not be run as a standlone script.
#
#   2024-04-20 Frank Halasz
#
#   Copyright 2024 Interlisp.org
#
###############################################################################

config_file=""

# look thru args looking to see if a config file was specified
j=1
jmax=$#
while [ "$j" -le "$jmax" ]
do
  if [ "$(eval "printf %s \${${j}}")" = "-c" ] || [ "$(eval "printf %s \${${j}}")" = "--config" ]
  then
    k=$(( j + 1 ))
    config_file="$(eval "printf %s \${${k}}")"
    if [ ! "${config_file}" = "-" ] && [ ! -f "${config_file}" ]
    then
      echo "Error: specified config file \"${config_file}\" not found."
      echo "Exiting."
      exit 52
    fi
    j=$(( j + 1 ))
  fi
  j=$(( j + 1 ))
done

# if no config file specified, use the defaults (if they exist)
if [ -z "${config_file}" ]
then
  for f in "${HOME}/.medley_config" "${MEDLEYDIR}/.medley_config"
  do
    if [ -f "$f" ]
    then
      config_file="$f"
    fi
  done
fi

# add marker to separate config file args from command line args
set -- "--start_cl_args" "--start_cl_args" "$@"

# if there is a config file and its not been suppressed with "-",
# read the config file (in reverse order) and add the first two items on each line
# to the arguments array
if [ -n "${config_file}" ] && [ ! "${config_file}" = "-" ]
then
  rev_config_file="${TMPDIR:-/tmp}"/.medley_config_$$
  # reverse order of lines in medley config file
  sed '1!x;H;1h;$!d;g' < "${config_file}" >"${rev_config_file}"
  while read -r arg1 arg2
  do
    if [ -n "${arg2}" ]
    then
      arg2="$(echo "${arg2}" | sed s/\"//g)"
      set -- "${arg2}" "$@"
    fi
    if [ -n "${arg1}" ]
    then
      set -- "${arg1}" "$@"
    fi
  done < "${rev_config_file}"
  rm -f "${rev_config_file}"
fi



