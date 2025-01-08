# shellcheck shell=bash disable=SC2148

# MACHINE STOP ================================================================

# MU_stop_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_stop_process_options() {
  case "$1" in
  -h | --help)
    MU_stop_usage
    return "${STOP}"
    ;;
  *)
    MU_stop_usage
    printf 'ERROR: "%s" is not a valid "stop" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# MU_stop_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_stop_usage() {

  cat <<EnD
machine stop options:
 
 Format:
  machine stop [flags]
 
 Flags:
  -h - This help text.

 Description:
  This will stop a Podman machine named 'mok-machine'.
  Stop the podman machine with: $(MA_program_name) machine stop
EnD
}

# MU_stop_run lists Podman machines.
# Args: None expected.
MU_stop_run() {
  UT_run_with_progress \
    "    Stopping Podman machine: mok-machine" \
    podman machine stop mok-machine
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }
}


