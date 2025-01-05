# shellcheck shell=bash disable=SC2148
# MU - Machine Utilities for Podman

# _MU is an associative array that holds data specific to machine utils.
declare -A _MU

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR STOP TRUE FALSE

# Getters/Setters -------------------------------------------------------------

# Public Functions ------------------------------------------------------------

# MU_cleanup removes artifacts that were created during execution. This function
# is run automatically by the Parser library. Currently this does nothing and
# this function could be deleted.
MU_cleanup() { :; }

# MU_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_process_options() {
  case "$1" in
  -h | --help)
    MU_usage
    return "${STOP}"
    ;;
  *)
    MU_usage
    printf 'ERROR: "%s" is not a valid "create" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# MU_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_usage() {

  cat <<'EnD'
MACHINE subcommands are:
 
  list   - List the currently created Podman machines.
           Only one machine is currently supported and if it exists
           it will be named 'mok-machine'.
  create - Create a Podman machine named 'mok-machine'.
  delete - Delete the Podman machine named 'mok-machine'.
  setup  - Modify the Podman machine to automatically apply the correct
           settings to run Kubernetes. Mok will also be copied to the
           Podman machine for cases where the host machine does not
           have GNU tools installed.
 
For more information:

  machine list -h
  machine create -h
  machine delete -h
  machine setup -h
 
EnD
}

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
  echo "MU_list_run"
}

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

  cat <<'EnD'
machine create options:
 
 Format:
  machine create [flags]
 
 Flags:
  -h - This help text.

EnD
}

# MU_create_run lists Podman machines.
# Args: None expected.
MU_create_run() {
  echo "MU_create_run"
}

# MACHINE DELETE ==============================================================

# MU_delete_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_delete_process_options() {
  case "$1" in
  -h | --help)
    MU_delete_usage
    return "${STOP}"
    ;;
  *)
    MU_delete_usage
    printf 'ERROR: "%s" is not a valid "create" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# MU_delete_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_delete_usage() {

  cat <<'EnD'
machine delete options:
 
 Format:
  machine delete [flags]
 
 Flags:
  -h - This help text.

EnD
}

# MU_delete_run deletes a Podman machine.
# Args: None expected.
MU_delete_run() {
  echo "MU_delete_run"
}

# MACHINE SETUP ===============================================================

# MU_setup_process_options checks if arg1 is in a list of valid machine utility
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option.
MU_setup_process_options() {
  case "$1" in
  -h | --help)
    MU_setup_usage
    return "${STOP}"
    ;;
  *)
    MU_setup_usage
    printf 'ERROR: "%s" is not a valid "create" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}


# MU_setup_usage outputs help text for the machine utilities component.
# Args: None expected.
MU_setup_usage() {

  cat <<'EnD'
machine setup options:
 
 Format:
  machine setup [flags]
 
 Flags:
  -h - This help text.

EnD
}

# MU_setup_run sets up a Podman machine.
# Args: None expected.
MU_setup_run() {
  echo "MU_setup_run"
}

# Private Functions -----------------------------------------------------------

# _MU_new sets the initial values for the Machine Utils associative array and
# sets up the Parser to call functions in this file.
# Args: None expected.
_MU_new() {
  # Program the parser's state machine
  PA_add_state "COMMAND" "machine" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "machinelist" "END" ""
  PA_add_state "SUBCOMMAND" "machinecreate" "END" ""
  PA_add_state "SUBCOMMAND" "machinedelete" "END" ""
  PA_add_state "SUBCOMMAND" "machinesetup" "END" ""

  # Set up the parser's option callbacks
  PA_add_option_callback "machine" "MU_process_options" || return
  PA_add_option_callback "machinelist" "MU_list_process_options" || return
  PA_add_option_callback "machinecreate" "MU_create_process_options" || return
  PA_add_option_callback "machinedelete" "MU_delete_process_options" || return
  PA_add_option_callback "machinesetup" "MU_setup_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "machine" "MU_usage" || return
  PA_add_usage_callback "machinelist" "MU_list_usage" || return
  PA_add_usage_callback "machinecreate" "MU_create_usage" || return
  PA_add_usage_callback "machinedelete" "MU_delete_usage" || return
  PA_add_usage_callback "machinesetup" "MU_setup_usage" || return

  # Set up the parser's run callbacks
  PA_add_run_callback "machinelist" "MU_list_run"
  PA_add_run_callback "machinecreate" "MU_create_run"
  PA_add_run_callback "machinedelete" "MU_delete_run"
  PA_add_run_callback "machinesetup" "MU_setup_run"
}

# Initialise _MU
_MU_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
