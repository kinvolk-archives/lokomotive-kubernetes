resource "packet_device" "nodes" {
  count            = "${var.count}"
  hostname         = "${var.cluster_name}-${var.pool_name}-worker-${count.index}"
  plan             = "${var.type}"
  facilities       = ["${var.facility}"]
  operating_system = "flatcar_${var.os_channel}"
  billing_cycle    = "hourly"
  project_id       = "${var.project_id}"
  user_data        = "${data.ct_config.ignitions.rendered}"

  # If not present in the map, it uses ${var.reservation_ids_default}
  hardware_reservation_id = "${lookup(var.reservation_ids, format("worker-%v", count.index), var.reservation_ids_default)}"
}

resource "packet_bgp_session" "bgp" {
  count          = "${var.count}"
  device_id      = "${element(packet_device.nodes.*.id, count.index)}"
  address_family = "ipv4"
}

data "ct_config" "ignitions" {
  content  = "${data.template_file.configs.rendered}"
  platform = "packet"
}

data "template_file" "configs" {
  template = "${file("${path.module}/cl/worker.yaml.tmpl")}"

  vars {
    kubeconfig            = "${indent(10, "${var.kubeconfig}")}"
    ssh_keys              = "${jsonencode("${var.ssh_keys}")}"
    k8s_dns_service_ip    = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix = "${var.cluster_domain_suffix}"
    worker_labels         = "${var.labels}"
    taints                = "${var.taints}"
  }
}
