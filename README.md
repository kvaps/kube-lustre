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

## Requirements

* **Kubernetes:** >=1.9.1 version
* **Servers:** Centos 7 with latest updates
* **Clients:** Centos 7 with latest updates (or installed `lustre` kernel-module)
* **Selinux**: disabled
* **Hostnames**: Each node should reach each other by single hostname
* **Fixed IPs**: Each node should have unchangeable IP-address

You need to understand that all packages will installed directly on your node.

## Limitations

* Only ZFS Backend is supported.
* Unmanaged `ldev.conf` file.
* This is just concept please don't use it on production!

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

## Usage

After installation you will have one common filesystem mounted to same mountpoint on each node.

You can use [`hostPath`](https://kubernetes.io/docs/concepts/storage/volumes/#hostpath) volumes for passthrough directories from lustre filesystem to your containers, or install special [hostpath provisioner](https://github.com/torchbox/k8s-hostpath-provisioner) for Kubernetes for automate volumes allocation process.

---

In case of ha-installation if you want to migrate lustre resources from one node to another one, you can use simple command for achieve this:
```
kubectl drain <node> --ignore-daemonsets
```
Don't forget to enable node after it will able to run resources:
```
kubectl uncordon <node>
```

## License information

* Kube-lustre is under the Apache 2.0 license. (See the [LICENSE](LICENSE) file for details)
* Lustre filesystem is under the GPL 2.0 license. (See [this page](http://lustre.org/development/) for details)
* DRBD is under the GPL 2.0 license.
