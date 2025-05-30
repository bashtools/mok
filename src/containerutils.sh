# shellcheck shell=bash disable=SC2148
# CU - Container Utilities

# _CU is an associative array that holds data specific to container utils.
declare -A _CU

# Declare externally defined variables ----------------------------------------

declare OK ERROR STDERR

# Getters/Setters -------------------------------------------------------------

# CU_containerrt getter outputs the container runtime (podman or docker)
# that has been chosen.
CU_containerrt() {
  printf '%s' "${_CU[containerrt]}"
}

# CU_imgprefix getter outputs the prefix to be used with docker build. For
# podman it is 'localhost/'. For docker it is empty.
CU_imgprefix() {
  printf '%s' "${_CU[imgprefix]}"
}

# CU_labelkey getter outputs the key value of the label that is applied to all
# cluster member's container labels for podman or docker.
CU_labelkey() {
  printf '%s' "${_CU[labelkey]}"
}

# CU_podmantype getter outputs the container runtime type (native or machine).
CU_podmantype() {
  printf '%s' "${_CU[podmantype]}"
}

# Public Functions ------------------------------------------------------------

# CU_cleanup removes artifacts that were created during execution. Currently
# this does nothing and this function could be deleted.
CU_cleanup() { :; }

# CU_get_cluster_container_ids outputs just the container IDs, one per line
# for any MOK cluster, unless arg1 is set, in which case just the IDs
# for the requested cluster name are output.
# Args: arg1 - The cluster name, optional.
CU_get_cluster_container_ids() {

  local value output

  [[ -n $1 ]] && value="=$1"

  output=$(docker ps -a -f label="${_CU[labelkey]}${value}" -q) || {
    printf 'ERROR: %s command failed\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }

  output=$(printf '%s' "${output}" | sed 's/$//')

  printf '%s' "${output}"

  return "${OK}"
}

# CU_get_cluster_size searches for an existing cluster using labels and outputs
# the number of containers in that cluster. All cluster nodes are labelled with
# "${_CU[labelkey]}=${CC[clustername]}"
# Args: arg1 - The cluster name to search for.
CU_get_cluster_size() {

  local output
  declare -a nodes

  [[ -z ${1} ]] && {
    printf 'INTERNAL ERROR: Cluster name cannot be empty.\n' >"${STDERR}"
    err || return
  }

  output=$(CU_get_cluster_container_ids "$1") || err || return

  # readarray will read null as an array item so don't run
  # through readarray if it's null
  [[ -z ${output} ]] && {
    printf '0'
    return "${OK}"
  }

  # read the nodes array and delete blank lines
  readarray -t nodes <<<"${output}"

  printf '%d' "${#nodes[*]}"
}

# CU_get_container_ip outputs the IP address of the container.
# Args: arg1 - docker container id or container name to query.
CU_get_container_ip() {

  local info

  [[ -z ${1} ]] && {
    printf 'INTERNAL ERROR: Container ID (arg1) cannot be empty.\n' >"${STDERR}"
    err || return
  }

  info=$(CU_get_container_info "$1") || return
  JSONPath '.[0].NetworkSettings.Networks.*.IPAddress' -b <<<"${info}" ||
    err || return
}

# CU_get_container_info uses 'docker/podman inspect $id' to output
# container details.
# Args: arg1 - docker container id
CU_get_container_info() {

  [[ -z ${1} ]] && {
    printf 'INTERNAL ERROR: Container ID (arg1) cannot be empty.\n' >"${STDERR}"
    err || return
  }

  docker inspect "$1" || {
    printf 'ERROR: %s inspect failed\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }
}

# CU_create_container creates and runs a container with settings suitable for
# running privileged containers that can manipulate cgroups.
# Args: arg1 - The string used to set the name and hostname.
#       arg2 - The label to assign to the container.
#       arg3 - The k8s base image version to use.
CU_create_container() {

  local imagename img allimgs systemd_always clustername parg pval root_user url port

  [[ -z $1 || -z $2 || -z $3 ]] && {
    printf 'INTERNAL ERROR: Neither arg1, arg2 nor arg3 can be empty.\n' \
      >"${STDERR}"
    err || return
  }

  img="$(BI_baseimagename)_$(MA_arch)"

  local imglocal="${_CU[imgprefix]}local/${img}"
  local imgremote="myownkind/${img}"
  local imgtag="${3}"

  # Prefer a locally built container over one downloaded from a registry
  allimgs=$(docker images | tail -n +2) || {
    printf 'ERROR: %s returned an error\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }

  if echo "${allimgs}" | grep -qs "${imglocal} *${imgtag}"; then
    imagename="${imglocal}:${imgtag}"
  elif echo "${allimgs}" | grep -qs "${imgremote} *${imgtag}"; then
    imagename="${imgremote}:${imgtag}"
  else
    cat <<EnD
ERROR: No container base image found. Use either:

  $ mok build image
OR
  $ mok build image --get-prebuilt-image

Then try running 'mok create ...' again.
EnD
    return "${ERROR}"
  fi

  clustername=$(CC_clustername) || err || return

  if [[ ${_CU[containerrt]} == "podman" ]];
  then 
    docker network exists "${clustername}_network" >/dev/null 2>&1
    create_network=$?
  else
    docker network inspect "${clustername}_network" >/dev/null 2>&1
    create_network=$?
  fi

  [[ ${create_network} -ne 0 ]] && {
    docker network create "${clustername}_network" || {
      printf 'ERROR: docker network create failed\n' >"${STDERR}"
      err || return
    }
  }

  # Docker does not have the --systemd option
  [[ ${_CU[containerrt]} == "podman" ]] && systemd_always="--systemd=always"
  [[ ${_CU[podmantype]} == "machine" ]] && {
    root_user="--user=root"
    # TODO: A named podman machine does not work the same way
    #       as the default podman machine. Rootful doesn't work
    #       for a named machine so need to use '--url'. Ask
    #       Podman developers about this.
    port=$(podman machine inspect mok-machine | grep Port | grep -o '[0-9]\+')
    url="--url ssh://root@127.0.0.1:$port/run/podman/podman.sock"
  }

  [[ $(CC_publish) == "${TRUE}" ]] && {
    if [[ $(CC_withlb) == "${TRUE}" ]]; then
      if echo "$1" | grep -qs -- '-lb$'; then
        parg='-p'
        pval='6443:6443'
      fi
    else
      if echo "$1" | grep -qs -- '-master-1$'; then
        parg='-p'
        pval='6443:6443'
      fi
    fi
  }

  # shellcheck disable=SC2086
  docker ${url} run --privileged ${systemd_always} ${root_user} \
    --network "${clustername}_network" \
    -v /lib/modules:/lib/modules:ro \
    --detach ${parg} ${pval} \
    --name "$1" \
    --hostname "$1" \
    --label "$2" \
    "${imagename}" \
    /usr/local/bin/entrypoint /lib/systemd/systemd log-level=info unit=sysinit.target || {
    printf 'ERROR: %s run failed\n' "${_CU[containerrt]}" >"${STDERR}"
    err || return
  }
}

# CU_podman_or_docker checks to see if docker and/or podman are installed and
# sets the imgprefix and containerrt array members accordingly. It also defines
# the docker function to run the detected container runtime. Podman is
# preferred if both are installed.
# Args: No args expected.
CU_podman_or_docker() {
  if type podman &>/dev/null; then
    _CU[imgprefix]="localhost/"
    _CU[containerrt]="podman"
    _CU_podman_checks || return
  elif type docker &>/dev/null; then
    _CU[imgprefix]=""
    _CU[containerrt]="docker"
    _CU_docker_checks || return
  else
    printf 'ERROR: Neither "podman" nor "docker" were found.\n' \
      >"${STDERR}"
    printf 'Please install one of "podman" or "docker".\nAborting.\n' \
      >"${STDERR}"
    return "${ERROR}"
  fi
  return "${OK}"
}

# Private Functions -----------------------------------------------------------

# _CU_docker_checks checks to see if the current user has permission to write
# to the docker socket. If not, it prints an error message and exits.
# Args: No args expected.
_CU_docker_checks() {
  if [[ ! -e /proc/sys/kernel/hostname ]]; then
    printf 'ERROR: Docker is currently supported on Linux only'
    exit "${ERROR}"
  fi

  if docker ps >/dev/stdout 2>&1 | grep -qs 'docker.sock.*permission denied'; then
    cat <<EnD >"${STDERR}"
Not enough permissions to write to 'docker.sock'.

Please use 'sudo' to run this command.

$ sudo mok $(MA_program_args)

Or set up an alias, for example:

$ alias mok="sudo mok"

Then run the command again.
EnD
    exit "${ERROR}"
  fi

  _CU[podmantype]="native"
  return "${OK}"
}

# _CU_podman_checks sets the _CU[podmantype] member to "native" or "machine"
# depending on whether this is linux or macos. We assume linux won't be using
# a podman machine, and macos will always be using a podman machine.
# Args: No args expected.
_CU_podman_checks() {
  local info running exists

  if [[ -e /proc/sys/kernel/hostname ]]; then
    # We're on linux
    _CU[podmantype]="native"
    _CU_podman_native_checks || return
  elif [[ -d /System/Library/CoreServices ]]; then
    # We're on macOS
    [[ $(id -u) -eq 0 ]] && {
      printf 'ERROR: Cannot run mok as root on macOS.\n' >"${STDERR}"
      exit "${ERROR}"
    }

    info=$(podman machine list --format json) || err || return
    running=$(UT_sed_json_block "${info}" \
      'Name' 'mok-machine' '}' \
      'Running' \
      ) || err || return
    exists=$(UT_sed_json_block "${info}" \
      'Name' 'mok-machine' '}' \
      'Name' \
      ) || err || return

    if [[ $(MA_arg_1) != "machine" && ${exists} != "mok-machine" ]]; then
      printf 'ERROR: Podman machine does not exist.\n' >"${STDERR}"
      printf '       Create a Podman machine with: %s machine create\n' \
        "$(MA_program_name)" >"${STDERR}"
      exit "${ERROR}"
    elif [[ ${running} == "true" ]]; then
      _CU[podmantype]="machine"
    elif [[ $(MA_arg_1) != "machine" ]]; then
      # Don't check for a podman machine if we're running 'machine' commands
      printf 'ERROR: Podman machine is not running.\n' >"${STDERR}"
      printf '       Try starting the machine with: %s machine start\n' \
        "$(MA_program_name)" >"${STDERR}"
      exit "${ERROR}"
    fi
  else
    printf 'ERROR: Unknown OS. Aborting.\n' >"${STDERR}"
    exit "${ERROR}"
  fi
}

# _CU_podman_native_checks checks to see if the current user is root. If not,
# it prints an error message and exits.
# Args: No args expected.
_CU_podman_native_checks() {
  [[ $(id -u) -ne 0 ]] && {
    cat <<EnD >"${STDERR}"
Please use 'sudo' to run this command.

$ sudo mok $(MA_program_args)

Or set up an alias, for example:

$ alias mok="sudo mok"

Then run the command again.
EnD
    exit "${ERROR}"
  }
}

# _CU_new sets the initial values for the Container Utils associative array.
# Args: None expected.
_CU_new() {
  _CU[imgprefix]=
  _CU[labelkey]="MokCluster"
  _CU[containerrt]=

  # _CU[podmantype] will only be set only if _CU[containerrt]=podman.
  # podmantype will be "native" or "machine".
  _CU[podmantype]=
}

# Override `docker` depending on _CU[containerrt]
# [[ -n ${_CU[containerrt]} ]] && {
  docker() {
    local cmd port url

    if [[ "${_CU[containerrt]}" == "podman" && "${_CU[podmantype]}" == "machine" ]]; then
      # TODO: A named podman machine does not work the same way
      #       as the default podman machine. Rootful doesn't work
      #       for a named machine so need to use '--url'. Ask
      #       Podman developers about this.
      port=$(podman machine inspect mok-machine | grep Port | grep -o '[0-9]\+')
      url="ssh://root@127.0.0.1:$port/run/podman/podman.sock"

      # TODO: This would be preferred to '--url'
      # podman -c mok-machine "$@"
      podman --url "${url}" "$@"
    elif [[ "${_CU[containerrt]}" == "podman" ]]; then
      podman "$@"
    else
      cmd=$(which -a docker | tail -n 1)
      $cmd "$@"
    fi
  }
# }

# Override `ip` depending on _CU[podmantype]
ip() {
  local cmd
  if [[ "${_CU[podmantype]}" == "machine" ]]; then
    podman machine ssh mok-machine ip "$@"
  else
    cmd=$(which -a ip | tail -n 1)
    $cmd "$@"
  fi
}

# Initialise _CU
_CU_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
