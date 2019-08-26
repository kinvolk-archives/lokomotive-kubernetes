# Discrete DNS records for each controller's private IPv4 for etcd usage
resource "aws_route53_record" "etcds" {
  count = var.controller_count

  # DNS Zone where record should be created
  zone_id = var.dns_zone_id

  name = format("%s-etcd%d.%s.", var.cluster_name, count.index, var.dns_zone)
  type = "A"
  ttl  = 300

  # private IPv4 address for etcd
  records = [element(aws_instance.controllers.*.private_ip, count.index)]
}

# Controller instances
resource "aws_instance" "controllers" {
  count = var.controller_count

  tags = {
    Name = "${var.cluster_name}-controller-${count.index}"
  }

  instance_type = var.controller_type

  ami       = local.ami_id
  user_data = element(data.ct_config.controller-ignitions.*.rendered, count.index)

  # storage
  root_block_device {
    volume_type = var.disk_type
    volume_size = var.disk_size
    iops        = var.disk_iops
  }

  # network
  associate_public_ip_address = true
  subnet_id                   = element(aws_subnet.public.*.id, count.index)
  vpc_security_group_ids      = [aws_security_group.controller.id]

  lifecycle {
    ignore_changes = [
      ami,
      user_data,
    ]
  }
}

# Controller Ignition configs
data "ct_config" "controller-ignitions" {
  count = var.controller_count
  content = element(
    data.template_file.controller-configs.*.rendered,
    count.index,
  )
  pretty_print = false
  snippets     = var.controller_clc_snippets
}

# Controller Container Linux configs
data "template_file" "controller-configs" {
  count = var.controller_count

  template = file("${path.module}/cl/controller.yaml.tmpl")

  vars = {
    # Cannot use cyclic dependencies on controllers or their DNS records
    etcd_name   = "etcd${count.index}"
    etcd_domain = "${var.cluster_name}-etcd${count.index}.${var.dns_zone}"
    # etcd0=https://cluster-etcd0.example.com,etcd1=https://cluster-etcd1.example.com,...
    etcd_initial_cluster   = join(",", data.template_file.etcds.*.rendered)
    kubeconfig             = indent(10, module.bootkube.kubeconfig-kubelet)
    ssh_authorized_key     = var.ssh_authorized_key
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
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

