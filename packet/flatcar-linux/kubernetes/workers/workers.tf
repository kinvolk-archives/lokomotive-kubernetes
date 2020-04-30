resource "packet_device" "nodes" {
  count            = var.worker_count
  hostname         = "${var.cluster_name}-${var.pool_name}-worker-${count.index}"
  plan             = var.type
  facilities       = [var.facility]
  operating_system = var.ipxe_script_url != "" ? "custom_ipxe" : format("flatcar_%s", var.os_channel)
  billing_cycle    = "hourly"
  project_id       = var.project_id
  ipxe_script_url  = var.ipxe_script_url
  always_pxe       = false
  user_data        = var.ipxe_script_url != "" ? data.ct_config.install-ignitions.rendered : data.ct_config.ignitions.rendered

  # If not present in the map, it uses ${var.reservation_ids_default}.
  hardware_reservation_id = lookup(
    var.reservation_ids,
    format("worker-%v", count.index),
    var.reservation_ids_default,
  )

  tags = var.tags
}

data "ct_config" "install-ignitions" {
  content = data.template_file.install.rendered
}

# These configs are used for the fist boot, to run flatcar-install
data "template_file" "install" {
  template = file("${path.module}/cl/install.yaml.tmpl")

  vars = {
    os_channel           = var.os_channel
    os_version           = var.os_version
    os_arch              = var.os_arch
    flatcar_linux_oem    = "packet"
    ssh_keys             = jsonencode(var.ssh_keys)
    postinstall_ignition = data.ct_config.ignitions.rendered
  }
}

resource "packet_bgp_session" "bgp" {
  count          = var.disable_bgp == true ? 0 : var.worker_count
  device_id      = packet_device.nodes[count.index].id
  address_family = "ipv4"
}

# BGP node labels.
locals {
  my_asn = format("metallb.universe.tf/my-asn=%d", data.packet_project.project.bgp_config.0.asn)
  # Packet always uses ASN 65530 as the remote ASN for local BGP.
  peer_asn = format("metallb.universe.tf/peer-asn=%d", 65530)
}

data "ct_config" "ignitions" {
  content = templatefile(
    "${path.module}/cl/worker.yaml.tmpl",
    {
      os_arch               = var.os_arch
      kubeconfig            = indent(10, var.kubeconfig)
      ssh_keys              = jsonencode(var.ssh_keys)
      k8s_dns_service_ip    = cidrhost(var.service_cidr, 10)
      cluster_domain_suffix = var.cluster_domain_suffix
      node_labels           = var.labels
      bgp_node_labels       = var.disable_bgp ? "" : format("%s,%s", local.my_asn, local.peer_asn)
      taints                = var.taints
      setup_raid            = var.setup_raid
      setup_raid_hdd        = var.setup_raid_hdd
      setup_raid_ssd        = var.setup_raid_ssd
      setup_raid_ssd_fs     = var.setup_raid_ssd_fs
      use_ccm               = var.use_ccm
    }
  )
  platform = "packet"
  snippets = var.clc_snippets
}

data "packet_project" "project" {
  project_id = var.project_id
}
