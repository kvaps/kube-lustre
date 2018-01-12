# Kube-Lustre

![](lustre-logo.png)

High-available Lustre filesystem concept with DRBD for Kubernetes.

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
[kvaps/lustre-client]: https://hub.docker.com/r/kvaps/lustre-client/builds/
[kvaps/lustre-install]: https://hub.docker.com/r/kvaps/lustre-install/builds/
[kvaps/drbd]: https://hub.docker.com/r/kvaps/drbd/builds/
[kvaps/drbd-install]: https://hub.docker.com/r/kvaps/drbd-install/builds/

## Concept

All project represents a few simple docker-images with shell-scripts, each one do some does its specific task.

Since lustre zfs and drbd work at the kernel level, which little bit does not fit into the docker's ideology, almost all actions executes directly on the host machine.
Docker and Kubernetes used here only as orchestration-system and ha-management framework.

What each image does?

| Image                         | Role                                                                                      |
|-------------------------------|-------------------------------------------------------------------------------------------|
| **kube-lustre-configurator**  | Reads [config], then generates templates and assign resources to specific Kubernetes nodes |
| **lustre**                    | Makes lustre target, then imports zpool and mounts lustre target                          |
| **lustre-client**             | Mounts lustre filesystem                                                                  |
| **lustre-install**            | Installs lustre and zfs packages and dkms modules                                         |
| **drbd**                      | Makes and runs drbd resource                                                              |
| **drbd-install**              | Installs drbd packages and dkms modules                                                   |


[config]: https://github.com/kvaps/kube-lustre/blob/master/yaml/kube-lustre-config.yaml

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
