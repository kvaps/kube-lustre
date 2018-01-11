# kube-lustre

Lustre Filesystem for Kubernetes

### Build Status

| Image                             | Build Status                                                                 |
|-----------------------------------|------------------------------------------------------------------------------|
| **[kvaps/kube-lustre-configurator]**  | ![](https://img.shields.io/docker/build/kvaps/kube-lustre-configurator.svg)  |
| **[kvaps/lustre]**                    | ![](https://img.shields.io/docker/build/kvaps/lustre.svg)                    |
| **[kvaps/lustre-install]**            | ![](https://img.shields.io/docker/build/kvaps/lustre-install.svg)            |
| **[kvaps/drbd]**                      | ![](https://img.shields.io/docker/build/kvaps/drbd.svg)                      |
| **[kvaps/drbd-install]**              | ![](https://img.shields.io/docker/build/kvaps/drbd-install.svg)              |

[kvaps/kube-lustre-configurator]: https://hub.docker.com/r/kvaps/kube-lustre-configurator/builds/
[kvaps/lustre]: https://hub.docker.com/r/kvaps/kvaps/lustre/builds/
[kvaps/lustre-install]: https://hub.docker.com/r/kvaps/lustre-install/builds/
[kvaps/drbd]: https://hub.docker.com/r/kvaps/drbd/builds/
[kvaps/drbd-install]: https://hub.docker.com/r/kvaps/drbd-install/builds/

### How to start

```sh
# create namespace, and clusterrolebinding
kubectl create namespace lustre
kubectl create clusterrolebinding --user system:serviceaccount:lustre:default lustre-cluster-admin --clusterrole cluster-admin
# download and edit your config
curl -O https://raw.githubusercontent.com/kvaps/kube-lustre/master/yaml/kube-lustre-config.yaml
vim kube-lustre-config.yaml
# apply your configuration
kubectl apply -f kube-lustre-config.yaml
# create job for label nodes and run daemons according your configuration
kubectl create -f https://raw.githubusercontent.com/kvaps/kube-lustre/master/yaml/kube-lustre-configurator.yaml
```
