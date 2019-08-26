# Google Cloud

In this tutorial, we'll create a Kubernetes v1.14.1 cluster on Google Compute Engine with Flatcar Linux.

We'll declare a Kubernetes cluster using the Lokomotive Terraform module. Then apply the changes to create a network, firewall rules, health checks, controller instances, worker managed instance group, load balancers, and TLS assets.

Controllers are provisioned to run an `etcd-member` peer and a `kubelet` service. Workers run just a `kubelet` service. A one-time [bootkube](https://github.com/kubernetes-incubator/bootkube) bootstrap schedules the `apiserver`, `scheduler`, `controller-manager`, and `coredns` on controllers and schedules `kube-proxy` and `calico` (or `flannel`) on every node. A generated `kubeconfig` provides `kubectl` access to the cluster.

## Requirements

* Google Cloud Account and Service Account
* Google Cloud DNS Zone (registered Domain Name or delegated subdomain)
* Terraform v0.11.x and [terraform-provider-ct](https://github.com/poseidon/terraform-provider-ct) installed locally

## Terraform Setup

Install [Terraform](https://www.terraform.io/downloads.html) v0.11.x on your system.

```sh
$ terraform version
Terraform v0.11.12
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

Login to your Google Console [API Manager](https://console.cloud.google.com/apis/dashboard) and select a project, or [signup](https://cloud.google.com/free/) if you don't have an account.

Select "Credentials" and create a service account key. Choose the "Compute Engine Admin" and "DNS Administrator" roles and save the JSON private key to a file that can be referenced in configs.

```sh
mv ~/Downloads/project-id-43048204.json ~/.config/google-cloud/terraform.json
```

Configure the Google Cloud provider to use your service account key, project-id, and region in a `providers.tf` file.

```tf
provider "google" {
  version = "~> 2.5.1"
  alias   = "default"

  credentials = "${file("~/.config/google-cloud/terraform.json")}"
  project     = "project-id"
  region      = "us-central1"
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

Additional configuration options are described in the `google` provider [docs](https://www.terraform.io/docs/providers/google/index.html).

!!! tip
    Regions are listed in [docs](https://cloud.google.com/compute/docs/regions-zones/regions-zones) or with `gcloud compute regions list`. A project may contain multiple clusters across different regions.

## Cluster

Define a Kubernetes cluster using the module `google-cloud/flatcar-linux/kubernetes`.

```tf
module "google-cloud-yavin" {
  source = "git::https://github.com/kinvolk/lokomotive-kubernetes//google-cloud/flatcar-linux/kubernetes?ref=<hash>"

  providers = {
    google   = "google.default"
    local    = "local.default"
    null     = "null.default"
    template = "template.default"
    tls      = "tls.default"
  }

  # Google Cloud
  cluster_name  = "yavin"
  region        = "us-central1"
  dns_zone      = "example.com"
  dns_zone_name = "example-zone"

  # configuration
  ssh_authorized_key = "ssh-rsa AAAAB3Nz..."
  asset_dir          = "/home/user/.secrets/clusters/yavin"

  # optional
  worker_count = 2
}
```

Reference the [variables docs](#variables) or the [variables.tf](https://github.com/kinvolk/lokomotive-kubernetes/blob/master/google-cloud/flatcar-linux/kubernetes/variables.tf) source.

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
Plan: 64 to add, 0 to change, 0 to destroy.
```

Apply the changes to create the cluster.

```sh
$ terraform apply
module.google-cloud-yavin.null_resource.bootkube-start: Still creating... (10s elapsed)
...

module.google-cloud-yavin.null_resource.bootkube-start: Still creating... (5m30s elapsed)
module.google-cloud-yavin.null_resource.bootkube-start: Still creating... (5m40s elapsed)
module.google-cloud-yavin.null_resource.bootkube-start: Creation complete (ID: 5768638456220583358)

Apply complete! Resources: 64 added, 0 changed, 0 destroyed.
```

In 4-8 minutes, the Kubernetes cluster will be ready.

## Verify

[Install kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) on your system. Use the generated `kubeconfig` credentials to access the Kubernetes cluster and list nodes.

```
$ export KUBECONFIG=/home/user/.secrets/clusters/yavin/auth/kubeconfig
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
```

## Going Further

Learn about [maintenance](/topics/maintenance/) and [addons](/addons/overview/).

!!! note
    On Flatcar Linux clusters, install the `CLUO` addon to coordinate reboots and drains when nodes auto-update. Otherwise, updates may not be applied until the next reboot.

## Variables

Check the [variables.tf](https://github.com/kinvolk/lokomotive-kubernetes/blob/master/google-cloud/flatcar-linux/kubernetes/variables.tf) source.

### Required

| Name | Description | Example |
|:-----|:------------|:--------|
| cluster_name | Unique cluster name (prepended to dns_zone) | "yavin" |
| region | Google Cloud region | "us-central1" |
| dns_zone | Google Cloud DNS zone | "google-cloud.example.com" |
| dns_zone_name | Google Cloud DNS zone name | "example-zone" |
| ssh_authorized_key | SSH public key for user 'core' | "ssh-rsa AAAAB3NZ..." |
| asset_dir | Path to a directory where generated assets should be placed (contains secrets) | "/home/user/.secrets/clusters/yavin" |

Check the list of valid [regions](https://cloud.google.com/compute/docs/regions-zones/regions-zones) and list Flatcar Linux [images](https://cloud.google.com/compute/docs/images) with `gcloud compute images list | grep flatcar`.

#### DNS Zone

Clusters create a DNS A record `${cluster_name}.${dns_zone}` to resolve a TCP proxy load balancer backed by controller instances. This FQDN is used by workers and `kubectl` to access the apiserver(s). In this example, the cluster's apiserver would be accessible at `yavin.google-cloud.example.com`.

You'll need a registered domain name or delegated subdomain on Google Cloud DNS. You can set this up once and create many clusters with unique names.

```tf
resource "google_dns_managed_zone" "zone-for-clusters" {
  dns_name    = "google-cloud.example.com."
  name        = "example-zone"
  description = "Production DNS zone"
}
```

!!! tip ""
    If you have an existing domain name with a zone file elsewhere, just delegate a subdomain that can be managed on Google Cloud (e.g. google-cloud.mydomain.com) and [update nameservers](https://cloud.google.com/dns/update-name-servers).

### Optional

| Name | Description | Default | Example |
|:-----|:------------|:--------|:--------|
| controller_count | Number of controllers (i.e. masters) | 1 | 3 |
| worker_count | Number of workers | 1 | 3 |
| controller_type | Machine type for controllers | "n1-standard-1" | See below |
| worker_type | Machine type for workers | "n1-standard-1" | See below |
| os_image | Flatcar Linux image for compute instances | "flatcar-stable" | "flatcar-stable-1632-3-0-v20180215" |
| disk_size | Size of the disk in GB | 40 | 100 |
| worker_preemptible | If enabled, Compute Engine will terminate workers randomly within 24 hours | false | true |
| controller_clc_snippets | Controller Flatcar Linux Config snippets | [] | [example](/advanced/customization/) |
| worker_clc_snippets | Worker Flatcar Linux Config snippets | [] | [example](/advanced/customization/) |
| networking | Choice of networking provider | "calico" | "calico" or "flannel" |
| pod_cidr | CIDR IPv4 range to assign to Kubernetes pods | "10.2.0.0/16" | "10.22.0.0/16" |
| service_cidr | CIDR IPv4 range to assign to Kubernetes services | "10.3.0.0/16" | "10.3.0.0/24" |
| cluster_domain_suffix | FQDN suffix for Kubernetes services answered by coredns. | "cluster.local" | "k8s.example.com" |

Check the list of valid [machine types](https://cloud.google.com/compute/docs/machine-types).

#### Preemption

Add `worker_preemeptible = "true"` to allow worker nodes to be [preempted](https://cloud.google.com/compute/docs/instances/preemptible) at random, but pay [significantly](https://cloud.google.com/compute/pricing) less. Clusters tolerate stopping instances fairly well (reschedules pods, but cannot drain) and preemption provides a nice reward for running fault-tolerant cluster systems.`

