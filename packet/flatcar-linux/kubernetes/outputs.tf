output "kubeconfig-admin" {
  value = module.bootkube.kubeconfig-admin
}

output "kubeconfig" {
  value = module.bootkube.kubeconfig-kubelet
}

output "dns_entries" {
  value = concat(
    # etcd
    [
      for index, device in packet_device.controllers:
      {
        name    = null_resource.dns_entries[index].triggers.etcd_fqdn
        type    = "A",
        ttl     = 300,
        records = null_resource.dns_entries[index].triggers.etcd_ip
      }
    ],
    [
      # apiserver public
      {
        name    = null_resource.dns_entries[0].triggers.apiserver_fqdn
        type    = "A",
        ttl     = 300,
        records = null_resource.dns_entries.*.triggers.apiserver_ip
      },
      # apiserver private
      {
        name    = null_resource.dns_entries[0].triggers.apiserver_private_fqdn
        type    = "A",
        ttl     = 300,
        records = null_resource.dns_entries.*.triggers.apiserver_private_ip
      },
    ]
  )
}
