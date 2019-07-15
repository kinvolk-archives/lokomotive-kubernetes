module "bootkube" {
  source = "github.com/kinvolk/terraform-render-bootkube?ref=0913331140747fd464946981c1d43a895d7a630b"

  cluster_name = "${var.cluster_name}"

  # Cannot use cyclic dependencies on controllers or their DNS records
  api_servers          = ["${format("%s-private.%s", var.cluster_name, var.dns_zone)}"]
  api_servers_external = ["${format("%s.%s", var.cluster_name, var.dns_zone)}"]
  etcd_servers         = "${aws_route53_record.etcds.*.name}"
  node_names           = "${local.node_names}"
  node_count           = "${var.worker_count+var.controller_count}"
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
}
