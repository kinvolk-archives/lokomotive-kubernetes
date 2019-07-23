output "worker_nodes_hostname" {
  value = "${packet_device.nodes.*.hostname}"
}

output "worker_nodes_public_ipv4" {
  value = "${packet_device.nodes.*.access_public_ipv4}"
}

output "pool_name" {
  value = "${var.pool_name}"
}

output "user_data" {
  value = "${data.ct_config.ignitions.rendered}"
}

output "type" {
  value = "${var.type}"
}

output "os_channel" {
  value = "${var.os_channel}"
}
