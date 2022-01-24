terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
#terraform 
#Configure AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = "AKIA5EYWRYDVQZQYDJ74"
  secret_key = "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"
}
# Define Variable
# variable "subent_prefix"{
#   description = "cidr block for subnet"
#   #default
# }

#Create VPC
resource "aws_vpc" "terraform-vpc" {
  cidr_block = "172.20.0.0/16"
 #
  tags = {
    Name = "Production VPC"
  }
}

#Create Subnet
resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.terraform-vpc.id
  # cidr_block = var.subent_prefix
  cidr_block = "172.20.1.0/24"
  availability_zone =  "us-east-1a"

  tags = {
    Name = "Prod-Subnet"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.test-RT.id
}
#Create Internet Gateway
resource "aws_internet_gateway" "test-gw" {
  vpc_id = aws_vpc.terraform-vpc.id

  tags = {
    Name = "Test_VPC"
  }
}

# Create Custom Route Table
resource "aws_route_table" "test-RT" {
  vpc_id = aws_vpc.terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.test-gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.test-gw.id
  }

  tags = {
    Name = "Test"
  }
}

# Create Security Group
resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.terraform-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}
  #Create Network Interface
  resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["172.20.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  #  attachment {
  #    instance    ="${aws_instance.test.id}"
  #    device_index = 1
  #  }
}

#Assigin an Elastic IP to the Network interface 
resource "aws_eip" "a" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "172.20.1.50"
  depends_on                = [aws_internet_gateway.test-gw]
}

#Print the output of Elastic Ip
output "server_public_ip"{
  value = aws_eip.a
}
#Create EC2 Instance 
resource "aws_instance" "web-server-instance" {
  ami               = "ami-04505e74c0741db8d" 
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"
  key_name          = "ansible_test"
 
  # disable_api_termination = false

  network_interface{
    device_index = 0
    network_interface_id = aws_network_interface.web-server-nic.id
  }

  user_data = <<-EOF
              #!/bin/bash
              sudo apt update -y
              sudo apt install apache2 -y
              sudo systemctl start apache2
              sudo bash -c 'echo web server > /var/www/html/index.html'
              EOF

  tags = {
    Name = "Ubunutu Server"
  }
}

# output "Ubunut_Server"{
#   value = aws_instance.web-server-instance.private_ip
# }


# 1. Create vpc
# 2.Create Internet Gateway.
# 3.Create Custom Route Table.
# 4.Create Subnet.
# 5.Associate Subnet with Route Table.
# 6.Create Security Group to allow Port 22,80,443.
# 7.Create a Network Interface with ip in the subnet that was created in step4.
# 8.Assigin Elastic IP to the network interface created in step4.
# 9.Create Ubuntu Server and install/enable apache2.
