# Secure copy etcd TLS assets to controllers.
resource "null_resource" "copy-controller-secrets" {
  count = var.controller_count

  connection {
    type    = "ssh"
    host    = packet_device.controllers[count.index].access_public_ipv4
    user    = "core"
    timeout = "60m"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_ca_cert
    destination = "$HOME/etcd-client-ca.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_client_cert
    destination = "$HOME/etcd-client.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_client_key
    destination = "$HOME/etcd-client.key"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_server_cert
    destination = "$HOME/etcd-server.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_server_key
    destination = "$HOME/etcd-server.key"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_peer_cert
    destination = "$HOME/etcd-peer.crt"
  }

  provisioner "file" {
    content     = module.bootkube.etcd_peer_key
    destination = "$HOME/etcd-peer.key"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /etc/ssl/etcd/etcd",
      "sudo mv etcd-client* /etc/ssl/etcd/",
      "sudo cp /etc/ssl/etcd/etcd-client-ca.crt /etc/ssl/etcd/etcd/server-ca.crt",
      "sudo mv etcd-server.crt /etc/ssl/etcd/etcd/server.crt",
      "sudo mv etcd-server.key /etc/ssl/etcd/etcd/server.key",
      "sudo cp /etc/ssl/etcd/etcd-client-ca.crt /etc/ssl/etcd/etcd/peer-ca.crt",
      "sudo mv etcd-peer.crt /etc/ssl/etcd/etcd/peer.crt",
      "sudo mv etcd-peer.key /etc/ssl/etcd/etcd/peer.key",
      "sudo chown -R etcd:etcd /etc/ssl/etcd",
      "sudo chmod -R 500 /etc/ssl/etcd",
    ]
  }

  triggers = {
    controller_id = packet_device.controllers[count.index].id
  }
}

# Secure copy bootkube assets to ONE controller.
resource "null_resource" "copy-assets-dir" {
  depends_on = [
    module.bootkube,
    null_resource.copy-controller-secrets,
    local_file.host_endpoint_controller,
    local_file.host_protection_policy,
  ]

  connection {
    type    = "ssh"
    host    = packet_device.controllers[0].access_public_ipv4
    user    = "core"
    timeout = "15m"
  }

  provisioner "file" {
    source      = var.asset_dir
    destination = "$HOME/assets"
  }
}

# start bootkube to perform one-time self-hosted cluster bootstrapping.
resource "null_resource" "bootkube-start" {
  depends_on = [
    module.bootkube,
    null_resource.copy-controller-secrets,
    null_resource.copy-assets-dir,
  ]

  connection {
    type    = "ssh"
    host    = packet_device.controllers[0].access_public_ipv4
    user    = "core"
    timeout = "15m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv $HOME/assets /opt/bootkube",
      "sudo systemctl start bootkube",
    ]
  }
}

resource "local_file" "host_endpoint_controller" {
  count = var.networking == "calico" ? 1 : 0

  content  = file("${path.module}/calico/host-endpoint-controller.yaml")
  filename = "${var.asset_dir}/charts/kube-system/calico/templates/host-endpoint-controller.yaml"
}

resource "local_file" "host_protection_policy" {
  count = var.networking == "calico" ? 1 : 0

  content = templatefile("${path.module}/calico/host-protection.yaml.tmpl", {
    controller_host_endpoints = templatefile("${path.module}/calico/controller-host-endpoint.yaml.tmpl", {
      node_names = packet_device.controllers.*.hostname
    })
    management_cidrs       = jsonencode(var.management_cidrs)
    cluster_internal_cidrs = jsonencode([var.node_private_cidr, var.pod_cidr, var.service_cidr])
    etcd_server_cidrs      = jsonencode(packet_device.controllers.*.access_private_ipv4)
  })

  filename = "${var.asset_dir}/charts/kube-system/calico/templates/host-protection.yaml"
}
