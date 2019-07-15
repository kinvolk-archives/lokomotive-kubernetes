resource "null_resource" "worker" {
  count = "${var.count}"

  triggers {
    hostname = "${var.cluster_name}-${var.pool_name}-worker-${count.index}"
  }
}

resource "packet_device" "nodes" {
  count            = "${var.count}"
  hostname         = "${element(null_resource.worker.*.triggers.hostname, count.index)}"
  plan             = "${var.type}"
  facilities       = ["${var.facility}"]
  operating_system = "custom_ipxe"
  billing_cycle    = "hourly"
  project_id       = "${var.project_id}"
  ipxe_script_url  = "${var.ipxe_script_url}"
  always_pxe       = "false"
  user_data        = "${element(data.ct_config.install-ignitions.*.rendered, count.index)}"

  # If not present in the map, it uses ${var.reservation_ids_default}
  hardware_reservation_id = "${lookup(var.reservation_ids, format("worker-%v", count.index), var.reservation_ids_default)}"
}

# These configs are used for the fist boot, to run flatcar-install
data "ct_config" "install-ignitions" {
  count   = "${var.count}"
  content = "${element(data.template_file.install.*.rendered, count.index)}"
}

data "template_file" "install" {
  count    = "${var.count}"
  template = "${file("${path.module}/cl/install.yaml.tmpl")}"

  vars {
    os_channel           = "${var.os_channel}"
    os_version           = "${var.os_version}"
    flatcar_linux_oem    = "packet"
    ssh_keys             = "${jsonencode("${var.ssh_keys}")}"
    postinstall_ignition = "${element(data.ct_config.ignitions.*.rendered, count.index)}"
    setup_raid           = "${var.setup_raid}"
  }
}

resource "packet_bgp_session" "bgp" {
  count          = "${var.count}"
  device_id      = "${element(packet_device.nodes.*.id, count.index)}"
  address_family = "ipv4"
}

data "ct_config" "ignitions" {
  count    = "${var.count}"
  content  = "${element(data.template_file.configs.*.rendered,count.index)}"
  platform = "packet"
}

data "template_file" "configs" {
  count    = "${var.count}"
  template = "${file("${path.module}/cl/worker.yaml.tmpl")}"

  vars {
    kubeconfig            = "${indent(10, "${lookup(var.kubeconfig, element(null_resource.worker.*.triggers.hostname, count.index))}")}"
    ssh_keys              = "${jsonencode("${var.ssh_keys}")}"
    k8s_dns_service_ip    = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix = "${var.cluster_domain_suffix}"
    worker_labels         = "${var.labels}"
    taints                = "${var.taints}"
  }
}
