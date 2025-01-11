# shellcheck shell=bash disable=SC2148

# MACHINE DESTROY ==============================================================

# MU_destroy_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_destroy_process_options() {
  case "$1" in
  -h | --help)
    MU_destroy_usage
    return "${STOP}"
    ;;
  -v | --verbose)
    UT_set_tailf "${TRUE}" || err || return
    ;;
  *)
    MU_destroy_usage
    printf 'ERROR: "%s" is not a valid "create" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# MU_destroy_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_destroy_usage() {

  cat <<'EnD'
machine destroy options:
 
 Format:
  machine destroy [flags]
 
 Flags:
  -h, --help - This help text.
  -v, --verbose - Verbose output. Useful if there was a problem.

 Description:
  This will completely remove a Podman machine named 'mok-machine'.
  A machine must be stopped before it can be destroyed.

EnD
}

# MU_destroy_run deletes a Podman machine.
# Args: None expected.
MU_destroy_run() {
  printf 'This will completely remove the podman machine named "mok-machine"\n'
  printf "Are you sure you want to destroy the machine? (y/N) >"
  read -r ans
  [[ ${ans} != "y" ]] && {
    printf 'Cancelling by user request.\n'
    return "${OK}"
  }
  UT_run_with_progress \
    "    Deleting the Podman machine: mok-machine" \
    podman machine rm -f mok-machine
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }
}

