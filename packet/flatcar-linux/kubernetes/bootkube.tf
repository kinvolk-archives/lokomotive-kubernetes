module "bootkube" {
  source = "github.com/kinvolk/terraform-render-bootkube?ref=d07243a9e7f6084cfe08b708731a79c26146badb"

  cluster_name = "${var.cluster_name}"

  # Cannot use cyclic dependencies on controllers or their DNS records
  api_servers          = ["${format("%s-private.%s", var.cluster_name, var.dns_zone)}"]
  api_servers_external = ["${format("%s.%s", var.cluster_name, var.dns_zone)}"]
  etcd_servers         = "${aws_route53_record.etcds.*.name}"
  asset_dir            = "${var.asset_dir}"
  networking           = "${var.networking}"
  network_mtu          = "${var.network_mtu}"

  # Select private Packet NIC by using the can-reach Calico autodetection option with the first
  # host in our private CIDR.
  network_ip_autodetection_method = "can-reach=${cidrhost(var.node_private_cidr, 1)}"

  pod_cidr              = "${var.pod_cidr}"
  service_cidr          = "${var.service_cidr}"
  cluster_domain_suffix = "${var.cluster_domain_suffix}"
  enable_reporting      = "${var.enable_reporting}"
  enable_aggregation    = "${var.enable_aggregation}"

  container_images = {
    calico           = "quay.io/calico/node:v3.7.3"
    calico_cni       = "quay.io/calico/cni:v3.7.3"
    flannel          = "quay.io/coreos/flannel:v0.11.0-amd64"
    flannel_cni      = "quay.io/coreos/flannel-cni:v0.3.0"
    kube_router      = "cloudnativelabs/kube-router:v0.3.1"
    hyperkube        = "k8s.gcr.io/hyperkube:${var.kube_version}"
    coredns          = "k8s.gcr.io/coredns:1.5.0"
    pod_checkpointer = "quay.io/coreos/pod-checkpointer:83e25e5968391b9eb342042c435d1b3eeddb2be1"
  }
}
