#!/usr/bin/env bash

export KUBECONFIG=/etc/kubernetes/super-admin.conf
# Wait for api server to become ready
# shellcheck disable=SC2034
for i in {1..60}; do
  if kubectl get pods -n kube-system -l k8s-app=kube-proxy --no-headers=true | grep -qs Running; then
    break
  fi
  sleep 1
done
sleep 2
ipv4=$(cat /mok/old-ipv4)
kubectl get configmap kube-proxy -n kube-system -o yaml > /tmp/kube-proxy.yaml
sed -i '/^ *creationTimestamp:/d;/^ *resourceVersion:/d;/^ *uid:/d' /tmp/kube-proxy.yaml
sed -i "s#\(^ *server: \).*#\1https://$ipv4:6443#" /tmp/kube-proxy.yaml
kubectl apply -f /tmp/kube-proxy.yaml -n kube-system
kubectl delete pod -l k8s-app=kube-proxy -n kube-system
sleep 2
systemctl restart kubelet
