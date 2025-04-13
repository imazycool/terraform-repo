variable "my_map" {
  type = map(any)
  default = {
    "prod" = {
      ip  = "10.120.12.12"
      azy = "prod-ip"
    }
    "dev" = {
      ip  = "10.250.0.53"
      azy = "dev-ip"
    }
  }
}

output "map_test" {
  value = "value for : ${var.my_map["prod"]["azy"]}  is --> ${var.my_map["prod"]["ip"]}"
}

resource "local_file" "output" {
  for_each = var.my_map
  content  = "${each.value.azy} -----> ${each.value.ip}"
  filename = "output-${each.key}.txt"
}

