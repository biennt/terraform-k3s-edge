terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

variable "availabilty_zone" {
  default = "ap-east-1a"
}

variable "instance_count" {
  default = "3"
}

provider "aws" {
  region = "ap-east-1"
}

resource "aws_vpc" "bientfvpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.bientfvpc.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.bientfvpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}

resource "aws_route_table_association" "route_table_external" {
  subnet_id      = aws_subnet.external.id
  route_table_id = aws_vpc.bientfvpc.main_route_table_id
}

resource "aws_subnet" "external" {
  vpc_id                  = aws_vpc.bientfvpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = var.availabilty_zone
}

resource "aws_security_group" "allow_all" {
  name        = "allow_all"
  description = "an allow all security group used in terraform"
  vpc_id      = aws_vpc.bientfvpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "k3s" {
  count                       = var.instance_count
  ami                         = "ami-0350928fdb53ae439"
  instance_type               = "t3.micro"
  associate_public_ip_address = true
  availability_zone           = aws_subnet.external.availability_zone
  subnet_id                   = aws_subnet.external.id
  security_groups             = ["${aws_security_group.allow_all.id}"]
  vpc_security_group_ids      = ["${aws_security_group.allow_all.id}"]
  key_name                    = "biennguyen-hk"
  user_data                   = file("userdata_ubuntu_k3s.sh")
  root_block_device { delete_on_termination = true }
  tags = {
    Name = "k3s-${count.index + 1}"
  }
}

output "public_ip" {
  value = {
    for k, v in aws_instance.k3s : k => v.public_ip
  }
}

