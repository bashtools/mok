# MOK - Run Kubernetes on your laptop

![image](https://github.com/user-attachments/assets/0750910e-d6da-4c65-92ea-f7bc64b116cc)


Current kubernetes version: 1.31

## Requirements

**Fedora 40 Desktop/Server on x86_64 or AMD64**
* Podman
* 5 GB of free disk space

**MacOS 14.7 (Sonoma) on Apple Silicon**
* Podman
* 5 GB of free disk space

Mok may work on other versions of Linux or MacOS but I have only tested it on the above.

## Install

Use `curl` and download `mok` to `/usr/local/bin`:

```bash
curl -O https://raw.githubusercontent.com/bashtools/mok/refs/heads/master/package/mok
chmod +x mok
sudo mv mok /usr/local/bin/
```

or use `git` and `make` and install to `/usr/local/bin`:

```bash
git clone https://github.com/bashtools/mok.git
cd mok
sudo make install
```

### First use

For linux users: `alias mok="sudo /usr/local/bin/mok"`

```bash
# Takes around 10 minutes
mok build image
```

### Create a multi node kuberenetes cluster

```bash
mok create cluster myk8s --masters 1 --workers 1
```

### Run some kubectl commands

```bash
export KUBECONFIG=/var/tmp/admin-myk8s.conf
kubectl get nodes
kubectl get pods --all-namespaces
```

```bash
# --privileged is required if you want to `ping`
kubectl run --privileged --rm -ti alpine --image alpine /bin/sh
```

### Get help

```bash
mok -h
mok create -h
```

### Delete the cluster

```bash
mok delete cluster myk8s
```

### Uninstall mok completely

```bash
sudo rm /usr/local/bin/mok

# If you used git and make delete the git repo
rm -rf mok/
```

Then delete the podman images that were built by `mok build`.

## Known Issues

**Fedora and MacOS:**
* With multiple master nodes only the first master is set up
* Containers cannot be stopped then restarted

**MacOS only:**
* A recent version of Bash is required.
  * Use homebrew to install `bash` and `gawk`
  * add `eval "$(/opt/homebrew/bin/brew shellenv)` to the end of your `.zprofile` or `.bash_profile` so that
  brew installed files are found first.
* To be able to use `kubectl` from the host machine and to be able to modify `nf_conntrack_max` the machine needs to be created with:
  ```bash
  podman machine init --rootful --user-mode-networing
  ```
  * This allows a kubernetes cluster to be created with the `--publish` option, for example:
    ```bash
    mok create cluster myk8s 1 0 --publish
    ```
    Then the commands in the 'Run some kubectl commands' section above will work without any modification.
* `kube-proxy` requires a correctly set `nf_conntrack_max`. If it's incorrect then mok will supply the command to correct it and will also suggest the following commands be run:
    ```
    # WARNING - This will delete all your existing pods/containers and anything else in the podman machine:
    podman machine stop
    podman machine rm
    podman machine init --now --rootful --user-mode-networing
    podman machine ssh modprobe nf_conntrack
    podman machine ssh sysctl -w net.netfilter.nf_conntrack_max=163840
    ```

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
