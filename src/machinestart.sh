# shellcheck shell=bash disable=SC2148

# MACHINE START ===============================================================

# MU_start_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_start_process_options() {
  case "$1" in
  -h | --help)
    MU_start_usage
    return "${STOP}"
    ;;
  -v | --verbose)
    UT_set_tailf "${TRUE}" || err || return
    ;;
  *)
    MU_start_usage
    printf 'ERROR: "%s" is not a valid "start" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# MU_start_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_start_usage() {

  cat <<EnD
machine start options:
 
 Format:
  machine start [flags]
 
 Flags:
  -h, --help - This help text.
  -v, --verbose - Verbose output. Useful if there was a problem.

 Description:
  This will start a Podman machine named 'mok-machine'.
  Start the podman machine with: $(MA_program_name) machine start
EnD
}

# MU_start_run lists Podman machines.
# Args: None expected.
MU_start_run() {
  UT_run_with_progress \
    "    Starting Podman machine: mok-machine" \
    podman machine start mok-machine
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }
}

