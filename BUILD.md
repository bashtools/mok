Update versions in:
- `Makefile`
  - `VERSION = 0.8.21`
- `README.md`
  - `Current kubernetes version: 1.x.x`
- `src/globals.sh`
  - `declare -rg MOKVERSION="0.8.x"`
+ - `declare -rg K8SVERSION="1.x.x"`

Check versions in:
- https://github.com/cri-o/cri-o/tags
- https://github.com/opencontainers/runc/tags
- https://github.com/kubernetes-sigs/cri-tools/tags

and update `mok-image/Dockerfile`

For kubernetes MINOR version upgrades, update:
- `src/createcluster.sh`
  - `_CC_set_up_master_node()`
    - `"1.31."* | "1.32."*)`
  - `_CC_set_up_worker_node()`
    - `"1.31."* | "1.32."*)`

Remove all images:
```
sudo podman images | tail -n +2 | awk '{ print $3 }' | xargs sudo podman rmi --force
```
Update mok
```
touch mok-image/Dockerfile
sudo make install
make package
```
Build prebuilt image for upload and check version as it's building:
```
mok build image --tailf
```
Tag and upload:
```
sudo podman tag localhost/local/mok-image:1.32.0 docker.io/myownkind/mok-image:1.32.0
sudo podman login docker.io
sudo podman push docker.io/myownkind/mok-image:1.32.0
```
