# shellcheck shell=bash disable=SC2148

# MACHINE LIST ================================================================

# MU_list_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_list_process_options() {
  case "$1" in
  -h | --help)
    MU_list_usage
    return "${STOP}"
    ;;
  *)
    MU_list_usage
    printf 'ERROR: "%s" is not a valid "create" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# MU_list_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_list_usage() {

  cat <<'EnD'
machine list options:
 
 Format:
  machine list [flags]
 
 Flags:
  -h - This help text.

EnD
}

# MU_list_run lists Podman machines.
# Args: None expected.
MU_list_run() {
  info=$(podman machine list --format json) || err || return

  running=$(UT_sed_json_block "${info}" \
    'Name' 'mok-machine' '}' \
    'Running' \
    ) || err || return

  exists=$(UT_sed_json_block "${info}" \
    'Name' 'mok-machine' '}' \
    'Name' \
    ) || err || return

  if [[ ${exists} != "mok-machine" ]]; then
    printf 'mok-machine: does not exist.\n'
  else
    if [[ ${running} == "true" ]]; then
      printf 'mok-machine: running.\n'
    else
      printf 'mok-machine: stopped.\n'
    fi
  fi
}

