# MOK - Run Kubernetes on your laptop

![image](https://github.com/user-attachments/assets/0750910e-d6da-4c65-92ea-f7bc64b116cc)


Current kubernetes version: 1.31

*Requirements*

* Fedora 40
* Podman or Docker
* 5 GB of free disk space

*Install*

Use `curl` and download `mok` to `~/.local/bin`:

```bash
curl --output-dir ~/.local/bin -O https://github.com/bashtools/mok/blob/master/package/mok
mkdir -p ~/.local/bin
chmod +x ~/.local/bin/mok
```

or use `git` and `make` and install to `/usr/local/bin`:

```bash
git clone https://github.com/bashtools/mok.git
cd mok
sudo make install
```

*First use*

```bash
# Takes around 10 minutes
sudo mok build image
```

*Create a multi node kuberenetes cluster*

```bash
sudo mok create cluster myk8s --masters 1 --workers 1
```

*Run some kubectl commands*

```bash
export KUBECONFIG=/var/tmp/admin-myk8s.conf
kubectl get nodes
kubectl get pods --all-namespaces
```

```bash
# --privileged is required if you want to `ping`
kubectl run --privileged --rm -ti alpine --image alpine /bin/sh
```

*Get help*

```bash
sudo mok -h
sudo mok create -h
```

*Delete the cluster*

```bash
sudo mok delete cluster myk8s
```

*Uninstall mok completely*

```bash
rm ~/.local/bin/mok
```

Then delete the podman/docker images that were built by `mok build`.

## Known Issues

* With multiple master nodes only the first master is set up

## Some Features

* Builds kubernetes master and worker nodes in containers
* Very simple to use without need for YAML files
* After creating the image a single node cluster builds in under 60 seconds
* For multi-node clusters the 'create cluster' command returns only when kubernetes is completely ready, with all nodes and pods up and ready.
* Can skip setting up kubernetes on the master and/or worker node (good for learning!)
  * In this case the set-up scripts are placed in `/root` in the containers and can be run by hand
  * Can do kubernetes the hard way (see [kthwic](https://github.com/my-own-kind/kubernetes-the-hard-way-in-containers))
* `mok build` and `mok create` can show extensive logs with `--tailf`

* [Full Documentation](https://github.com/bashtools/mokctl-docs/tree/master/docs)
