output "worker_nodes_hostname" {
  value = "${null_resource.worker.*.triggers.hostname}"
}

output "worker_nodes_public_ipv4" {
  value = "${packet_device.nodes.*.access_public_ipv4}"
}
