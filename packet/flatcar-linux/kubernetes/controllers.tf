# Discrete DNS records for each controller's private IPv4 for etcd usage
resource "aws_route53_record" "etcds" {
  count = var.controller_count

  # DNS Zone where record should be created
  zone_id = var.dns_zone_id

  name = format("%s-etcd%d.%s.", var.cluster_name, count.index, var.dns_zone)
  type = "A"
  ttl  = 300

  # private IPv4 address for etcd
  records = [packet_device.controllers[count.index].access_private_ipv4]
}

# DNS record for the API servers
resource "aws_route53_record" "apiservers" {
  zone_id = var.dns_zone_id

  name = format("%s.%s.", var.cluster_name, var.dns_zone)
  type = "A"
  ttl  = "300"

  # TODO - verify that a multi-controller setup actually works
  records = packet_device.controllers.*.access_public_ipv4
}

resource "aws_route53_record" "apiservers_private" {
  zone_id = var.dns_zone_id

  name = format("%s-private.%s.", var.cluster_name, var.dns_zone)
  type = "A"
  ttl  = "300"

  # TODO - verify that a multi-controller setup actually works
  records = packet_device.controllers.*.access_private_ipv4
}

resource "packet_device" "controllers" {
  count            = var.controller_count
  hostname         = "${var.cluster_name}-controller-${count.index}"
  plan             = var.controller_type
  facilities       = [var.facility]
  operating_system = "custom_ipxe"
  billing_cycle    = "hourly"
  project_id       = var.project_id
  ipxe_script_url  = var.ipxe_script_url
  always_pxe       = "false"
  user_data = data.ct_config.controller-install-ignitions[count.index].rendered
}

data "ct_config" "controller-install-ignitions" {
  count = var.controller_count
  content = data.template_file.controller-install[count.index].rendered
}

data "template_file" "controller-install" {
  count    = var.controller_count
  template = file("${path.module}/cl/controller-install.yaml.tmpl")

  vars = {
    os_channel           = var.os_channel
    os_version           = var.os_version
    flatcar_linux_oem    = "packet"
    ssh_keys             = jsonencode(var.ssh_keys)
    postinstall_ignition = data.ct_config.controller-ignitions[count.index].rendered
  }
}

data "ct_config" "controller-ignitions" {
  count    = var.controller_count
  platform = "packet"
  content = data.template_file.controller-configs[count.index].rendered
}

data "template_file" "controller-configs" {
  count    = var.controller_count
  template = file("${path.module}/cl/controller.yaml.tmpl")

  vars = {
    # Cannot use cyclic dependencies on controllers or their DNS records
    etcd_name   = "etcd${count.index}"
    etcd_domain = "${var.cluster_name}-etcd${count.index}.${var.dns_zone}"
    # etcd0=https://cluster-etcd0.example.com,etcd1=https://cluster-etcd1.example.com,...
    etcd_initial_cluster  = join(",", data.template_file.etcds.*.rendered)
    kubeconfig            = indent(10, module.bootkube.kubeconfig-kubelet)
    ssh_keys              = jsonencode(var.ssh_keys)
    k8s_dns_service_ip    = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix = var.cluster_domain_suffix
  }
}

data "template_file" "etcds" {
  count    = var.controller_count
  template = "etcd$${index}=https://$${cluster_name}-etcd$${index}.$${dns_zone}:2380"

  vars = {
    index        = count.index
    cluster_name = var.cluster_name
    dns_zone     = var.dns_zone
  }
}

