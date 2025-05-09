# shellcheck shell=bash disable=SC2148
# CC - Create Cluster

# CC is an associative array that holds data specific to creating a cluster.
declare -A _CC

# Declare externally defined variables ----------------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STDERR STOP TRUE FALSE K8SVERSION

# Getters/Setters -------------------------------------------------------------

# CC_set_clustername setter sets the clustername array item.
CC_clustername() {
  printf '%s' "${_CC[clustername]}"
}

# CC_publish getter outputs the publish array item.
CC_publish() {
  printf '%s' "${_CC[publish]}"
}

# CC-withlb getter outputs the withlb array item.
CC_withlb() {
  printf '%s' "${_CC[withlb]}"
}

# CC_set_clustername setter sets the clustername array item.
CC_set_clustername() {
  _CC[clustername]="$1"
}

# CC_set_nummasters setter sets the nummasters array item.
# This function is called by the parser, via a callback in _CC_new.
CC_set_nummasters() {
  _CC[nummasters]="$1"
}

# CC_set_numworkers setter sets the numworkers array item.
# This function is called by the parser, via a callback in _CC_new.
CC_set_numworkers() {
  _CC[numworkers]="$1"
}

# Public Functions ------------------------------------------------------------

# CC_process_options checks if arg1 is in a list of valid create cluster
# options. This function is called by the parser.
# Args: arg1 - the option to check.
#       arg2 - value of the option to be set, optional. This depends on the
#              type of option. For example, '--masters' should be sent
#              with a value but boolean options, like 'skiplbsetup' should not.
CC_process_options() {

  case "$1" in
  -h | --help)
    CC_usage
    return "${STOP}"
    ;;
  --skiplbsetup)
    _CC[skiplbsetup]="${TRUE}"
    return
    ;;
  --k8sver)
    _CC[k8sver]="$2"
    return "$(PA_shift)"
    ;;
  --with-lb)
    _CC[withlb]="${TRUE}"
    return
    ;;
  --skipmastersetup)
    _CC[skipmastersetup]="${TRUE}"
    return
    ;;
  --skipworkersetup)
    _CC[skipworkersetup]="${TRUE}"
    return
    ;;
  --masters)
    _CC[nummasters]="$2"
    return "$(PA_shift)"
    ;;
  --workers)
    _CC[numworkers]="$2"
    return "$(PA_shift)"
    ;;
  --tailf)
    _CC[tailf]="${TRUE}"
    return "${OK}"
    ;;
  --publish)
    _CC[publish]="${TRUE}"
    return
    ;;
  *)
    CC_usage
    printf 'ERROR: "%s" is not a valid "create" option.\n' "${1}" \
      >"${STDERR}"
    return "${ERROR}"
    ;;
  esac
}

# CC_usage outputs help text for the create cluster component.  It is called in
# this file and by PA_usage(), via a callback set in _CC_new.
# Args: None expected.
CC_usage() {

  cat <<'EnD'
CREATE subcommands are:
 
  cluster - Create a local kubernetes cluster.
 
create cluster [flags] options:
 
 Format:
  create cluster NAME [ [NUM_MASTERS] [NUM_WORKERS] ]
  NAME        - The name of the cluster. This will be used as
                the prefix in the name for newly created
                docker containers.
  NUM_MASTERS - The number of master containers.
  NUM_WORKERS - The number of worker containers. If NUM_WORKERS is
                zero then the 'node-role.kubernetes.io/master' taint
                will be removed from master nodes so that pods are
                schedulable.
 
 Flags:
  --skipmastersetup - Create the master container but don't set it
         up. Useful for manually installing kubernetes. Kubeadm, 
         kubelet and kubectl will be installed at the requested 
         version. With this option the worker will also be skipped.
         See also '--k8sver' flag.
  --skipworkersetup - The same as '--skipmastersetup', but skips
         setting up the worker only.
  --with-lb - Add a haproxy load balancer. The software will be installed
         and set up to reverse proxy to the master node(s), unless
         --skiplbsetup is used.
  --k8sver VERSION - The Kubernetes version, e.g. "1.32.0".
         A previous version will need to be downloaded first with:
           mok build image --get-prebuilt-image --k8sver VERSION
  --masters NUM - The number of master containers to create.
  --workers NUM - The number of worker containers to create. When workers
                  is zero then the master node taint will be removed from
                  master nodes so that pods are schedulable on those nodes.
  --tailf - Show the log output whilst creating the cluster.
  --publish - Publish port 6443 for the master node, or the load balancer if
              it's enabled, for external kubectl access to the cluster. The IP
              address of the default route interface is added to the cert.

EnD
}

# CC_run creates the kubernetes cluster.
# Args: None expected.
CC_run() {

  _CC_sanity_checks || return

  [[ ${_CC[tailf]} == "${TRUE}" ]] && {
    UT_set_tailf "${TRUE}" || err || return
  }

  declare -i numnodes=0

  numnodes=$(CU_get_cluster_size "${_CC[clustername]}") || return

  [[ ${numnodes} -gt 0 ]] && {
    printf '\nERROR: Cluster, "%s", exists! Aborting.\n\n' "${_CC[clustername]}" \
      >"${STDERR}"
    return "${ERROR}"
  }

  [[ ${_CC[withlb]} -eq ${TRUE} ]] && {
    _CC_create_lb_node "${_CC[nummasters]}" || return
  }

  [[ ${_CC[nummasters]} -gt 0 ]] && {
    _CC_create_master_nodes "${_CC[nummasters]}" || return
  }

  [[ ${_CC[withlb]} -eq ${TRUE} ]] && {
    _CC_setup_lb_node "${_CC[nummasters]}" || return
  }

  [[ ${_CC[nummasters]} -gt 0 ]] && {
    _CC_setup_master_nodes "${_CC[nummasters]}" || return
  }

  [[ ${_CC[numworkers]} -gt 0 ]] && {
    _CC_create_worker_nodes "${_CC[numworkers]}" || return
  }

  printf '\n'

  [[ -z ${_CC[skipmastersetup]} ]] && {
    printf 'Cluster, "%s", can be accessed using:\n\n' "${_CC[clustername]}"
    printf 'export KUBECONFIG=/var/tmp/admin-%s.conf\n\n' "${_CC[clustername]}"
  }

  return "${OK}"
}

# Private Functions -----------------------------------------------------------

# _CC_new sets the initial values for the _CC associative array and sets up the
# parser ready for processing the command line arguments, options and usage.
# Args: None expected.
_CC_new() {
  _CC[tailf]="${FALSE}"
  _CC[skipmastersetup]=
  _CC[skipworkersetup]=
  _CC[skiplbsetup]=
  _CC[withlb]=
  _CC[clustername]=
  _CC[nummasters]=0
  _CC[numworkers]=0
  _CC[publish]=0
  _CC[k8sver]="${K8SVERSION}"

  # Program the parser's state machine
  PA_add_state "COMMAND" "create" "SUBCOMMAND" ""
  PA_add_state "SUBCOMMAND" "createcluster" "ARG2" ""

  # Support for the legacy style of create (less to type):
  PA_add_state "ARG1" "createcluster" "ARG2" "CC_set_clustername"
  PA_add_state "ARG2" "createcluster" "ARG3" "CC_set_nummasters"
  PA_add_state "ARG3" "createcluster" "END" "CC_set_numworkers"

  # Set up the parser's option callbacks
  PA_add_option_callback "create" "CC_process_options" || return
  PA_add_option_callback "createcluster" "CC_process_options" || return

  # Set up the parser's usage callbacks
  PA_add_usage_callback "create" "CC_usage" || return
  PA_add_usage_callback "createcluster" "CC_usage" || return

  # Set up the parser's run callbacks
  PA_add_run_callback "createcluster" "CC_run"
  PA_add_run_callback "createclusters" "CC_run"
}

# CC_sanity_checks is expected to run some quick and simple checks to see if it
# has it's main requirements before CC_run is called.
# Args: None expected.
_CC_sanity_checks() {

  declare -i host_max=0 cpus=0 should_be=0

  if [[ -z $(PA_subcommand) ]]; then
    CC_usage
    exit "${OK}"
  fi

  if [[ -z ${_CC[clustername]} ]]; then
    CC_usage
    printf 'Please provide the Cluster NAME to create.\n' >"${STDERR}"
    return "${ERROR}"
  fi

  if [[ -z ${_CC[nummasters]} || ${_CC[nummasters]} -le 0 ]]; then
    CC_usage
    printf 'Please provide the number of Masters to create. Must be 1 or more.\n' \
      >"${STDERR}"
    return "${ERROR}"
  fi

  if [[ -z ${_CC[numworkers]} ]]; then
    CC_usage
    printf 'Please provide the number of Workers to create.\n' >"${STDERR}"
    return "${ERROR}"
  fi

  if [[ $(CU_podmantype) == "native" && -e /proc/sys/net/nf_conntrack_max ]]; then
    host_max=$(cat /proc/sys/net/nf_conntrack_max)
  elif [[ $(CU_podmantype) == "machine" ]]; then
    # Lazily assuming the file exists
    host_max=$(podman machine ssh mok-machine cat /proc/sys/net/nf_conntrack_max)
  else
    printf '\nWARNING: /proc/sys/net/nf_conntrack_max not found.\n' >"${STDERR}"
    printf '         kube-proxy may not work.\n\n' >"${STDERR}"
  fi

  if [[ $(CU_podmantype) == "native" && -e /proc/cpuinfo ]]; then
    cpus=$(grep -cw ^processor /proc/cpuinfo)
  elif [[ $(CU_podmantype) == "machine" ]]; then
    # Lazily assuming the file exists
    cpus=$(podman machine ssh mok-machine cat /proc/cpuinfo | grep -cw ^processor)
  else
    printf '\nWARNING: /proc/cpuinfo not found.\n' >"${STDERR}"
    printf '         I have no idea how many CPUs I have\n' >"${STDERR}"
    printf '         and kube-proxy may not work.\n\n' >"${STDERR}"
  fi

  # These are the default values that kube-proxy expects:
  # conntrack:
  #   max: null
  #   maxPerCore: 32768
  #   min: 131072
  if [[ $((32768*cpus)) -lt 131072 ]]; then
    should_be=131072
  else
    should_be=$((32768*cpus))
  fi
  if [[ ${should_be} -ne $host_max ]]; then
    printf '\nERROR: /proc/sys/net/nf_conntrack_max should be set to %d.\n' \
      "${should_be}" >"${STDERR}"
    printf '     kube-proxy will not start with an incorrect nf_conntrack_max.\n' >"${STDERR}"
    printf '     To fix this, run the following command:\n\n' >"${STDERR}"
    if [[ $(CU_podmantype) == "native" ]]; then
      printf '       sudo sysctl -w net.netfilter.nf_conntrack_max=%d\n\n' \
        "${should_be}" >"${STDERR}"
    elif [[ $(CU_podmantype) == "machine" ]]; then
      printf '       %s machine setup\n\n' "$(MA_program_name)" >"${STDERR}"
    else
      printf 'Internal ERROR. Invalid podman type.\n' >"${STDERR}"
      return "${ERROR}"
    fi
    
    printf 'Press ENTER to continue or CTRL-C to abort.\n' >"${STDERR}"
    read -r
    printf '\n' >"${STDERR}"
  fi
}

# _CC_create_master_nodes creates the master node containers.
# Args: arg1 - number of master nodes to create
_CC_create_master_nodes() {

  declare -i int=0 r

  local labelkey runlogfile
  labelkey=$(CU_labelkey) || err || return

  for int in $(seq 1 "$1"); do
    UT_run_with_progress \
      "    Creating master container, '${_CC[clustername]}-master-${int}'" \
      CU_create_container \
      "${_CC[clustername]}-master-${int}" \
      "${labelkey}=${_CC[clustername]}" \
      "${_CC[k8sver]}"
    r=$?

    [[ ${r} -ne 0 ]] && {
      runlogfile=$(UT_runlogfile) || err || return
      printf '\n'
      cat "${runlogfile}" >"${STDERR}"
      printf '\nERROR: Docker failed.\n' >"${STDERR}"
      return "${ERROR}"
    }
  done

  return "${OK}"
}

# _CC_setup_master_nodes sets up the master node containers.
# Args: arg1 - number of master nodes to create
_CC_setup_master_nodes() {

  declare -i int=0 r

  local labelkey runlogfile lbaddr hostaddr
  labelkey=$(CU_labelkey) || err || return

  for int in $(seq 1 "$1"); do
    UT_run_with_progress \
      "    Setting up '${_CC[clustername]}-master-${int}'" \
      _CC_set_up_master_node "${_CC[clustername]}-master-${int}"
    r=$?

    [[ ${r} -ne 0 ]] && {
      runlogfile=$(UT_runlogfile) || err || return
      printf '\n' >"${STDERR}"
      cat "${runlogfile}" >"${STDERR}"
      printf '\nERROR: Set up failed. See above, and also in the file:' >"${STDERR}"
      printf '%s\n' "${runlogfile}" >"${STDERR}"
      return "${ERROR}"
    }
  done

  # For now, copy admin.conf from master to /var/tmp/admin-CLUSTERNAME.conf

  if [[ -z ${_CC[skipmastersetup]} ]]; then
    if [[ ${_CC[publish]} -eq ${TRUE} ]]; then
      # On MacOS we need to use localhost, on linux use the host IP
      if [[ $(CU_podmantype) == "native" ]]; then
        hostaddr=$(ip ro get 8.8.8.8 | cut -d" " -f 7) || err || return
      else
        hostaddr="localhost"
      fi
      docker cp "${_CC[clustername]}-master-1:/etc/kubernetes/admin.conf" \
        "/var/tmp/admin-${_CC[clustername]}.conf" >/dev/null || err || return
      sed -i 's#\(server: https://\)[0-9.]*\(:.*\)#\1'"${hostaddr}"'\2#' \
        "/var/tmp/admin-${_CC[clustername]}.conf"
    elif [[ ${_CC[withlb]} -eq ${TRUE} ]]; then
      lbaddr=$(CU_get_container_ip "${_CC[clustername]}-lb") || err || return
      docker cp "${_CC[clustername]}-master-1:/etc/kubernetes/admin.conf" \
        "/var/tmp/admin-${_CC[clustername]}.conf" >/dev/null || err || return
      sed -i 's#\(server: https://\)[0-9.]*\(:.*\)#\1'"${lbaddr}"'\2#' \
        "/var/tmp/admin-${_CC[clustername]}.conf"
    else
      [[ -n ${_CC[skipmastersetup]} ]] || {
        docker cp "${_CC[clustername]}-master-1:/etc/kubernetes/admin.conf" \
          "/var/tmp/admin-${_CC[clustername]}.conf" >/dev/null || err || return
      }
    fi

    chmod 666 "/var/tmp/admin-${_CC[clustername]}.conf" || {
      printf 'ERROR: Could not "chown 666 /var/tmp/admin-%s.conf"' "${_CC[clustername]}"
      err || return
    }
  fi

  return "${OK}"
}

# _CC_set_up_master_node calls the correct set up function based on the version
# Args: arg1 - the container ID to set up
_CC_set_up_master_node() {

  case "${_CC[k8sver]}" in
  "1.31."* | "1.32."* | "1.33."*)
    _CC_set_up_master_node_v1_30_0 "$@"
    ;;
  *)
    printf 'ERROR: Version not found, "%s".\n' "${_CC[k8sver]}" >"${STDERR}"
    err || return
    ;;
  esac
}

# _CC_get_master_join_details uses 'docker exec' or 'podman exec' to run a
# script on the master to get CA hash, a token, and the master IP.  The caller
# can eval the output of this function to set the variables: cahash, token, and
# masterip. See also:
# https://kubernetes.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#token-based-discovery-with-ca-pinning
# Args: arg1 - id/name of master container
_CC_get_master_join_details() {

  local joinvarsfile master1ip

  joinvarsfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  master1ip=$(CU_get_container_ip "${_CC[clustername]}-master-1") || err || return

  cat <<EnD >"${joinvarsfile}"
#!/bin/bash
set -e

sed 's#\(server: https://\)[0-9.]*\(:.*\)#\1'"${master1ip}"'\2#' \
  /etc/kubernetes/super-admin.conf >/etc/kubernetes/admin2.conf

cahash=\$(openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | \
        openssl rsa -pubin -outform der 2>/dev/null | \
        openssl dgst -sha256 -hex | sed 's/^.* //')
token=\$(kubeadm token create --kubeconfig=/etc/kubernetes/admin2.conf 2>/dev/null)
ip=\$(ip ro get 8.8.8.8 | cut -d" " -f 7)

printf 'cahash=%s\ntoken=%s\nmasterip=%s' "\$cahash" "\$token" "\$ip"

exit 0
EnD

  docker cp "${joinvarsfile}" "$1":/root/joinvars.sh 2>"${STDERR}" ||
    err || return
  rm -f "${joinvarsfile}" 2>"${STDERR}" || err || return

  [[ -z ${_CC[skipworkersetup]} ]] && {
    docker exec "$1" bash /root/joinvars.sh 2>"${STDERR}" || err || return
  }

  return "${OK}"
}

# _CC_create_lb_node creates the load balancer node container.
# Args: None expected.
_CC_create_lb_node() {

  local labelkey runlogfile
  labelkey=$(CU_labelkey) || err || return

  # Create container
  UT_run_with_progress \
    "    Creating load balancer container, '${_CC[clustername]}-lb'" \
    CU_create_container \
    "${_CC[clustername]}-lb" \
    "${labelkey}=${_CC[clustername]}" \
    "${_CC[k8sver]}"

  [[ ${r} -ne 0 ]] && {
    runlogfile=$(UT_runlogfile) || err || return
    printf '\n' >"${STDERR}"
    cat "${runlogfile}" >"${STDERR}"
    printf '\nERROR: Set up failed. See above, and also in the file:' >"${STDERR}"
    printf '%s\n' "${runlogfile}" >"${STDERR}"
    return "${ERROR}"
  }

  return "${OK}"
}

# _CC_setup_lb_node sets up the load balancer node container.
# Args: None expected.
_CC_setup_lb_node() {

  local runlogfile

  # Set up
  [[ -z ${_CC[skiplbsetup]} ]] && {
    UT_run_with_progress \
      "    Setting up '${_CC[clustername]}-lb'" \
      _CC_set_up_lb_node_real "${_CC[clustername]}-lb"
    r=$?

    [[ ${r} -ne 0 ]] && {
      runlogfile=$(UT_runlogfile) || err || return
      printf '\n' >"${STDERR}"
      cat "${runlogfile}" >"${STDERR}"
      printf '\nERROR: Set up failed. See above, and also in the file:' >"${STDERR}"
      printf '%s\n' "${runlogfile}" >"${STDERR}"
      return "${ERROR}"
    }
  }

  return "${OK}"
}

# _CC_set_up_lb_node_real sets up the lb node.
# Args: arg1 - the container ID to set up
_CC_set_up_lb_node_real() {

  local setupfile nl idx masteriplist

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  masteriplist=
  nl=
  gotamaster="${FALSE}"
  for idx in $(seq 1 "${_CC[nummasters]}"); do
    ip=$(CU_get_container_ip "${_CC[clustername]}-master-${idx}") || continue
    gotamaster="${TRUE}"
    masteriplist="${masteriplist}${nl}    server master-${idx} ${ip}:6443 check fall 3 rise 2"
    nl='\n'
  done

  [[ ${gotamaster} == "${FALSE}" ]] && {
    printf 'ERROR: Did not manage to get an IP address for any master nodes\n'
    err || return
  }

  cat <<EnD >"${setupfile}"
# Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

systemctl stop kubelet crio
systemctl disable kubelet crio

apt -y install haproxy

INTERNAL_IP=\$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")

cat <<EOF | tee /etc/haproxy/haproxy.cfg 
frontend kubernetes
    bind \$INTERNAL_IP:6443
    option tcplog
    mode tcp
    default_backend kubernetes-master-nodes
backend kubernetes-master-nodes
    mode tcp
    balance roundrobin
    option tcp-check
\$(echo -e "${masteriplist}")
EOF

systemctl restart haproxy
systemctl enable haproxy

EnD

  docker cp "${setupfile}" "$1":/root/setup.sh || err || {
    rm -f "${setupfile}"
    return "${ERROR}"
  }

  docker exec "$1" bash /root/setup.sh || err
}

# _CC_create_worker_nodes creates the worker nodes.
# Args: arg1 - number of worker nodes to create
_CC_create_worker_nodes() {

  local cahash token t masterip
  declare -i int=0

  [[ -n ${_CC[skipmastersetup]} ]] || {
    # Runs a script on master node to get details
    t=$(_CC_get_master_join_details "${_CC[clustername]}-master-1") || {
      printf '\nERROR: Problem with "_CC_get_master_join_details".\n\n' >"${STDERR}"
      return "${ERROR}"
    }

    # Sets cahash, token, and masterip:
    eval "${t}"
  }

  local labelkey
  labelkey=$(CU_labelkey) || err || return

  for int in $(seq 1 "$1"); do
    UT_run_with_progress \
      "    Creating worker container, '${_CC[clustername]}-worker-${int}'" \
      CU_create_container \
      "${_CC[clustername]}-worker-${int}" \
      "${labelkey}=${_CC[clustername]}" \
      "${_CC[k8sver]}"
    r=$?
    [[ ${r} -ne 0 ]] && {
      runlogfile=$(UT_runlogfile) || err || return
      printf '\n'
      cat "${runlogfile}" >"${STDERR}"
      printf '\nERROR: Docker failed.\n' >"${STDERR}"
      return "${ERROR}"
    }

    [[ -n ${_CC[skipworkersetup]} || -n ${_CC[skipmastersetup]} ]] || {
      UT_run_with_progress \
        "    Setting up '${_CC[clustername]}-worker-${int}'" \
        _CC_set_up_worker_node "${_CC[clustername]}-worker-${int}" \
        "${cahash}" "${token}" "${masterip}"
      r=$?
      [[ ${r} -ne 0 ]] && {
        runlogfile=$(UT_runlogfile) || err || return
        printf '\n' >"${STDERR}"
        cat "${runlogfile}" >"${STDERR}"
        printf '\nERROR: Set up failed. See above, and also in the file:' >"${STDERR}"
        printf '%s\n' "${runlogfile}" >"${STDERR}"
        return "${ERROR}"
      }

      UT_run_with_progress \
        "    Waiting for system to become ready" \
        _CC_wait_for_cluster \
        "${_CC[clustername]}-master-1" \
        "${_CC[clustername]}-worker-${int}"
      r=$?
      [[ ${r} -ne 0 ]] && {
        runlogfile=$(UT_runlogfile) || err || return
        printf '\n'
        cat "${runlogfile}" >"${STDERR}"
        printf '\nERROR: Wait timed out.\n' >"${STDERR}"
        return "${ERROR}"
      }
    }
  done

  return "${OK}"
}

# _CC_wait_for_cluster runs a `kubectl` command in the master-1 container,
# which doesn't exit until the all pods are fully up and running before it
# returns.
# Args: arg1 - the master container name to log into
#       arg2 - the worker container name to wait for
_CC_wait_for_cluster() {

  local setupfile nl idx masteriplist

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  cat <<'EnD' >"${setupfile}"
export KUBECONFIG=/etc/kubernetes/super-admin.conf
found=0
for i in $(seq 1 20); do
  if kubectl get pods &>/dev/null; then
    found=1
    break
  fi
  sleep 1
done
[[ $found == 0 ]] && {
  printf '# kubectl get pods\n'
  kubectl get pods
  printf '\nWaited for 20 seconds for kubectl to work.\n'
  printf 'Kubectl cannot contact master. Aborting.\n'
  exit 1
}
counter=0
while ! kubectl get nodes | grep -qs "$1"; do
  ((counter++))
  [[ ${counter} -gt 60 ]] && {
    printf '# kubectl get nodes\n'
    kubectl get nodes
    printf '\nWaited for 2 minutes for node to appear in master. Aborting.\n'
    exit 1
  }
  sleep 2
done
counter=0
while kubectl get pods -A | tail -n +2 | awk '{ print $3; }' | grep -qs 0; do
  ((counter++))
  [[ ${counter} -gt 120 ]] && {
    printf '# kubectl get pods -A\n'
    kubectl get pods -A
    printf '\nWaited for 3 minutes for pods to be ready. Aborting.\n'
    exit 1
  }
  sleep 2
done
exit 0
EnD

  docker cp "${setupfile}" "$1":/root/wait.sh || err || {
    rm -f "${setupfile}"
    return "${ERROR}"
  }

  docker exec "$1" bash /root/wait.sh "$2" || err
}

# _CC_set_up_worker_node calls the correct set up function based on the version.
# Args: arg1 - the container ID to set up
#       arg2 - the CA hash
#       arg3 - the token
#       arg4 - the master IP
_CC_set_up_worker_node() {

  case "${_CC[k8sver]}" in
  "1.31."* | "1.32."* | "1.33."*)
    _CC_set_up_worker_node_v1_30_0 "$@"
    ;;
  *)
    printf 'ERROR: Version not found, "%s".\n' "${_CC[k8sver]}" >"${STDERR}"
    err || return
    ;;
  esac
}

# Initialise _CC
_CC_new || exit 1

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
