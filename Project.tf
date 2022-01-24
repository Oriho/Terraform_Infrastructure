terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

#Configure AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA5SBQGJMQW3PX5MOE"
  secret_key = "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"
}

#Create VPC
resource "aws_vpc" "GeyafaVPC" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "GeyafaVPC"
  }
}

#Create Internet Gateway
resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.GeyafaVPC.id

  tags = {
    Name = "Geyafa-IGW"
  }
}

#Create Subnet (Public/Private)
resource "aws_subnet" "PublicSubNet" {
  vpc_id     = aws_vpc.GeyafaVPC.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public-SubNet"
  }
}

resource "aws_subnet" "PrivateSubnet" {
  vpc_id     = aws_vpc.GeyafaVPC.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "PrivateSubNet"
  }
}

#Create Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.GeyafaVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_internet_gateway.IGW.id
  }

  tags = {
    Name = "Geyafa-RT"
  }
}

#Subnet Association with Route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.PublicSubNet.id
  route_table_id = aws_route_table.rt.id
}

#Create Security Group
resource "aws_security_group" "WebDMZ" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.GeyafaVPC.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = {
    Name = "WebDMZ"
  }
}

#Create a network interface with an IP in a subnet which was created 
resource "aws_network_interface" "Geyafa-NIC" {
  subnet_id       = aws_subnet.PublicSubNet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.WebDMZ.id]
}

#Assign an Elastic IP to the Network Interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface      = aws_network_interface.Geyafa-NIC.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.IGW]
}

#Create EC2 Instance 
resource "aws_instance" "web" {
  ami           = "ami-04bf6dcdc9ab498ca"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "ice"
  # disable_api_termination = true
  
  network_interface{
    device_index = 0
    network_interface_id = aws_network_interface.Geyafa-NIC.id
  }
  tags = {
    Name = "WebServer"
  }
  # user.data = <<-EOF
  #             #/bin/bash
  #             #yum install httpd
  #             #sudo systemctl start
  #             #sudo bash -c 'HI LANGA' > /var/www/html/index.html
  #             EOF
}