# Terraform version and plugin versions

terraform {
  required_version = ">= 0.11.0"
}

provider "ct" {
  version = "~> 0.4.0"
}

provider "local" {
  version = "~> 1.0"
}

provider "null" {
  version = "~> 2.1.2"
}

provider "template" {
  version = "~> 2.1.2"
}

provider "tls" {
  version = "~> 2.0.1"
}

provider "libvirt" {
  version = "~> 0.5.2"
  uri = "qemu:///system"
}

