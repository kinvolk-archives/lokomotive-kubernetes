# Bare-Metal

In this tutorial, we'll network boot and provision a Kubernetes v1.14.1 cluster on bare-metal with Flatcar Linux.

First, we'll deploy a [Matchbox](https://github.com/poseidon/matchbox) service and setup a network boot environment. Then, we'll declare a Kubernetes cluster using the Lokomotive Terraform module and power on machines. On PXE boot, machines will install Flatcar Linux to disk, reboot into the disk install, and provision themselves as Kubernetes controllers or workers via Ignition.

Controllers are provisioned to run an `etcd-member` peer and a `kubelet` service. Workers run just a `kubelet` service. A one-time [bootkube](https://github.com/kubernetes-incubator/bootkube) bootstrap schedules the `apiserver`, `scheduler`, `controller-manager`, and `coredns` on controllers and schedules `kube-proxy` and `calico` (or `flannel`) on every node. A generated `kubeconfig` provides `kubectl` access to the cluster.

## Requirements

* Machines with 2GB RAM, 30GB disk, PXE-enabled NIC, IPMI
* PXE-enabled [network boot](https://coreos.com/matchbox/docs/latest/network-setup.html) environment (with HTTPS support)
* Matchbox v0.6+ deployment with API enabled
* Matchbox credentials `client.crt`, `client.key`, `ca.crt`
* Terraform v0.11.x, [terraform-provider-matchbox](https://github.com/poseidon/terraform-provider-matchbox), and [terraform-provider-ct](https://github.com/poseidon/terraform-provider-ct) installed locally

## Machines

Collect a MAC address from each machine. For machines with multiple PXE-enabled NICs, pick one of the MAC addresses. MAC addresses will be used to match machines to profiles during network boot.

* 52:54:00:a1:9c:ae (node1)
* 52:54:00:b2:2f:86 (node2)
* 52:54:00:c3:61:77 (node3)

Configure each machine to boot from the disk through IPMI or the BIOS menu.

```
ipmitool -H node1 -U USER -P PASS chassis bootdev disk options=persistent
```
 
During provisioning, you'll explicitly set the boot device to `pxe` for the next boot only. Machines will install (overwrite) the operating system to disk on PXE boot and reboot into the disk install.

!!! tip ""
    Ask your hardware vendor to provide MACs and preconfigure IPMI, if possible. With it, you can rack new servers, `terraform apply` with new info, and power on machines that network boot and provision into clusters.

## DNS

Create a DNS A (or AAAA) record for each node's default interface. Create a record that resolves to each controller node (or re-use the node record if there's one controller).

* node1.example.com (node1)
* node2.example.com (node2)
* node3.example.com (node3)
* myk8s.example.com (node1)

Cluster nodes will be configured to refer to the control plane and themselves by these fully qualified names and they'll be used in generated TLS certificates.

## Matchbox

Matchbox is an open-source app that matches network-booted bare-metal machines (based on labels like MAC, UUID, etc.) to profiles to automate cluster provisioning.

Install Matchbox on a Kubernetes cluster or dedicated server.

* Installing on [Kubernetes](https://coreos.com/matchbox/docs/latest/deployment.html#kubernetes) (recommended)
* Installing on a [server](https://coreos.com/matchbox/docs/latest/deployment.html#download)

!!! tip
    Deploy Matchbox as service that can be accessed by all of your bare-metal machines globally. This provides a single endpoint to use Terraform to manage bare-metal clusters at different sites. Lokomotive will never include secrets in provisioning user-data so you may even deploy matchbox publicly.

Matchbox provides a TLS client-authenticated API that clients, like Terraform, can use to manage machine matching and profiles. Think of it like a cloud provider API, but for creating bare-metal instances.

[Generate TLS](https://coreos.com/matchbox/docs/latest/deployment.html#generate-tls-certificates) client credentials. Save the `ca.crt`, `client.crt`, and `client.key` where they can be referenced in Terraform configs.

```sh
mv ca.crt client.crt client.key ~/.config/matchbox/
```

Verify the matchbox read-only HTTP endpoints are accessible (port is configurable).

```sh
$ curl http://matchbox.example.com:8080
matchbox
```

Verify your TLS client certificate and key can be used to access the Matchbox API (port is configurable).

```sh
$ openssl s_client -connect matchbox.example.com:8081 \
  -CAfile ~/.config/matchbox/ca.crt \
  -cert ~/.config/matchbox/client.crt \
  -key ~/.config/matchbox/client.key
```

## PXE Environment

Create an iPXE-enabled network boot environment. Configure PXE clients to chainload [iPXE](http://ipxe.org/cmd) firmware compiled to support [HTTPS downloads](https://ipxe.org/crypto). Instruct iPXE clients to chainload from your Matchbox service's `/boot.ipxe` endpoint.

For networks already supporting iPXE clients, you can add a `default.ipxe` config.

```ini
# /var/www/html/ipxe/default.ipxe
chain http://matchbox.foo:8080/boot.ipxe
```

For networks with Ubiquiti Routers, you can [configure the router](/topics/hardware/#ubiquiti) itself to chainload machines to iPXE and Matchbox.

Read about the [many ways](https://coreos.com/matchbox/docs/latest/network-setup.html) to setup a compliant iPXE-enabled network. There is quite a bit of flexibility:

* Continue using existing DHCP, TFTP, or DNS services
* Configure specific machines, subnets, or architectures to chainload from Matchbox
* Place Matchbox behind a menu entry (timeout and default to Matchbox)

!!! note ""
    TFTP chainloading to modern boot firmware, like iPXE, avoids issues with old NICs and allows faster transfer protocols like HTTP to be used.

!!! warning
    Compile iPXE from [source](https://github.com/ipxe/ipxe) with support for [HTTPS downloads](https://ipxe.org/crypto). iPXE's pre-built firmware binaries do not enable this. If you cannot enable HTTPS downloads, set `download_protocol = "http"` (discouraged).

## Terraform Setup

Install [Terraform](https://www.terraform.io/downloads.html) v0.11.x on your system.

```sh
$ terraform version
Terraform v0.11.13
```

Add the [terraform-provider-matchbox](https://github.com/poseidon/terraform-provider-matchbox) plugin binary for your system to `~/.terraform.d/plugins/`, noting the final name.

```sh
wget https://github.com/poseidon/terraform-provider-matchbox/releases/download/v0.2.3/terraform-provider-matchbox-v0.2.3-linux-amd64.tar.gz
tar xzf terraform-provider-matchbox-v0.2.3-linux-amd64.tar.gz
mv terraform-provider-matchbox-v0.2.3-linux-amd64/terraform-provider-matchbox ~/.terraform.d/plugins/terraform-provider-matchbox_v0.2.3
```

Add the [terraform-provider-ct](https://github.com/poseidon/terraform-provider-ct) plugin binary for your system to `~/.terraform.d/plugins/`, noting the final name.

```sh
wget https://github.com/poseidon/terraform-provider-ct/releases/download/v0.4.0/terraform-provider-ct-v0.4.0-linux-amd64.tar.gz
tar xzf terraform-provider-ct-v0.4.0-linux-amd64.tar.gz
mv terraform-provider-ct-v0.4.0-linux-amd64/terraform-provider-ct ~/.terraform.d/plugins/terraform-provider-ct_v0.4.0
```

Read [concepts](/architecture/concepts/) to learn about Terraform, modules, and organizing resources. Change to your infrastructure repository (e.g. `infra`).

```
cd infra/clusters
```

## Provider

Configure the Matchbox provider to use your Matchbox API endpoint and client certificate in a `providers.tf` file.

```tf
provider "matchbox" {
  version     = "0.2.3"
  endpoint    = "matchbox.example.com:8081"
  client_cert = "${file("~/.config/matchbox/client.crt")}"
  client_key  = "${file("~/.config/matchbox/client.key")}"
  ca          = "${file("~/.config/matchbox/ca.crt")}"
}

provider "ct" {
  version = "0.4.0"
}

provider "local" {
  version = "~> 1.0"
  alias = "default"
}

provider "null" {
  version = "~> 2.1.2"
  alias = "default"
}

provider "template" {
  version = "~> 1.0"
  alias = "default"
}

provider "tls" {
  version = "~> 1.0"
  alias = "default"
}
```

## Cluster

Define a Kubernetes cluster using the module `bare-metal/flatcar-linux/kubernetes`.

```tf
module "bare-metal-mercury" {
  source = "git::https://github.com/kinvolk/lokomotive-kubernetes//bare-metal/flatcar-linux/kubernetes?ref=<hash>"
  
  providers = {
    local = "local.default"
    null = "null.default"
    template = "template.default"
    tls = "tls.default"
  }
  
  # bare-metal
  cluster_name            = "mercury"
  matchbox_http_endpoint  = "http://matchbox.example.com"
  os_channel              = "flatcar-stable"
  os_version              = "1632.3.0"

  # configuration
  k8s_domain_name    = "node1.example.com"
  ssh_authorized_key = "ssh-rsa AAAAB3Nz..."
  asset_dir          = "/home/user/.secrets/clusters/mercury"

  # machines
  controller_names   = ["node1"]
  controller_macs    = ["52:54:00:a1:9c:ae"]
  controller_domains = ["node1.example.com"]
  worker_names = [
    "node2",
    "node3",
  ]
  worker_macs = [
    "52:54:00:b2:2f:86",
    "52:54:00:c3:61:77",
  ]
  worker_domains = [
    "node2.example.com",
    "node3.example.com",
  ]

  # set to http only if you cannot chainload to iPXE firmware with https support
  # download_protocol = "http"
}
```

Reference the [variables docs](#variables) or the [variables.tf](https://github.com/kinvolk/lokomotive-kubernetes/blob/master/bare-metal/flatcar-linux/kubernetes/variables.tf) source.

## ssh-agent

Initial bootstrapping requires `bootkube.service` be started on one controller node. Terraform uses `ssh-agent` to automate this step. Add your SSH private key to `ssh-agent`.

```sh
ssh-add ~/.ssh/id_rsa
ssh-add -L
```

## Apply

Initialize the config directory if this is the first use with Terraform.

```sh
terraform init
```

Plan the resources to be created.

```sh
$ terraform plan
Plan: 55 to add, 0 to change, 0 to destroy.
```

Apply the changes. Terraform will generate bootkube assets to `asset_dir` and create Matchbox profiles (e.g. controller, worker) and matching rules via the Matchbox API.

```sh
$ terraform apply
module.bare-metal-mercury.null_resource.copy-kubeconfig.0: Provisioning with 'file'...
module.bare-metal-mercury.null_resource.copy-etcd-secrets.0: Provisioning with 'file'...
module.bare-metal-mercury.null_resource.copy-kubeconfig.0: Still creating... (10s elapsed)
module.bare-metal-mercury.null_resource.copy-etcd-secrets.0: Still creating... (10s elapsed)
...
```

Apply will then loop until it can successfully copy credentials to each machine and start the one-time Kubernetes bootstrap service. Proceed to the next step while this loops.

### Power

Power on each machine with the boot device set to `pxe` for the next boot only.

```sh
ipmitool -H node1.example.com -U USER -P PASS chassis bootdev pxe
ipmitool -H node1.example.com -U USER -P PASS power on
```

Machines will network boot, install Flatcar Linux to disk, reboot into the disk install, and provision themselves as controllers or workers.

!!! tip ""
    If this is the first test of your PXE-enabled network boot environment, watch the SOL console of a machine to spot any misconfigurations.

### Bootstrap

Wait for the `bootkube-start` step to finish bootstrapping the Kubernetes control plane. This may take 5-15 minutes depending on your network.

```
module.bare-metal-mercury.null_resource.bootkube-start: Still creating... (6m10s elapsed)
module.bare-metal-mercury.null_resource.bootkube-start: Still creating... (6m20s elapsed)
module.bare-metal-mercury.null_resource.bootkube-start: Still creating... (6m30s elapsed)
module.bare-metal-mercury.null_resource.bootkube-start: Still creating... (6m40s elapsed)
module.bare-metal-mercury.null_resource.bootkube-start: Creation complete (ID: 5441741360626669024)

Apply complete! Resources: 55 added, 0 changed, 0 destroyed.
```

To watch the install to disk (until machines reboot from disk), SSH to port 2222.

```
# before v1.14.1
$ ssh debug@node1.example.com
# after v1.14.1
$ ssh -p 2222 core@node1.example.com
```

To watch the bootstrap process in detail, SSH to the first controller and journal the logs.

```
$ ssh core@node1.example.com
$ journalctl -f -u bootkube
bootkube[5]:         Pod Status:        pod-checkpointer        Running
bootkube[5]:         Pod Status:          kube-apiserver        Running
bootkube[5]:         Pod Status:          kube-scheduler        Running
bootkube[5]:         Pod Status: kube-controller-manager        Running
bootkube[5]: All self-hosted control plane components successfully started
bootkube[5]: Tearing down temporary bootstrap control plane...
```

## Verify

[Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) on your system. Use the generated `kubeconfig` credentials to access the Kubernetes cluster and list nodes.

```
$ export KUBECONFIG=/home/user/.secrets/clusters/mercury/auth/kubeconfig
$ kubectl get nodes
NAME                STATUS  ROLES              AGE  VERSION
node1.example.com   Ready   controller,master  10m  v1.14.1
node2.example.com   Ready   node               10m  v1.14.1
node3.example.com   Ready   node               10m  v1.14.1
```

List the pods.

```
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                       READY     STATUS    RESTARTS   AGE
kube-system   calico-node-6qp7f                          2/2       Running   1          11m
kube-system   calico-node-gnjrm                          2/2       Running   0          11m
kube-system   calico-node-llbgt                          2/2       Running   0          11m
kube-system   coredns-1187388186-dj3pd                   1/1       Running   0          11m
kube-system   coredns-1187388186-mx9rt                   1/1       Running   0          11m
kube-system   kube-apiserver-7336w                       1/1       Running   0          11m
kube-system   kube-controller-manager-3271970485-b9chx   1/1       Running   0          11m
kube-system   kube-controller-manager-3271970485-v30js   1/1       Running   1          11m
kube-system   kube-proxy-50sd4                           1/1       Running   0          11m
kube-system   kube-proxy-bczhp                           1/1       Running   0          11m
kube-system   kube-proxy-mp2fw                           1/1       Running   0          11m
kube-system   kube-scheduler-3895335239-fd3l7            1/1       Running   1          11m
kube-system   kube-scheduler-3895335239-hfjv0            1/1       Running   0          11m
kube-system   pod-checkpointer-wf65d                     1/1       Running   0          11m
kube-system   pod-checkpointer-wf65d-node1.example.com   1/1       Running   0          11m
```

## Going Further

Learn about [maintenance](/topics/maintenance/).

## Variables

Check the [variables.tf](https://github.com/kinvolk/lokomotive-kubernetes/blob/master/bare-metal/flatcar-linux/kubernetes/variables.tf) source.

### Required

| Name | Description | Example |
|:-----|:------------|:--------|
| cluster_name | Unique cluster name | mercury |
| matchbox_http_endpoint | Matchbox HTTP read-only endpoint | http://matchbox.example.com:port |
| os_channel | Channel for Flatcar Linux | flatcar-stable, flatcar-beta, flatcar-alpha |
| os_version | Version of Flatcar Linux to PXE and install | 1632.3.0 |
| k8s_domain_name | FQDN resolving to the controller(s) nodes. Workers and kubectl will communicate with this endpoint | "myk8s.example.com" |
| ssh_authorized_key | SSH public key for user 'core' | "ssh-rsa AAAAB3Nz..." |
| asset_dir | Path to a directory where generated assets should be placed (contains secrets) | "/home/user/.secrets/clusters/mercury" |
| controller_names | Ordered list of controller short names | ["node1"] |
| controller_macs | Ordered list of controller identifying MAC addresses | ["52:54:00:a1:9c:ae"] |
| controller_domains | Ordered list of controller FQDNs | ["node1.example.com"] |
| worker_names | Ordered list of worker short names | ["node2", "node3"] |
| worker_macs | Ordered list of worker identifying MAC addresses | ["52:54:00:b2:2f:86", "52:54:00:c3:61:77"] |
| worker_domains | Ordered list of worker FQDNs | ["node2.example.com", "node3.example.com"] |

### Optional

| Name | Description | Default | Example |
|:-----|:------------|:--------|:--------|
| download_protocol | Protocol iPXE uses to download the kernel and initrd. iPXE must be compiled with [crypto](https://ipxe.org/crypto) support for https. Unused if cached_install is true | "https" | "http" |
| cached_install | PXE boot and install from the Matchbox `/assets` cache. Admin MUST have downloaded Flatcar Linux or Flatcar images into the cache | false | true |
| install_disk | Disk device where Flatcar Linux should be installed | "/dev/sda" | "/dev/sdb" |
| networking | Choice of networking provider | "calico" | "calico" or "flannel" |
| network_mtu | CNI interface MTU (calico-only) | 1480 | - | 
| clc_snippets | Map from machine names to lists of Container Linux Config snippets | {} | [example](/advanced/customization/#usage) |
| network_ip_autodetection_method | Method to detect host IPv4 address (calico-only) | first-found | can-reach=10.0.0.1 |
| pod_cidr | CIDR IPv4 range to assign to Kubernetes pods | "10.2.0.0/16" | "10.22.0.0/16" |
| service_cidr | CIDR IPv4 range to assign to Kubernetes services | "10.3.0.0/16" | "10.3.0.0/24" |
| cluster_domain_suffix | FQDN suffix for Kubernetes services answered by coredns. | "cluster.local" | "k8s.example.com" |
| kernel_args | Additional kernel args to provide at PXE boot | [] | "kvm-intel.nested=1" |

