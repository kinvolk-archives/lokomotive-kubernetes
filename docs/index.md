# Lokomotive

Lokomotive is an open source Kubernetes distribution by [Kinvolk](https://kinvolk.io/).

* Minimal, stable base Kubernetes distribution
* Declarative infrastructure and configuration
* [Free](#social-contract) (freedom and cost) and privacy-respecting
* Practical for labs, datacenters, and clouds

Lokomotive distributes upstream Kubernetes.

## Features

* Kubernetes v1.17.2 (upstream, via [kubernetes-incubator/bootkube](https://github.com/kubernetes-incubator/bootkube))
* Single or multi-master, [Calico](https://www.projectcalico.org/) or [flannel](https://github.com/coreos/flannel) networking
* On-cluster etcd with TLS, [RBAC](https://kubernetes.io/docs/admin/authorization/rbac/)-enabled, [network policy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
* Advanced features like [worker pools](advanced/worker-pools/) and [snippets](advanced/customization/#flatcar-linux) customization

## Modules

Lokomotive provides a Terraform Module for each supported operating system and platform. Flatcar Container Linux is a mature and reliable choice.

| Platform      | Operating System | Terraform Module | Status |
|---------------|------------------|------------------|--------|
| AWS           | Flatcar Container Linux | [aws/flatcar-linux/kubernetes](flatcar-linux/aws.md) | stable |
| Azure         | Flatcar Container Linux | [azure/flatcar-linux/kubernetes](flatcar-linux/azure.md) | alpha |
| Bare-Metal    | Flatcar Container Linux | [bare-metal/flatcar-linux/kubernetes](flatcar-linux/bare-metal.md) | stable |
| Packet        | Flatcar Container Linux | [packet/flatcar-linux/kubernetes](flatcar-linux/packet.md) | stable |

## Documentation

* Architecture [concepts](architecture/concepts.md) and [operating-systems](architecture/operating-systems.md)
* Tutorials for [AWS](flatcar-linux/aws.md), [Azure](flatcar-linux/azure.md), [Bare-Metal](flatcar-linux/bare-metal.md) and [Packet](flatcar-linux/packet.md)

## Example

Define a Kubernetes cluster by using the Terraform module for your chosen platform and operating system. Here's a minimal example.

```tf
module "google-cloud-yavin" {
  source = "git::https://github.com/kinvolk/lokomotive//google-cloud/flatcar-linux/kubernetes?ref=<hash>"

  providers = {
    google   = google.default
    local    = local.default
    null     = null.default
    template = template.default
    tls      = tls.default
  }

  # Google Cloud
  cluster_name  = "yavin"
  region        = "us-central1"
  dns_zone      = "example.com"
  dns_zone_name = "example-zone"

  # configuration
  ssh_keys = [
    "ssh-rsa AAAAB3Nz...",
    "ssh-rsa AAAAB3Nz...",
  ]

  asset_dir = "./assets"

  # optional
  worker_count = 2
}
```

Initialize modules, plan the changes to be made, and apply the changes.

```sh
$ terraform init
$ terraform plan
Plan: 64 to add, 0 to change, 0 to destroy.
$ terraform apply
Apply complete! Resources: 64 added, 0 changed, 0 destroyed.
```

In 4-8 minutes (varies by platform), the cluster will be ready. This Google Cloud example creates a `yavin.example.com` DNS record to resolve to a network load balancer across controller nodes.

```
$ export KUBECONFIG=$PWD/assets/auth/kubeconfig
$ kubectl get nodes
NAME                                       ROLES              STATUS  AGE  VERSION
yavin-controller-0.c.example-com.internal  controller,master  Ready   6m   v1.14.1
yavin-worker-jrbf.c.example-com.internal   node               Ready   5m   v1.14.1
yavin-worker-mzdm.c.example-com.internal   node               Ready   5m   v1.14.1
```

List the pods.

```
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                      READY  STATUS    RESTARTS  AGE
kube-system   calico-node-1cs8z                         2/2    Running   0         6m
kube-system   calico-node-d1l5b                         2/2    Running   0         6m
kube-system   calico-node-sp9ps                         2/2    Running   0         6m
kube-system   coredns-1187388186-dkh3o                  1/1    Running   0         6m
kube-system   coredns-1187388186-zj5dl                  1/1    Running   0         6m
kube-system   kube-apiserver-zppls                      1/1    Running   0         6m
kube-system   kube-controller-manager-3271970485-gh9kt  1/1    Running   0         6m
kube-system   kube-controller-manager-3271970485-h90v8  1/1    Running   1         6m
kube-system   kube-proxy-117v6                          1/1    Running   0         6m
kube-system   kube-proxy-9886n                          1/1    Running   0         6m
kube-system   kube-proxy-njn47                          1/1    Running   0         6m
kube-system   kube-scheduler-3895335239-5x87r           1/1    Running   0         6m
kube-system   kube-scheduler-3895335239-bzrrt           1/1    Running   1         6m
kube-system   pod-checkpointer-l6lrt                    1/1    Running   0         6m
kube-system   pod-checkpointer-l6lrt-controller-0       1/1    Running   0         6m
```

## Help

Ask questions on the IRC #lokomotive-k8s channel on [freenode.net](http://freenode.net/).

## Motivation

Lokomotive powers the author's cloud and colocation clusters. The project has evolved through operational experience and Kubernetes changes. Lokomotive is shared under a free license to allow others to use the work freely and contribute to its upkeep.

Lokomotive addresses real world needs, which you may share. It is honest about limitations or areas that aren't mature yet. It avoids buzzword bingo and hype. It does not aim to be the one-solution-fits-all distro. An ecosystem of Kubernetes distributions is healthy.

## Social Contract

Lokomotive clusters will contain only [free](https://www.debian.org/intro/free) components. Cluster components will not collect data on users without their permission.
