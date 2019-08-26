locals {
  # Channel for a Container Linux derivative
  # coreos-stable -> Container Linux Stable
  channel = "${element(split("-", var.os_image), 1)}"
}

data "azurerm_image" "custom_workers" {
  name                = "${var.custom_image_name}"
  resource_group_name = "${var.custom_image_resource_group_name}"
}

# Workers scale set
resource "azurerm_virtual_machine_scale_set" "workers" {
  resource_group_name = "${var.resource_group_name}"

  name                   = "${var.name}-workers"
  location               = "${var.region}"
  single_placement_group = false

  sku {
    name     = "${var.vm_type}"
    tier     = "standard"
    capacity = "${var.worker_count}"
  }

  # boot
  storage_profile_image_reference {
    id = "${data.azurerm_image.custom_workers.id}"
  }

  # storage
  storage_profile_os_disk {
    create_option     = "FromImage"
    caching           = "ReadWrite"
    os_type           = "linux"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name_prefix = "${var.name}-worker-"
    admin_username       = "core"
    custom_data          = "${data.ct_config.worker-ignition.rendered}"
  }

  # Azure mandates setting an ssh_key, even though Ignition custom_data handles it too
  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/core/.ssh/authorized_keys"
      key_data = "${var.ssh_authorized_key}"
    }
  }

  # network
  network_profile {
    name                      = "nic0"
    primary                   = true
    network_security_group_id = "${var.security_group_id}"

    ip_configuration {
      name      = "ip0"
      primary   = true
      subnet_id = "${var.subnet_id}"

      # backend address pool to which the NIC should be added
      load_balancer_backend_address_pool_ids = ["${var.backend_address_pool_id}"]
    }
  }

  # lifecycle
  upgrade_policy_mode = "Manual"
  priority            = "${var.priority}"
  eviction_policy     = "Delete"
}

# Scale up or down to maintain desired number, tolerating deallocations.
resource "azurerm_monitor_autoscale_setting" "workers" {
  resource_group_name = "${var.resource_group_name}"

  name     = "${var.name}-maintain-desired"
  location = "${var.region}"

  # autoscale
  enabled            = true
  target_resource_id = "${azurerm_virtual_machine_scale_set.workers.id}"

  profile {
    name = "default"

    capacity {
      minimum = "${var.worker_count}"
      default = "${var.worker_count}"
      maximum = "${var.worker_count}"
    }
  }
}

# Worker Ignition configs
data "ct_config" "worker-ignition" {
  content      = "${data.template_file.worker-config.rendered}"
  pretty_print = false
  snippets     = ["${var.clc_snippets}"]
}

# Worker Container Linux configs
data "template_file" "worker-config" {
  template = "${file("${path.module}/cl/worker.yaml.tmpl")}"

  vars = {
    kubeconfig             = "${indent(10, var.kubeconfig)}"
    ssh_authorized_key     = "${var.ssh_authorized_key}"
    cluster_dns_service_ip = "${cidrhost(var.service_cidr, 10)}"
    cluster_domain_suffix  = "${var.cluster_domain_suffix}"
  }
}
