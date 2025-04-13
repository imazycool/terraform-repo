variable "my_region" {
  default = "ap-south-1"
}

variable "my_cidr_range" {
  default = "10.0.0.0/16"
}

variable "my_public_subnet" {
  type = map(string)
  default = {
    "public-01" = 1
    "public-02" = 2
  }
}

variable "private_subnets" {
  default = {
    "pvt-01" = 1
    "pvt-01" = 2
  }
}