##################################################################################
# PROVIDERS
##################################################################################

provider "aws" {
}

data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu" {
  most_recent = true
  
filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# NETWORKING #


# VPC 

resource "aws_vpc" "joestack-vpc" {
  cidr_block           = "${var.network_address_space}"
  enable_dns_hostnames = "true"

  tags {
    Name        = "${var.name}-vpc"
    Environment = "${var.environment_tag}"
    TTL         = "${var.ttl}"
    Owner       = "${var.owner}"
  }
}


resource "aws_subnet" "tfe_subnet" {
  vpc_id                  = "${aws_vpc.joestack-vpc.id}"
  cidr_block              = "${cidrsubnet(var.network_address_space, 8, 1)}"
  map_public_ip_on_launch = "true"
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
          Name = "TFE Subnet"
  }

}

# ROUTING #


resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.joestack-vpc.id}"

}

resource "aws_route_table" "rtb" {
  vpc_id = "${aws_vpc.joestack-vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw.id}"
  }

    tags {
        Name = "IGW"
    }

}

resource "aws_route_table_association" "tfe_subnet" {
  subnet_id      = "${aws_subnet.tfe_subnet.*.id[0]}"
  route_table_id = "${aws_route_table.rtb.id}"

}

# SECURITY GROUPS #

# Jumphost
resource "aws_security_group" "jumphost" {
  name        = "${var.name}-jumphost-sg"
  description = "Jumphost/Bastion servers"
  vpc_id      = "${aws_vpc.joestack-vpc.id}"
}

resource "aws_security_group_rule" "jh-ssh" {
  security_group_id = "${aws_security_group.jumphost.id}"
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "jh-egress" {
  security_group_id = "${aws_security_group.jumphost.id}"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}




# TFE security group

resource "aws_security_group" "tfe" {
  name        = "tfe"
  vpc_id      = "${aws_vpc.joestack-vpc.id}"

  # SSH access from anywhere
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # TFE access from anywhere
  ingress {
    from_port   = 8800
    to_port     = 8800
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

# INSTANCES #

resource "aws_instance" "jumphost" {
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.micro"
  subnet_id                   = "${aws_subnet.tfe_subnet.id}"
  private_ip                  = "${cidrhost(aws_subnet.tfe_subnet.cidr_block, 10)}"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = ["${aws_security_group.jumphost.id}"]
  key_name                    = "${var.key_name}"

  user_data = <<-EOF
              #!/bin/bash
              echo "${var.id_rsa_aws}" >> /home/ubuntu/.ssh/id_rsa
              chown ubuntu /home/ubuntu/.ssh/id_rsa
              chgrp ubuntu /home/ubuntu/.ssh/id_rsa
              chmod 600 /home/ubuntu/.ssh/id_rsa
              apt-get update -y
              apt-get install ansible -y 
              EOF

  tags {
    Name        = "jumphost-${var.environment_tag}"
    Environment = "${var.environment_tag}"
    TTL         = "${var.ttl}"
    Owner       = "${var.owner}"
  }
}



resource "aws_instance" "tfe_node" {
  count                       = "${var.tfe_node_count}"
  ami                         = "${data.aws_ami.ubuntu.id}"
  instance_type               = "t2.medium"
  subnet_id                   = "${aws_subnet.tfe_subnet.id}"
  private_ip                  = "${cidrhost(aws_subnet.tfe_subnet.cidr_block, count.index + 100)}"
  associate_public_ip_address = "true"
  vpc_security_group_ids      = ["${aws_security_group.tfe.id}"]
  key_name                    = "${var.key_name}"
  
  tags = [
  {
         Name = "${format("tfe-%02d.${var.dns_domain}", count.index + 1)}"
  },
  {
         key = "owner"
         value = "${var.owner}"
         propagate_at_launch = true
  },
  {
         key = "TTL"
         value = "-1"
         propagate_at_launch = true
  }

  ]

  ebs_block_device {
      device_name = "/dev/xvdb"
      volume_type = "gp2"
      volume_size = 40
    }

  ebs_block_device {
      device_name = "/dev/xvdc"
      volume_type = "gp2"
      volume_size = 20
    }

  user_data = "${file("./templates/userdata.sh")}"

}
