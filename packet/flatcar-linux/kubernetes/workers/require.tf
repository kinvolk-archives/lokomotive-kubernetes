# Terraform version and plugin versions

terraform {
  required_version = ">= 0.12.0"

  required_providers {
    aws      = ">= 2.31.0"
    ct       = "= 0.4.0"
    local    = "~> 1.2"
    template = "~> 2.1"
    null     = "~> 2.1"
    tls      = "~> 2.0"
    packet   = "~> 2.7.3"
  }
}
