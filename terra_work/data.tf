data "aws_ami" "my_ami" {
  name_regex  = "amzn2-ami-hvm"
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  #    filter {
  #     name   = "name"
  #     values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  #   }
}


data "aws_region" "my_available_region" {
}

data "aws_availability_zones" "my_available_zones" {
}


output "my_available_ami" {
  value = data.aws_ami.my_ami
}

output "my_available_zones_op" {
  value = data.aws_availability_zones.my_available_zones.names
}


locals {
  dev_instance_type  = "t2.micro"
  prod_instance_type = "t3.micro"
  server_name        = "imazy-web"
  timestamp          = timestamp()
}