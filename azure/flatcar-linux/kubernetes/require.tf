# Terraform version and plugin versions

terraform {
  required_version = ">= 0.11.0"
}

provider "azurerm" {
  version = "~> 1.21"
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
