# MOK - Run Kubernetes on your laptop

![image](https://github.com/user-attachments/assets/0750910e-d6da-4c65-92ea-f7bc64b116cc)


Default kubernetes version: 1.33.0

Available kubernetes versions:

| Minor version | versions |
| ------------- | -------- |
| 1.31.x        | not supported |
| 1.32.x        | 1.32.0, 1.32.1, 1.32.2, 1.32.3, 1.32.4 |
| 1.33.x        | 1.33.0, 1.33.1 |

## TL;DR Quick Start

Install:

```bash
curl -O https://raw.githubusercontent.com/bashtools/mok/refs/heads/master/package/mok
chmod +x mok
sudo mv mok /usr/local/bin/
```

Create cluster:

```
mok build image --get-prebuilt-image
mok create cluster myk8s --masters 1 --publish
```

Use cluser:

```
export KUBECONFIG=/var/tmp/admin-myk8s.conf
kubectl get nodes
kubectl get pods --all-namespaces
kubectl run --privileged --rm -ti alpine --image alpine /bin/sh
```

Delete cluster:

```
mok delete cluster myk8s
```

## Requirements

**MacOS**
* Mok will will install any required packages using Homebrew, and will prompt you before doing so.
* To see exactly how and what will be installed, see `src/macos.sh`.

**Fedora Desktop or Server**
* Install Podman.

## Install

### Installation for Linux and Mac

Use `curl` to download `mok` and move it to `/usr/local/bin`:

```bash
curl -O https://raw.githubusercontent.com/bashtools/mok/refs/heads/master/package/mok
chmod +x mok
sudo mv mok /usr/local/bin/
```

## Using Mok

### Build a container image

```bash
mok build image --get-prebuilt-image
```

### Create a single node kuberenetes cluster

```bash
mok create cluster myk8s --masters 1 --publish
```

For Mac users `--publish` must be used - but it's optional for Linux users:

### Run some kubectl commands

Naturally, the [kubectl command](https://kubernetes.io/docs/tasks/tools/) is needed for this.

```bash
export KUBECONFIG=/var/tmp/admin-myk8s.conf
kubectl get nodes
kubectl get pods --all-namespaces
```

```bash
# --privileged is required if you want to `ping` a host
kubectl run --privileged --rm -ti alpine --image alpine /bin/sh
```

### Get help

```bash
mok -h
mok create -h
mok build -h
mok machine -h
# ... etc ...
```

### Delete the cluster

```bash
mok delete cluster myk8s
```

On Mac OS do, `mok machine stop`, to stop the podman machine and free up resources.

## To Uninstall mok completely

### Mac

```bash
mok machine destroy
```

If `mok` installed Homebrew, then remove homebrew and all its installed packages with:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
```

Then to completely remove any left over directories run:

```
sudo rm -rf /opt/homebrew
```

Finally, delete `mok`, with:

```bash
sudo rm /usr/local/bin/mok
```

### Linux

```bash
sudo rm /usr/local/bin/mok

# If you used git and make, then delete the git repo
rm -rf mok/
```

Then delete the podman images that were built by `mok build`.

## Known Issues

* With multiple master nodes only the first master is set up
* Currently only single node clusters can be stopped and restarted
* For Mac, if you installed Homebrew with `mok` then you should run
  `/opt/homebrew/bin/brew doctor` and follow the instructions shown there if
  you want to use Homebrew outside of Mok, or if you want to run the utilities
  that mok installed (podman for example).

## Some Features

* Podman Desktop is not required
* On Mac OS all the required packages are installed for you
* On Mac OS it uses a non-default podman machine, so won't mess up your existing podman installation
* Builds kubernetes master and worker nodes in containers
* Very simple to use without need for YAML files
* After creating the image a single node cluster builds in under 60 seconds
* For multi-node clusters the 'create cluster' command returns only when kubernetes is completely ready, with all nodes and pods up and ready.
* Can skip setting up kubernetes on the master and/or worker node (good for learning!)
  * In this case the set-up scripts are placed in `/root` in the containers and can be run by hand
  * Can do kubernetes the hard way (see [kthwic](https://github.com/my-own-kind/kubernetes-the-hard-way-in-containers))
* `mok build` and `mok create` can show extensive kubernetes logs with `--tailf`

* [Full Documentation](https://github.com/bashtools/mokctl-docs/tree/master/docs)

## Support Mok

Follow [Mok on BlueSky](https://bsky.app/profile/github-mok.bsky.social) or give Mok a star.
