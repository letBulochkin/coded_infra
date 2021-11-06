# Create stand VPC

resource "aws_vpc" "stand_vpc" {
    cidr_block = "172.35.0.0/16"
    tags = {
        Name = format(var.stand_name)
    }
}

##########################################
# Subnet definition
##########################################

# Create subnet for DNS Server, Ansible server, etc

resource "aws_subnet" "service_subnet_az0" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.0.0/24"
    availability_zone = var.azs[0]
    tags = {  # As we can not refernce to resource itself, we can not substitute availability_zone attribute
        Name = format("%s.%s.subnet.service", var.stand_name, var.azs[1])
    }
}

resource "aws_subnet" "load_balancers_subnet_az1" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.1.0/24"
    availability_zone = var.azs[1]
    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[1])
    }
}

resource "aws_subnet" "load_balancers_subnet_az0" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.2.0/24"
    availability_zone = var.azs[0]
    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[0])
    }
}

resource "aws_subnet" "backend_subnet_az1" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.3.0/24"
    availability_zone = var.azs[1]
    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[1])
    }
}
resource "aws_subnet" "backend_subnet_az0" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.4.0/24"
    availability_zone = var.azs[0]
    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[0])
    }
}

# TODO: separate monolith configuration into modules

resource "aws_security_group" "sg_allow_all" {  # TODO: add rules as separate resources
    name = "allow all sg"
    vpc_id = aws_vpc.stand_vpc.id

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "sg_ansible_git_server" {
    name = "ansible git server sg"
    vpc_id = aws_vpc.stand_vpc.id

    # DNS ports
    
    egress {
        description = "dns tcp"
        from_port = 53
        to_port = 53
        protocol = "tcp"
        cidr_blocks = [aws_vpc.stand_vpc.cidr_block]
    }

    egress {
        description = "dns udp"
        from_port = 53
        to_port = 53
        protocol = "udp"
        cidr_blocks = [aws_vpc.stand_vpc.cidr_block]
    }

    # SSH access ingoing and outgoing for Ansible
    
    ingress {
        description = "ssh"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [aws_vpc.stand_vpc.cidr_block]
    }

    egress {
        description = "ssh"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [aws_vpc.stand_vpc.cidr_block]
    }
    
    # git proto to access remote repo

    egress {
        description = "git"
        from_port = 9418
        to_port = 9418
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "croc_stand.security_group.service"
    }
}
