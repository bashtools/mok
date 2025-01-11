# shellcheck shell=bash disable=SC2148
# MU - Machine Utilities for Podman

# _MU is an associative array that holds data specific to machine utils.
declare -A _MU

# Declare externally defined variables ----------------------------------------

declare ERROR STDERR STOP

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
 
  list    - List the currently created Podman machines. Only one machine
            is currently supported and it will be named 'mok-machine'.
  create  - Create a Podman machine named 'mok-machine'. This will also
            setup the Podman machine to run Kubernetes so there is no
            need to run 'machine setup'.
  destroy - Completely removes the Podman machine named 'mok-machine'.
  start   - Start the Podman machine named 'mok-machine'.
  stop    - Stop the Podman machine named 'mok-machine'.
  setup   - Apply the correct settings to the Podman machine to run
            Kubernetes.
 
For more information:

  machine list -h
  machine create -h
  machine destroy -h
  machine start -h
  machine stop -h
  machine setup -h
 
EnD
}

# Private Functions -----------------------------------------------------------

# _MU_new sets the initial values for the Machine Utils associative array and
# sets up the Parser to call functions in machine*.sh files.
# Args: None expected.
_MU_new() {
  # Program the parser's state machine
  PA_add_state "COMMAND" "machine" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "machinelist" "END" ""
  PA_add_state "SUBCOMMAND" "machinecreate" "END" ""
  PA_add_state "SUBCOMMAND" "machinedestroy" "END" ""
  PA_add_state "SUBCOMMAND" "machinesetup" "END" ""
  PA_add_state "SUBCOMMAND" "machinestart" "END" ""
  PA_add_state "SUBCOMMAND" "machinestop" "END" ""

  # Set up the parser's option callbacks
  PA_add_option_callback "machine" "MU_process_options" || return
  PA_add_option_callback "machinelist" "MU_list_process_options" || return
  PA_add_option_callback "machinecreate" "MU_create_process_options" || return
  PA_add_option_callback "machinedestroy" "MU_destroy_process_options" || return
  PA_add_option_callback "machinesetup" "MU_setup_process_options" || return
  PA_add_option_callback "machinestart" "MU_start_process_options" || return
  PA_add_option_callback "machinestop" "MU_stop_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "machine" "MU_usage" || return
  PA_add_usage_callback "machinelist" "MU_list_usage" || return
  PA_add_usage_callback "machinecreate" "MU_create_usage" || return
  PA_add_usage_callback "machinedestroy" "MU_destroy_usage" || return
  PA_add_usage_callback "machinesetup" "MU_setup_usage" || return
  PA_add_usage_callback "machinestart" "MU_start_usage" || return
  PA_add_usage_callback "machinestop" "MU_stop_usage" || return

  # Set up the parser's run callbacks
  PA_add_run_callback "machinelist" "MU_list_run"
  PA_add_run_callback "machinecreate" "MU_create_run"
  PA_add_run_callback "machinedestroy" "MU_destroy_run"
  PA_add_run_callback "machinesetup" "MU_setup_run"
  PA_add_run_callback "machinestart" "MU_start_run"
  PA_add_run_callback "machinestop" "MU_stop_run"
}

# Initialise _MU
_MU_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
