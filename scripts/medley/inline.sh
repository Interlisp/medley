#!/usr/bin/env sh
# MIT License
#
# Copyright (c) 2022-2022 Carlo Corradini
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Inspired by https://gist.github.com/joehillen/30f08738c1c3c0ca3e4c754ad33ad2ff

# Fail on error
set -o errexit
# Disable wildcard character expansion
set -o noglob

# PID shell
SELF_PID=$$

# ================
# LOGGER
# ================
# Fatal log level. Cause exit failure
LOG_LEVEL_FATAL=100
# Warning log level
LOG_LEVEL_WARN=200
# Informational log level
LOG_LEVEL_INFO=300
# Debug log level
LOG_LEVEL_DEBUG=400
# Silent log level
LOG_LEVEL_SILENT=500
# Log level
LOG_LEVEL=$LOG_LEVEL_INFO
# Log color flag
LOG_COLOR_ENABLE=true

# Convert log level to equivalent name
# @param $1 Log level
to_log_level_name() {
  _log_level=${1:-LOG_LEVEL}
  _log_level_name=

  case $_log_level in
    "$LOG_LEVEL_FATAL") _log_level_name=fatal ;;
    "$LOG_LEVEL_WARN") _log_level_name=warn ;;
    "$LOG_LEVEL_INFO") _log_level_name=info ;;
    "$LOG_LEVEL_DEBUG") _log_level_name=debug ;;
    "$LOG_LEVEL_SILENT") _log_level_name=silent ;;
    *) FATAL "Unknown log level '$_log_level'" ;;
  esac

  printf "%s\n" "$_log_level_name"
}

# Print log message
# @param $1 Log level
# @param $2 Message
_log_print_message() {
  _log_level=${1:-LOG_LEVEL_FATAL}
  shift
  _log_level_name=
  _log_message=${*:-}
  _log_prefix=
  _log_suffix="\033[0m"

  # Check log level
  if [ "$LOG_LEVEL" -eq "$LOG_LEVEL_SILENT" ] || [ "$_log_level" -gt "$LOG_LEVEL" ]; then
    return 0
  fi

  case $_log_level in
    "$LOG_LEVEL_FATAL")
      _log_level_name=FATAL
      _log_prefix="\033[41;37m"
      ;;
    "$LOG_LEVEL_WARN")
      _log_level_name=WARN
      _log_prefix="\033[1;33m"
      ;;
    "$LOG_LEVEL_INFO")
      _log_level_name=INFO
      _log_prefix="\033[37m"
      ;;
    "$LOG_LEVEL_DEBUG")
      _log_level_name=DEBUG
      _log_prefix="\033[1;34m"
      ;;
  esac

  # Check color flag
  if [ "$LOG_COLOR_ENABLE" = false ]; then
    _log_prefix=
    _log_suffix=
  fi

  # Log
  printf '%b[%-5s] %b%b\n' "$_log_prefix" "$_log_level_name" "$_log_message" "$_log_suffix"
}

# Fatal log message
# @param $1 Message
FATAL() {
  _log_print_message "$LOG_LEVEL_FATAL" "$1" >&2
  exit 1
}
# Warning log message
# @param $1 Message
WARN() { _log_print_message "$LOG_LEVEL_WARN" "$1" >&2; }
# Informational log message
# @param $1 Message
INFO() { _log_print_message "$LOG_LEVEL_INFO" "$1" >&2; }
# Debug log message
# @param $1 Message
DEBUG() { _log_print_message "$LOG_LEVEL_DEBUG" "$1" >&2; }

# ================
# FUNCTIONS
# ================
# Show help message
show_help() {
  cat << EOF
Usage: $(basename "$0") --in-file <FILE> [--disable-color] [--help] [--log-level <LEVEL>] [--out-file <FILE>] [--overwrite]

reCluster bundle script.

Options:
  --disable-color      Disable color

  --help               Show this help message and exit

  --in-file <FILE>     Input file
                       Values:
                         Any valid file

  --log-level <LEVEL>  Logger level
                       Default: $(to_log_level_name "$LOG_LEVEL")
                       Values:
                         fatal    Fatal level
                         warn     Warning level
                         info     Informational level
                         debug    Debug level
                         silent   Silent level

  --out-file <FILE>    Output file
                       Default: [IN_FILE_NAME].inlined[IN_FILE_EXTENSION]
                       Values:
                         Any valid file

  --overwrite          Overwrite input file
EOF
}

# Assert command is installed
# @param $1 Command name
assert_cmd() {
  command -v "$1" > /dev/null 2>&1 || FATAL "Command '$1' not found"
  DEBUG "Command '$1' found at '$(command -v "$1")'"
}

# ================
# CACHE
# ================
# Cache
CACHE=

# Add file path to cache
# @param $1 File path
cache_add() {
  if [ -z "$CACHE" ]; then
    CACHE=$(printf '%s\n' "$1")
  else
    CACHE=$(printf '%s\n%s\n' "$CACHE" "$1")
  fi
}

# Check cache has file path
# @param $1 File path
cache_has() {
  while read -r _entry; do
    if [ "$_entry" = "$1" ]; then
      return 0
    fi
  done << EOF
$CACHE
EOF

  return 1
}

# Inline sources ('source' or '.') of given script file
# @param $1 Script file path
inline_sources() {
  _file=$1
  _file_dir=$(dirname "$_file")
  _regex='^([[:space:]]*)(source|\.)[[:space:]]+(.+)'
  _regex_inline_skip='^[[:space:]]*#[[:space:]]*inline[[:space:]]+skip.*'
  _regex_shellcheck='^[[:space:]]*#[[:space:]]*shellcheck[[:space:]]+source=(.+)'
  _inline_skip=false
  _source_file_shellcheck=

  [ -f "$_file" ] || FATAL "File '$_file' does not exists"
  INFO "Reading file '$_file'"

  # Add to cache
  cache_add "$_file"

  # Read
  while IFS='' read -r _line; do
    DEBUG "Analyzing line '$_line'"

    if printf "%s\n" "$_line" | grep -q -E "$_regex_inline_skip"; then
      # # inline skip
      _inline_skip=true
      DEBUG "Inline skip '$_line'"

      # Print line
      printf '%s\n' "$_line"
    elif printf "%s\n" "$_line" | grep -q -E "$_regex_shellcheck"; then
      # # shellcheck source=...
      DEBUG "ShellCheck source '$_line'"

      # Source
      _source_file_shellcheck=$(printf "%s\n" "$_line" | sed -n -r "s/$_regex_shellcheck/\1/p")
      # Print line
      printf '%s\n' "$_line"
    elif printf "%s\n" "$_line" | grep -q -E "$_regex"; then
      # source ...
      # . ...
      DEBUG "Source '$_line'"

      # Source
      _source_file=$(printf "%s\n" "$_line" | sed -n -r "s/$_regex/\3/p" | sed -e 's/^"//' -e 's/"$//')

      # Check skip
      [ "$_inline_skip" = false ] || {
        # Skip
        WARN "Skipping source '$_line'"
        # Reset inline skip
        _inline_skip=false
        # Reset shellcheck
        _source_file_shellcheck=
        # Print line
        printf '%s\n' "$_line"
        continue
      }

      # Resolve source path
      _path=
      if printf "%s\n" "$_source_file" | grep -q -E -v '.*\/.*'; then
        # Search $PATH
        DEBUG "Searching '\$PATH'"

        _path=$(command -v "$_source_file" || :)
      fi
      if [ -z "$_path" ]; then
        # Resolve links, relative paths, ~, quotes, and escapes
        DEBUG "Path is undefined, continue searching"

        _path=$_source_file
        if printf "%s\n" "$_path" | grep -q -E -v '^\/|^\$'; then
          # Path does not start with '/' or '$' symbol, preprend directory
          _path="$_file_dir/$_path"
        fi

        # Canonicalize
        _path=$(eval readlink -f "$_path" || :)
        DEBUG "Path candidate '$_path'"

        if [ ! -f "$_path" ] && [ -n "$_source_file_shellcheck" ]; then
          # File does not exists, try shellcheck
          DEBUG "Path '$_path' is invalid, searching ShellCheck"

          _path=$_source_file_shellcheck
          if printf "%s\n" "$_path" | grep -q -E -v '^\/'; then
            # Path does not start with '/' symbol, preprend directory
            _path="$_file_dir/$_path"
          fi

          # Canonicalize
          _path=$(readlink -f "$_path" || :)
          DEBUG "Path candidate '$_path'"
          # Reset shellcheck
          _source_file_shellcheck=
        fi
      fi

      # Check path
      [ -f "$_path" ] || FATAL "Unable to resolve source file path '$_source_file'"
      DEBUG "Source '$_source_file' resolved to '$_path'"

      # Comment source
      printf '# %s\n' "$_line"

      # Check if already sourced
      ! cache_has "$_path" || {
        WARN "Recursion detected, source '$_source_file' of '$_file'"
        kill $SELF_PID
        wait $SELF_PID
      }

      # Inline source and remove shebang
      inline_sources "$_path" | sed '/^#!.*/d'
    else
      # Reset inline skip
      _inline_skip=false
      # Reset shellcheck
      _source_file_shellcheck=
      # Print line
      printf '%s\n' "$_line"
    fi
  done < "$_file"
}

################################################################################################################################

# Parse command line arguments
# @param $@ Arguments
parse_args() {
  # Assert argument has a value
  # @param $1 Argument name
  # @param $2 Argument value
  parse_args_assert_value() {
    [ -n "$2" ] || FATAL "Argument '$1' requires a non-empty value"
  }

  while [ $# -gt 0 ]; do
    case $1 in
      --disable-color)
        # Disable color
        LOG_COLOR_ENABLE=false
        shift
        ;;
      --help)
        # Display help message and exit
        show_help
        exit 0
        ;;
      --in-file)
        # Input file
        parse_args_assert_value "$@"

        IN_FILE=$2
        shift
        shift
        ;;
      --log-level)
        # Log level
        parse_args_assert_value "$@"

        case $2 in
          fatal) LOG_LEVEL=$LOG_LEVEL_FATAL ;;
          warn) LOG_LEVEL=$LOG_LEVEL_WARN ;;
          info) LOG_LEVEL=$LOG_LEVEL_INFO ;;
          debug) LOG_LEVEL=$LOG_LEVEL_DEBUG ;;
          silent) LOG_LEVEL=$LOG_LEVEL_SILENT ;;
          *) FATAL "Value '$2' of argument '$1' is invalid" ;;
        esac
        shift
        shift
        ;;
      --out-file)
        # Output file
        parse_args_assert_value "$@"

        OUT_FILE=$2
        shift
        shift
        ;;
      --overwrite)
        # Overwrite
        OVERWRITE=true
        shift
        ;;
      -*)
        # Unknown argument
        WARN "Unknown argument '$1' is ignored"
        shift
        ;;
      *)
        # No argument
        WARN "Skipping argument '$1'"
        shift
        ;;
    esac
  done

  # Determine output file
  if [ "$OVERWRITE" = true ]; then
    # Input file
    OUT_FILE=$IN_FILE
  elif [ -n "$IN_FILE" ] && [ -z "$OUT_FILE" ]; then
    # Input file 'inlined'
    _in_file_basename=$(basename -- "$IN_FILE")
    _in_file_name="${_in_file_basename%.*}"
    _in_file_extension=
    case $_in_file_basename in
      *.*) _in_file_extension=".${_in_file_basename##*.}" ;;
    esac

    OUT_FILE="$_in_file_name.inlined$_in_file_extension"
  fi
}

# Verify system
verify_system() {
  assert_cmd grep
  assert_cmd sed

  [ -n "$IN_FILE" ] || FATAL "Input file required"
  [ -f "$IN_FILE" ] || FATAL "Input file '$IN_FILE' does not exists"
  if [ "$OVERWRITE" = false ] && [ -f "$OUT_FILE" ]; then FATAL "Output file '$OUT_FILE' already exists"; fi
}

# Inline input file
inline() {
  INFO "Inlining file '$IN_FILE'"
  _inlined=$(inline_sources "$(readlink -f "$IN_FILE")") || FATAL "Error inlining file '$IN_FILE'"

  INFO "Saving file '$OUT_FILE'"
  printf '%s\n' "$_inlined" > "$OUT_FILE"
}

# ================
# CONFIGURATION
# ================
# Input file
IN_FILE=
# Log level
LOG_LEVEL=$LOG_LEVEL_INFO
# Log color flag
LOG_COLOR_ENABLE=true
# Output file
OUT_FILE=
# Overwrite flag
OVERWRITE=false

# ================
# MAIN
# ================
{
  parse_args "$@"
  verify_system
  inline
}

