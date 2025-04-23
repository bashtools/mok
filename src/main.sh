# shellcheck shell=bash disable=SC2148
# MA - execution starts here

# MA is an associative array that holds data specific to this file
declare -A _MA

# Defined in GL (globals.sh)
declare OK ERROR STOP STDERR TRUE __mokostype __mokarch

# Getters/Setters -------------------------------------------------------------

# MA_program_args getter outputs the program arguments sent by the user.
MA_program_args() {
  printf '%s' "${_MA[program_args]}"
}

# MA_arg_1 getter outputs the first argument sent by the user.
# Used by _CU_podman_checks so it doesn't check for a podman machine
# if we're running 'machine' commands
# FIXME: The command might not be the first argument. It could be '-p'
MA_arg_1() {
  printf '%s' "${_MA[arg_1]}"
}

# MA_program_name getter outputs the name of the program.
MA_program_name() {
  printf '%s' "${_MA[arg_0]##*/}"
}

# MA_ostype getter outputs the OS type.
MA_ostype() {
  printf '%s' "${_MA[ostype]}"
}

# MA_ostype getter outputs the machine architecture.
MA_arch() {
  printf '%s' "${_MA[arch]}"
}

# Public Functions ------------------------------------------------------------

# main is the start point for this application.
# Args: arg1-N - the command line arguments entered by the user.
MA_main() {
  local retval="${OK}"

  CU_podman_or_docker

  trap MA_cleanup EXIT
  MA_sanity_checks || return
  PA_run "$@" || retval=$?

  exit "${retval}"
}

# MA_version outputs the version information the exits.
MA_version() {
  printf 'Version: %s\n' "${MOKVERSION}"
  exit "${OK}"
}

# MA_process_global_options is called by the parser when a global option is
# encountered for processing.
# Args: arg1 - the global option that was found.
MA_process_global_options() {
  case "$1" in
  -h | --help)
    PA_usage
    return "${STOP}"
    ;;
  -p | --plain)
    UT_set_plain "${TRUE}"
    ;;
  *)
    printf 'INTERNAL ERROR: Invalid global option, "%s".' "$1"
    return "${ERROR}"
    ;;
  esac
}

# MA_cleanup is called from an EXIT trap only, when the program exits, and
# calls every other function matching the pattern '^.._cleanup'.
# Args: No args expected.
MA_cleanup() {
  local retval="${OK}" funcs func
  funcs=$(declare -F | awk '{print $NF;}' | grep '^.._cleanup')
  for func in ${funcs}; do
    [[ ${func} == "${FUNCNAME[0]}" ]] && continue
    eval "${func}" || retval=$?
  done
  return "${retval}"
}

# MA_sanity_checks is expected to run some quick and simple checks to
# see if key components are available before MA_main is called.
# Args: No args expected.
MA_sanity_checks() {

  local binary binaries

  if [[ $(CU_podmantype) == "native" ]]; then
    binaries="gawk tac column tput grep sed ip cut"
  else
    binaries="gawk tac column tput grep sed cut"
  fi

  for binary in ${binaries}; do
    if ! command -v "${binary}" >&/dev/null; then
      printf 'ERROR: "%s" binary not found in path. Aborting.' "${binary}" \
        >"${STDERR}"
      return "${ERROR}"
    fi
  done

  # Disable terminal escapes (colours) if stdout is not a terminal
  [ -t 1 ] || UT_disable_colours
}

# MA_usage outputs help text for all components then quits with no error.  This
# is registered as a callback in the Parser, see _MA_new
# Args: None expected.
MA_usage() {

  cat <<'EnD'
Usage: mok [-h] <command> [subcommand] [ARGS...]
 
Global options:
  --help
  -h     - This help text
  --plain
  -p     - Plain output. No colours or animations.
 
Where command can be one of:
  create  - Add item(s) to the system.
  delete  - Delete item(s) from the system.
  build   - Build item(s) used by the system.
  get     - Get details about items in the system.
  exec    - 'Log in' to the container.
  machine - Manage a podman machine (MacOS only).
  version - Display version information.

For help on a specific command, run:
  mok <command> --help
EnD
}

# MA_new sets the initial values for the _MA associative array
_MA_new() {
  _MA[program_args]="$*"
  _MA[arg_0]="$0"
  _MA[arg_1]="$1"
  _MA[ostype]="${__mokostype}" # linux or macos
  _MA[arch]="${__mokarch}" # x86_64 or arm64

  # Program the parser's state machine
  PA_add_state "COMMAND" "version" "END" "MA_version"

  # Set up the parser's option callbacks
  PA_add_option_callback "" "MA_process_global_options"

  # Set up the parser's usage callbacks
  PA_add_usage_callback "" "MA_usage"
}

# Initialise _MA
_MA_new "$@" || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
