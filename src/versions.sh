# shellcheck shell=bash disable=SC2148
# CC - Create Cluster - versions file

# CC is an associative array that holds data specific to creating a cluster.
declare -A _CC

# Declare externally defined variables ----------------------------------------

# Defined in GL (globals.sh)
declare OK ERROR STDERR TRUE

# _CC_set_up_master_node_v1_30_0 uses kubeadm to set up the master node.
# Args: arg1 - the container to set up.
_CC_set_up_master_node_v1_30_0() {

  local setupfile lbaddr certSANs="{}" certkey masternum t lbip
  # Set by _CC_get_master_join_details:
  local cahash token masterip

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  masternum="${1##*-}" # <- eg. for xxx-master-1, masternum=1

  if [[ ${_CC[skipmastersetup]} != "${TRUE}" ]]; then

    if [[ ${_CC[withlb]} == "${TRUE}" && ${masternum} -eq 1 ]]; then

      # This is the first master node

      # Sets cahash, token, and masterip:
      lbip=$(CU_get_container_ip "${_CC[clustername]}-lb")
      lbaddr=", '${lbip}'"
      uploadcerts="--upload-certs"
      certkey="CertificateKey: f8802e114ef118304e561c3acd4d0b543adc226b7a27f675f56564185ffe0c07"

    elif [[ ${_CC[withlb]} == "${TRUE}" && ${masternum} -ne 1 ]]; then

      # This is not the first master node, so join with the master
      # https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/

      # Keep trying to get join details until apiserver is ready or we run out of tries
      for try in $(seq 1 9); do
        # Runs a script on master node to get join details
        t=$(_CC_get_master_join_details "${_CC[clustername]}-master-1")
        retval=$?
        [[ ${retval} -eq 0 ]] && break
        [[ ${try} -eq 9 ]] && {
          printf '\nERROR: Problem with "_CC_get_master_join_details". Tried %d times\n\n' "${try}" \
            >"${STDERR}"
          return "${ERROR}"
        }
        sleep 5
      done
      eval "${t}"
    fi
  fi

  # Always set certSANs for the host whether we need it or not
  hostaddr=$(ip ro get 8.8.8.8 | cut -d" " -f 7) || err || return
  certSANs="
  certSANs: [ '${hostaddr}'${lbaddr}, '127.0.0.1', 'localhost' ]"

  # Write the file regardless, so the user can use it if required

  cat <<EnD >"${setupfile}"
# Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

# Use a custom configuration. Default config created from kubeadm with:
#   kubeadm config print init-defaults
# then edited.

ipaddr=\$(ip ro get default 8.8.8.8 | head -n 1 | cut -f 7 -d " ")
podsubnet="10.244.0.0/16"
servicesubnet="10.96.0.0/16"

cat <<EOF >kubeadm-init-defaults.yaml
apiVersion: kubeadm.k8s.io/v1beta4
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
${certkey}
localAPIEndpoint:
  advertiseAddress: \$ipaddr
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/crio/crio.sock
  imagePullPolicy: IfNotPresent
  imagePullSerial: true
  name: $1
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/control-plane
timeouts:
  controlPlaneComponentHealthCheck: 4m0s
  discovery: 5m0s
  etcdAPICall: 2m0s
  kubeletHealthCheck: 4m0s
  kubernetesAPICall: 1m0s
  tlsBootstrap: 5m0s
  upgradeManifests: 5m0s
---
apiServer: ${certSANs}
apiVersion: kubeadm.k8s.io/v1beta4
caCertificateValidityPeriod: 87600h0m0s
certificateValidityPeriod: 8760h0m0s
certificatesDir: /etc/kubernetes/pki
clusterName: ${_CC[clustername]}-cluster
controlPlaneEndpoint: ${lbaddr:-\$ipaddr}:6443
controllerManager: {}
dns: {}
encryptionAlgorithm: RSA-2048
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.k8s.io
kind: ClusterConfiguration
kubernetesVersion: v${_CC[k8sver]}
networking:
  dnsDomain: cluster.local
  podSubnet: \${podsubnet}
  serviceSubnet: \${servicesubnet}
proxy: {}
scheduler: {}
EOF

mkdir -p /mok
cp kubeadm-init-defaults.yaml /mok/kubeadm.yaml

if [[ -z "${masterip}" ]]; then
  # Run the preflight phase
  kubeadm init \\
    --ignore-preflight-errors Swap \\
    --config=kubeadm-init-defaults.yaml \\
    phase preflight

  # Set up the kubelet
  kubeadm init phase kubelet-start

  # Edit the kubelet configuration file
  echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml
  sed -i 's/cgroupDriver: systemd/cgroupDriver: cgroupfs/' /var/lib/kubelet/config.yaml

  # Tell kubeadm to carry on from here
  kubeadm init \\
    --config=kubeadm-init-defaults.yaml \\
    --ignore-preflight-errors Swap \\
    ${uploadcerts} \\
    --skip-phases=preflight,kubelet-start

  export KUBECONFIG=/etc/kubernetes/super-admin.conf

  # Flannel - 10.244.0.0./16
  kubectl apply -f /root/kube-flannel.yml
else
  kubeadm join ${masterip}:6443 \\
    --ignore-preflight-errors Swap \\
    --control-plane \\
    --token ${token} \\
    --discovery-token-ca-cert-hash sha256:${cahash} \\
    --certificate-key f8802e114ef118304e561c3acd4d0b543adc226b7a27f675f56564185ffe0c07
fi

systemctl enable kubelet
EnD

  docker cp "${setupfile}" "$1":/root/setup.sh || err || {
    rm -f "${setupfile}"
    return "${ERROR}"
  }

  # Run the file
  [[ -z ${_CC[skipmastersetup]} ]] && {
    docker exec "$1" bash /root/setup.sh || err || return

    # Remove the taint if we're setting up a single node cluster

    [[ ${_CC[numworkers]} -eq 0 ]] && {

      removetaint=$(mktemp -p /var/tmp) || {
        printf 'ERROR: mktmp failed.\n' >"${STDERR}"
        return "${ERROR}"
      }

      # Write the file
      cat <<'EnD' >"${removetaint}"
export KUBECONFIG=/etc/kubernetes/super-admin.conf
kubectl taint nodes --all node-role.kubernetes.io/control-plane:NoSchedule-
EnD

      docker cp "${removetaint}" "$1":/root/removetaint.sh || err || {
        rm -f "${removetaint}"
        return "${ERROR}"
      }

      # Run the file
      docker exec "$1" bash /root/removetaint.sh || err
    }
  }

  return "${OK}"
}

# _CC_set_up_worker_node_v1_30_0 uses kubeadm to set up the worker node.
# Args: arg1 - the container to set up.
_CC_set_up_worker_node_v1_30_0() {

  local setupfile cahash="$2" token="$3" masterip="$4"

  setupfile=$(mktemp -p /var/tmp) || {
    printf 'ERROR: mktmp failed.\n' >"${STDERR}"
    return "${ERROR}"
  }

  if [[ ${_CC[withlb]} == "${TRUE}" ]]; then
    masterip=$(CU_get_container_ip "${_CC[clustername]}-lb") || return
  fi

  cat <<EnD >"${setupfile}"
# Wait for the master API to become ready
while true; do
  curl -k https://${masterip}:6443/
  [[ \$? -eq 0 ]] && break
  sleep 1
done

# Do the preflight tests (ignoring swap error)
kubeadm join \\
  phase preflight \\
    --token ${token} \\
    --discovery-token-ca-cert-hash sha256:${cahash} \\
    --ignore-preflight-errors Swap \\
    ${masterip}:6443

# Set up the kubelet
kubeadm join \\
  phase kubelet-start \\
    --token ${token} \\
    --discovery-token-ca-cert-hash sha256:${cahash} \\
    ${masterip}:6443 &

while true; do
  [[ -e /var/lib/kubelet/config.yaml ]] && break
    sleep 1
  done

# Edit the kubelet configuration file
echo "failSwapOn: false" >>/var/lib/kubelet/config.yaml
sed -i 's/cgroupDriver: systemd/cgroupDriver: cgroupfs/' /var/lib/kubelet/config.yaml

systemctl enable --now kubelet
EnD

  docker cp "${setupfile}" "$1":/root/setup.sh 2>"${STDERR}" || err || {
    rm -f "${setupfile}"
    return "${ERROR}"
  }

  docker exec "$1" bash /root/setup.sh || err
}

# vim helpers -----------------------------------------------------------------
#include globals.sh
# vim:ft=sh:sw=2:et:ts=2:
