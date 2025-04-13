/*
Name: IaC Buildout for Terraform Associate Exam
Description: AWS Infrastructure Buildout
Contributors: Bryan and Gabe
*/


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

provider "p-aws" {
  region = var.my_region
}


#Retrieve the list of AZs in the current AWS region
data "aws_region" "my_available_region" {}
data "aws_availability_zones" "my_available_zones" {}


locals {
  dev_instance_type  = "t2.micro"
  prod_instance_type = "t3.micro"
  server_name        = "imazy-web"
  timestamp          = timestamp()
}


variable "my_region" {
  default = "ap-south-1"
}

variable "my_cidr_range" {
  default = "10.0.0.0/16"
}

variable "my_public_subnet" {
  type = map(string)
  default = {
    "public_subnet_1" = 1
    "public_subnet_2" = 2
  }
}


variable "my_private_subnet" {
    type = map(string)
  default = {
    "pvt-01" = 1
    "pvt-01" = 2
  }
}


# Configure the AWS Provider
provider "aws" {
  region = data.aws_region.my_available_region 
}



#Define the VPC 
resource "aws_vpc" "vpc" {
  cidr_block = var.my_cidr_range

  tags = {
    Name        = var.my_cidr_range
    Environment = "demo_environment"
    Terraform   = "true"
  }

  enable_dns_hostnames = true
}



#Deploy the private subnets
resource "aws_subnet" "private_subnets" {
  for_each          = var.my_private_subnet
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(var.my_cidr_range, 8, each.value)
  availability_zone = tolist(data.aws_availability_zones.my_available_zones.names)[each.value]

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}



#Deploy the public subnets
resource "aws_subnet" "public_subnets" {
  for_each                = var.my_public_subnet
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = cidrsubnet(var.my_cidr_range, 8, each.value + 100)
  availability_zone       = tolist(data.aws_availability_zones.my_available_zones.names)[each.value]
  map_public_ip_on_launch = true

  tags = {
    Name      = each.key
    Terraform = "true"
  }
}



#Create route tables for public and private subnets
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
    #nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_public_rtb"
    Terraform = "true"
  }
}


resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    # gateway_id     = aws_internet_gateway.internet_gateway.id
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
  tags = {
    Name      = "demo_private_rtb"
    Terraform = "true"
  }
}

#Create route table associations
resource "aws_route_table_association" "public" {
  depends_on     = [aws_subnet.public_subnets]
  route_table_id = aws_route_table.public_route_table.id
  for_each       = aws_subnet.public_subnets
  subnet_id      = each.value.id
}

resource "aws_route_table_association" "private" {
  depends_on     = [aws_subnet.private_subnets]
  route_table_id = aws_route_table.private_route_table.id
  for_each       = aws_subnet.private_subnets
  subnet_id      = each.value.id
}

#Create Internet Gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "demo_igw"
  }
}

#Create EIP for NAT Gateway
resource "aws_eip" "nat_gateway_eip" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.internet_gateway]
  tags = {
    Name = "demo_igw_eip"
  }
}

#Create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  depends_on    = [aws_subnet.public_subnets]
  allocation_id = aws_eip.nat_gateway_eip.id
  subnet_id     = aws_subnet.public_subnets["public_subnet_1"].id
  tags = {
    Name = "demo_nat_gateway"
  }
}


resource "random_string" "random" {
  length = 10
}


# Terraform Data Block - To Lookup Latest Ubuntu 20.04 AMI Image
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}




resource "tls_private_key" "generated" {
  algorithm = "RSA"
}

/* resource "local_file" "private_key_pem" {
  content  = tls_private_key.generated.private_key_pem
  filename = "MyAWSKey.pem"
} */

resource "aws_key_pair" "generated" {
  key_name   = "MyAWSKey"
  public_key = tls_private_key.generated.public_key_openssh
}

resource "aws_security_group" "ingress-ssh" {
  name   = "allow-all-ssh"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "vpc-web" {
  name        = "vpc-web-${terraform.workspace}"
  vpc_id      = aws_vpc.vpc.id
  description = "Web Traffic"
  ingress {
    description = "Allow Port 80"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow Port 443"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all ip and ports outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Terraform Resource Block - To Build Web Server in Public Subnet
resource "aws_instance" "web_server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public_subnets["public_subnet_1"].id
  security_groups             = [aws_security_group.ingress-ssh.id, aws_security_group.vpc-web.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.generated.key_name
  connection {
    user        = "ubuntu"
    private_key = tls_private_key.generated.private_key_pem
    host        = self.public_ip
  }

  # Leave the first part of the block unchanged and create our `local-exec` provisioner
  /*   provisioner "local-exec" {
    command = "chmod 600 ${local_file.private_key_pem.filename}"
  } */

  provisioner "remote-exec" {
    inline = [
      "sudo rm -rf /tmp",
      "sudo yum update", # For CentOS/RHEL
      "sudo yum install -y git", # For CentOS/RHEL
      "sudo git clone https://github.com/hashicorp/demo-terraform-101 /tmp",
      "sudo sh /tmp/assets/setup-web.sh",
    ]
  }

#   tags = local.common_tags

  lifecycle {
    ignore_changes = [security_groups]
  }
}



