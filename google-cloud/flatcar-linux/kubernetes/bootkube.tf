# Self-hosted Kubernetes assets (kubeconfig, manifests)
module "bootkube" {
  source = "github.com/kinvolk/terraform-render-bootkube?ref=58f8ed8d79b4f095f2bea185dcdb81843719f8ad"

  cluster_name          = "${var.cluster_name}"
  api_servers           = ["${format("%s.%s", var.cluster_name, var.dns_zone)}"]
  etcd_servers          = ["${google_dns_record_set.etcds.*.name}"]
  asset_dir             = "${var.asset_dir}"
  networking            = "${var.networking}"
  network_mtu           = 1440
  pod_cidr              = "${var.pod_cidr}"
  service_cidr          = "${var.service_cidr}"
  cluster_domain_suffix = "${var.cluster_domain_suffix}"
  enable_reporting      = "${var.enable_reporting}"
  enable_aggregation    = "${var.enable_aggregation}"

  // temporary
  external_apiserver_port = 443

  certs_validity_period_hours = "${var.certs_validity_period_hours}"
}
