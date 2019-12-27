variable "entries" {
  type = list(object({
    name = string
    type = string
    ttl = number
    records = list(string)
  }))
}

resource "null_resource" "dns-etcd" {
  triggers = {
    records = join(",", flatten(var.entries.*.records))
  }

  provisioner "local-exec" {
    # TODO: fix route
    command = format("/home/mvb/lokomotive-kubernetes/packet/flatcar-linux/kubernetes/dns/check_dns.sh")
    on_failure = fail

    environment = {
      # pass using env variable because passing as argument messes up with escaping
      JSON = jsonencode(var.entries)
    }
  }
}
