# MOK - Run Kubernetes on your laptop

![image](https://github.com/user-attachments/assets/0750910e-d6da-4c65-92ea-f7bc64b116cc)


Current kubernetes version: 1.32.0

## Requirements

**MacOS on Apple Silicon (M1, M2, ...)**
* Podman
* 5 GB of free disk space

**Fedora 41 Desktop/Server on x86_64 or AMD64**
* Podman
* 5 GB of free disk space

Mok may work on other versions of Linux or MacOS but I have only tested it on the above.

## Install

Podman is required. On Mac, install [Homebrew](https://brew.sh/) then type `brew install podman`.
Podman Desktop is not required.

### Installation for Mac Silicon (M1, M2, ...)

Download `mok` to your home directory using curl:

```bash
cd ~
curl -O https://raw.githubusercontent.com/bashtools/mok/refs/heads/master/package/mok
```

Create a podman machine with the right settings: 

```bash
podman machine init --now --rootful --user-mode-networking mok-machine
podman machine ssh --username root mok-machine modprobe nf_conntrack
podman machine ssh --username root mok-machine sysctl -w net.netfilter.nf_conntrack_max=163840
```

Move `mok` into the podman machine and delete the `mok` that was previously downloaded:

```bash
cat ~/mok | podman machine ssh --username root mok-machine "cat >/usr/local/bin/mok; chmod +x /usr/local/bin/mok"
rm ~/mok
```

### Installation for Linux

Use `curl` to download and move `mok` to `/usr/local/bin`:

```bash
curl -O https://raw.githubusercontent.com/bashtools/mok/refs/heads/master/package/mok
chmod +x mok
sudo mv mok /usr/local/bin/
```

## Using Mok

### Add an alias

For Mac users:

```bash
alias mok="podman machine ssh --username root mok-machine env TERM=$TERM mok"
```

<<<<<<< HEAD
### First use

For linux users: `alias mok="sudo /usr/local/bin/mok"`

Build the latest image:

```bash
mok build image
=======
For Linux users:

```bash
alias mok="sudo /usr/local/bin/mok"
>>>>>>> a0e801d (Fixing mok for mac)
```

Note: Add the alias to your shell startup file to make it persistent
(For example: mac/zsh users can append that line to `~/.zshrc`).

### Build a container image

```bash
mok build image
```

Prebuilt images don't work with Mac yet, so don't try that if you're on Mac OS.

### Create a single node kuberenetes cluster

```bash
mok create cluster myk8s --masters 1 --publish
```

For Mac users `--publish` must be used - but it's optional for Linux users:

### Run some kubectl commands

Naturally, the [`kubectl`](https://kubernetes.io/docs/tasks/tools/) command is needed for this.

Mac users only:
```bash
podman machine ssh mok-machine cat /var/tmp/admin-myk8s.conf | sed 's#server:.*#server: https://127.0.0.1:6443#' >/var/tmp/admin-myk8s.conf
```

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
mok build -h
# ... etc ...
```

### Delete the cluster

```bash
mok delete cluster myk8s
```

### Uninstall mok completely

#### Mac

```bash
podman machine rm mok-machine
```

#### Linux

```bash
sudo rm /usr/local/bin/mok

# If you used git and make delete the git repo
rm -rf mok/
```

Then delete the podman images that were built by `mok build`.

## Known Issues

* With multiple master nodes only the first master is set up
* Currently only single node clusters can be stopped and restarted
* For Mac, the instructions on this page show one way to run `mok` but colorised
  output is missing, and `mok exec` does not work optimally. If your Mac is set
  up with Gnu tools then you can run `mok` without copying it to the podman
  machine.

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

## Support Mok

Follow [Mok on BlueSky](https://bsky.app/profile/github-mok.bsky.social) or give Mok a star.
