# Self-hosted Kubernetes assets (kubeconfig, manifests)
module "bootkube" {
  source = "git::https://github.com/kinvolk/terraform-render-bootkube.git?ref=9c1ff5a9e8b3e98922980a097c49c8b3a903437a"

  cluster_name          = var.cluster_name
  api_servers           = [format("%s.%s", var.cluster_name, var.dns_zone)]
  etcd_servers          = formatlist("%s.%s", azurerm_dns_a_record.etcds.*.name, var.dns_zone)
  asset_dir             = var.asset_dir
  networking            = "flannel"
  pod_cidr              = var.pod_cidr
  service_cidr          = var.service_cidr
  cluster_domain_suffix = var.cluster_domain_suffix
  enable_reporting      = var.enable_reporting
  enable_aggregation    = var.enable_aggregation
}

