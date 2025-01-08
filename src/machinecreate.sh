# shellcheck shell=bash disable=SC2148

# MACHINE CREATE ==============================================================

# MU_create_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_create_process_options() {
  case "$1" in
  -h | --help)
    MU_create_usage
    return "${STOP}"
    ;;
  -v | --verbose)
    UT_set_tailf "${TRUE}" || err || return
    ;;
  *)
    MU_create_usage
    printf 'ERROR: "%s" is not a valid "create" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# MU_create_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_create_usage() {

  cat <<EnD
machine create options:
 
 Format:
  machine create [flags]
 
 Flags:
  -h, --help - This help text.
  -v, --verbose - Verbose output. Useful if there was a problem.

 Description:
  This will create a Podman machine named 'mok-machine' and setup the
  machine to run Kubernetes.
EnD
}

# MU_create_run lists Podman machines.
# Args: None expected.
MU_create_run() {
  UT_run_with_progress \
    "    Creating the Podman machine: mok-machine" \
    podman machine init --now --rootful --user-mode-networking mok-machine
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }

  UT_run_with_progress \
    "    Loading module in mok-machine" \
    podman machine ssh --username root mok-machine modprobe nf_conntrack
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }

  UT_run_with_progress \
    "    Persisting nf_conntrack module in mok-machine" \
    podman machine ssh --username root mok-machine \
      bash -c \
      "\"\\\"echo nf_conntrack \
      >/etc/modules-load.d/nf_conntrack.conf\\\"\""
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }

  UT_run_with_progress \
    "    Setting nf_conntrack_max in mok-machine" \
    podman machine ssh --username root mok-machine sysctl -q \
      -w net.netfilter.nf_conntrack_max=163840
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }

  UT_run_with_progress \
    "    Persisting nf_conntrack_max in mok-machine" \
    podman machine ssh --username root mok-machine \
      bash -c \
      "\"\\\"echo net.netfilter.nf_conntrack_max=163840 \
      >/etc/sysctl.d/99-nf_conntrack_max.conf\\\"\""
  r=$?
  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    cat "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }
}

