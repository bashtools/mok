# shellcheck shell=bash disable=SC2148
# BI - Build Image

# _BI is an associative array that holds data specific to building an image.
declare -A _BI

# Declare externally defined variables ----------------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STDERR STOP TRUE FALSE

# Getters/Setters -------------------------------------------------------------

# BI_setflag_useprebuiltimage setter sets the useprebuiltimage array item.
# This is called by the parser, via a callback in _BI_new.
BI_setflag_useprebuiltimage() {
  _BI[useprebuiltimage]="$1"
}

# BI_baseimagename getter outputs the value of the _BI[baseimagename].
# Args: None expected.
BI_baseimagename() {
  printf '%s' "${_BI[baseimagename]}"
}

# Public Functions ------------------------------------------------------------

# BI_usage outputs help text for the build image component.
# It is called by PA_usage(), via a callback in _BI_new.
# Args: None expected.
BI_usage() {

  cat <<'EnD'
BUILD subcommands are:
 
  image - Creates the docker 'mok-image' container image.
 
build image options:
 
 Format:
  build image [flags]

 Flags:
  --get-prebuilt-image - Instead of building a 'node' image
         locally, download it from a container registry instead.
  --k8sver VERSION - The Kubernetes version, e.g. "1.32.0"
         A previous version cannot be built from scratch hence this option
         must be used with '--get-prebuilt-image'. To build a previous
         version of kubernetes it must be built with a previous version
         of mok.
  --tailf - Show the build output whilst building.

EnD
}

# BI_cleanup removes temporary files created during the build.
# This function is called by the 'MA_cleanup' trap only.
# Args: None expected.
BI_cleanup() {
  [[ -e ${_BI[dockerbuildtmpdir]} ]] &&
    [[ ${_BI[dockerbuildtmpdir]} == "/var/tmp/"* ]] && {
    rm -rf "${_BI[dockerbuildtmpdir]}" || {
      printf 'ERROR: "rm -rf %s" failed.\n' "${_BI[dockerbuildtmpdir]}" \
        >"${STDERR}"
      err || return
    }
  }
}

# BI_check_valid_options checks if arg1 is in a list of valid build image
# options. This function is called by the parser, via a callback in _BI_new.
# Args: arg1 - the option to check.
#       arg2 - value of the item to be set, optional
BI_process_options() {

  case "$1" in
  -h | --help)
    BI_usage
    return "${STOP}"
    ;;
  --tailf)
    _BI[tailf]="${TRUE}"
    return "${OK}"
    ;;
  --k8sver)
    _BI[k8sver]="$2"
    return "$(PA_shift)"
    ;;
  --get-prebuilt-image)
    _BI[useprebuiltimage]="${TRUE}"
    return "${OK}"
    ;;
  *)
    BI_usage
    printf 'ERROR: "%s" is not a valid "build" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# BI_run builds the base image used for masters and workers.
# This function is called in main.sh.
# Args: None expected.
BI_run() {

  _BI_sanity_checks || return

  [[ ${_BI[tailf]} == "${TRUE}" ]] && {
    UT_set_tailf "${TRUE}" || err || return
  }

  local retval=0
  _BI_build_container_image
  retval=$?

  if [[ ${retval} -eq ${OK} ]]; then
    : # We only need the tick - no text
  else
    printf 'Image build failed\n' >"${STDERR}"
    err
  fi

  return "${retval}"
}

# Private Functions -----------------------------------------------------------

# _BI_new resets the initial values for the _BI associative array.
# Args: None expected.
_BI_new() {
  _BI[tailf]="${FALSE}"
  _BI[baseimagename]="mok-image"
  _BI[useprebuiltimage]="${FALSE}"
  _BI[dockerbuildtmpdir]=
  _BI[k8sver]="${K8SVERSION}"

  # Program the parser's state machine
  PA_add_state "COMMAND" "build" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "buildimage" "END" ""

  # Set up the parser's option callbacks
  PA_add_option_callback "build" "BI_process_options" || return
  PA_add_option_callback "buildimage" "BI_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "build" "BI_usage" || return
  PA_add_usage_callback "buildimage" "BI_usage" || return

  # Set up the parser's run callbacks
  PA_add_run_callback "buildimage" "BI_run"
}

# BI_sanity_checks is expected to run some quick and simple checks to
# see if it has all it's key components. For build image this does nothing.
# This function should not be deleted as it is called in main.sh.
# Args: None expected.
_BI_sanity_checks() {

  if [[ -z $(PA_subcommand) ]]; then
    BI_usage
    exit "${OK}"
  fi
}

# _BI_build_container_image creates the docker build directory in
# dockerbuildtmpdir then calls docker build to build the image.
# Args: No args expected.
_BI_build_container_image() {

  local cmd retval tagname buildargs text buildtype basename

  _BI_create_docker_build_dir || return

  buildargs=$(_BI_get_build_args_for_latest) || return
  basename="${_BI[baseimagename]}_$(MA_arch)"
  tagname="${_BI[k8sver]}"

  local imgprefix
  imgprefix=$(CU_imgprefix) || err || return
  if [[ ${_BI[useprebuiltimage]} == "${FALSE}" ]]; then
    # Each mok release can build the hardcoded version only
    # so reset the tagname to that version
    tagname="${K8SVERSION}"
    buildtype="create"
    cmd="docker build \
      -t "${imgprefix}local/${basename}:${tagname}" \
      --force-rm \
      ${buildargs} \
      ${_BI[dockerbuildtmpdir]}/${_BI[baseimagename]}"
    text="Creating"
  else
    # We can download and run any available version
    buildtype="download"
    cmd="docker pull docker.io/myownkind/${basename}:${tagname}"
    text="Downloading"
  fi

  UT_run_with_progress \
    "    ${text} base image, '${basename}:${tagname}'" "${cmd}"

  retval=$?
  [[ ${retval} -ne ${OK} ]] && {
    local runlogfile
    runlogfile=$(UT_runlogfile) || err || return
    printf 'ERROR: Docker returned an error, shown below\n\n' >"${STDERR}"
    cat "${runlogfile}" >"${STDERR}"
    printf '\n' >"${STDERR}"
    return "${ERROR}"
  }

  [[ ${buildtype} == "create" ]] && {
    cmd="_BI_modify_container_image"

    UT_run_with_progress \
      "    Modifying base image (pulling kubernetes images)" "${cmd}"

    retval=$?
    [[ ${retval} -ne ${OK} ]] && {
      local runlogfile
      runlogfile=$(UT_runlogfile) || err || return
      printf 'ERROR: Docker returned an error, shown below\n\n' >"${STDERR}"
      cat "${runlogfile}" >"${STDERR}"
      printf '\n' >"${STDERR}"
      return "${ERROR}"
    }
  }

  return "${OK}"
}

# _BI_modify_container_image starts a container suitable for running kubernetes
# components (since the docker/podman build environment isn't suitable), makes
# some modifications and then 'commits' the image. The modifications allow
# `mok create ...` to complete more quickly.
# Args: No args expected.
_BI_modify_container_image() {

  # Delete container, just in case it was left behind
  docker stop -t 5 mok-build-modify &>/dev/null
  docker rm mok-build-modify &>/dev/null

  CC_set_clustername "build" || err || return

  # Start container
  CU_create_container "mok-build-modify" "mok-build-modify" "${K8SVERSION}" ||
    return

  # Wait for crio to become ready
  local counter
  printf '\n\n ** WAITING FOR CRIO TO BECOME READY **\n\n'
  while ! docker exec mok-build-modify systemctl status crio; do
    sleep 1
    [[ ${counter} -gt 10 ]] && {
      printf '\nERROR: CRI-O did not start after %d tries.\n' "${counter}"
      err || return
    }
    ((counter++))
  done

  # Modify container
  docker exec mok-build-modify kubeadm config images pull \
    --kubernetes-version "${K8SVERSION}" || err || return

  # Stop container
  docker stop -t 5 "mok-build-modify"

  # Write image
  local imgprefix tagname basename
  imgprefix=$(CU_imgprefix) || err || return
  basename="${_BI[baseimagename]}_$(MA_arch)"
  tagname="${K8SVERSION}"
  docker commit mok-build-modify "${imgprefix}local/${basename}:${tagname}" || err || return

  # Delete container, just in case it was left behind
  docker stop -t 5 mok-build-modify
  docker rm mok-build-modify || err || return

  return "${OK}"
}

# _BI_get_build_args_for_latest sets the buildargs variable that is added
# to the 'podman build ...' command line.  Only the latest version is built
# from scratch.  Earlier versions are downloaded using '--get-prebuilt-image'.
# Args: None expected
_BI_get_build_args_for_latest() {

  local buildargs

  buildargs="--build-arg GO_VERSION=${GO_VERSION}"

  printf '%s' "${buildargs}"
}

# _BI_create_docker_build_dir creates a docker build directory in
# /var/tmp/tmp.XXXXXXXX
# Args: None expected
_BI_create_docker_build_dir() {

  _BI[dockerbuildtmpdir]="$(mktemp -d -p /var/tmp)" || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    err || return
  }

  # The following comments should not be removed or changed.
  # embed-dockerfile.sh adds a base64 encoded tarball and
  # unpacking code between them.

  #mok-image-tarball-start
  #mok-image-tarball-end
}

# Initialise _BI
_BI_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
