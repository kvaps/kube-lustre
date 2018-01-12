# kube-lustre

Lustre Filesystem for Kubernetes

## Build Status

| Image                                 | Build Status                                                                 |
|---------------------------------------|------------------------------------------------------------------------------|
| **[kvaps/kube-lustre-configurator]**  | ![](https://img.shields.io/docker/build/kvaps/kube-lustre-configurator.svg)  |
| **[kvaps/lustre]**                    | ![](https://img.shields.io/docker/build/kvaps/lustre.svg)                    |
| **[kvaps/lustre-client]**             | ![](https://img.shields.io/docker/build/kvaps/lustre-client.svg)             |
| **[kvaps/lustre-install]**            | ![](https://img.shields.io/docker/build/kvaps/lustre-install.svg)            |
| **[kvaps/drbd]**                      | ![](https://img.shields.io/docker/build/kvaps/drbd.svg)                      |
| **[kvaps/drbd-install]**              | ![](https://img.shields.io/docker/build/kvaps/drbd-install.svg)              |

[kvaps/kube-lustre-configurator]: https://hub.docker.com/r/kvaps/kube-lustre-configurator/builds/
[kvaps/lustre]: https://hub.docker.com/r/kvaps/kvaps/lustre/builds/
[kvaps/lustre-client]: https://hub.docker.com/r/kvaps/kvaps/lustre-client/builds/
[kvaps/lustre-install]: https://hub.docker.com/r/kvaps/lustre-install/builds/
[kvaps/drbd]: https://hub.docker.com/r/kvaps/drbd/builds/
[kvaps/drbd-install]: https://hub.docker.com/r/kvaps/drbd-install/builds/

## Quick Start

* Create namespace, and clusterrolebinding:
```sh
kubectl create namespace lustre
kubectl create clusterrolebinding --user system:serviceaccount:lustre:default lustre-cluster-admin --clusterrole cluster-admin
```

* Download and edit config:
```sh
curl -O https://raw.githubusercontent.com/kvaps/kube-lustre/master/yaml/kube-lustre-config.yaml
vim kube-lustre-config.yaml
```

* Apply your config:
```sh
kubectl apply -f kube-lustre-config.yaml
```

* Create job for label nodes and run daemons according your configuration:
```sh
kubectl create -f https://raw.githubusercontent.com/kvaps/kube-lustre/master/yaml/kube-lustre-configurator.yaml
```
