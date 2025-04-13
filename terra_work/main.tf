#create vpc 

terraform {
  required_version = ">= 1.9"
  required_providers {
    p-aws = {
      source  = "hashicorp/aws"
      version = ">= 4.8"
    }
    p-random = {
      source  = "hashicorp/random"
      version = ">= 2.5"
    }
    p-http = {
      source  = "hashicorp/http"
      version = ">= 2.5"
    }
    p-tls = {
      source  = "hashicorp/tls"
      version = ">= 3.0"
    }
  }
}



resource "aws_vpc" "my_vpc" {
  cidr_block = var.my_cidr_range
}


resource "aws_eip" "my_public_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.my_internet_gtw]
}



#public subnet 
resource "aws_subnet" "my_public_subnet" {
  for_each                = var.my_public_subnet
  cidr_block              = cidrsubnet(var.my_cidr_range, 8, each.value + 2)
  vpc_id                  = aws_vpc.my_vpc.id
  map_public_ip_on_launch = true
  availability_zone       = tolist(data.aws_availability_zones.my_available_zones.names)[each.value]
  tags = {
    Name      = "imazy-${each.key}"
    terraform = true
  }
}


resource "aws_subnet" "my_private_subnet" {
  cidr_block = cidrsubnet(var.my_cidr_range, 8, 8)
  vpc_id     = aws_vpc.my_vpc.id
}


resource "aws_internet_gateway" "my_internet_gtw" {
  vpc_id = aws_vpc.my_vpc.id
}



resource "aws_route_table" "my_public_route" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gtw.id
  }
}


resource "aws_route_table" "my_private_route" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_net_gtw.id
  }
}

resource "aws_route_table_association" "my_route_table_asc" {
  depends_on     = [aws_subnet.my_public_subnet]
  route_table_id = aws_route_table.my_public_route.id
  for_each       = aws_subnet.my_public_subnet
  subnet_id      = each.value.id
}

resource "aws_nat_gateway" "my_net_gtw" {
  depends_on    = [aws_subnet.my_public_subnet]
  subnet_id     = aws_subnet.my_public_subnet["public-01"].id
  allocation_id = aws_eip.my_public_eip.id
}


## aws resources 
provider "p-aws" {
  region = var.my_region
}


resource "tls_private_key" "my_pvt_key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "my_key_pair" {
  key_name   = "imazy_pvt_key"
  public_key = tls_private_key.my_pvt_key.public_key_openssh
  lifecycle {
    ignore_changes = [key_name]
  }
}


resource "aws_security_group" "my_http_sg" {
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "my_ssh_sg" {
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "my_web-server" {
  ami                         = data.aws_ami.my_ami.id
  instance_type               = (strcontains(terraform.workspace, "prod") ? local.prod_instance_type : local.dev_instance_type)
  subnet_id                   = aws_subnet.my_public_subnet["public-01"].id
  security_groups             = [aws_security_group.my_http_sg.id, aws_security_group.my_ssh_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.my_key_pair.key_name

  connection {
    user        = "ec2-user"
    private_key = tls_private_key.my_pvt_key.private_key_pem
    host        = self.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp",
      "sudo yum update", # For CentOS/RHEL
      "sudo yum install -y git", # For CentOS/RHEL
      "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
      "sudo sh /tmp/assets/setup-web.sh",
    ]
  }

  tags = {
    Name = "${local.server_name}-${terraform.workspace}"
  }
}

