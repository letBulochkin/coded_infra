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

##########################################
# Security groups definition
##########################################

# TODO: add reposerver security group as soon as I figure it out

resource "aws_security_group" "sg_allow_all" {
    name = "allow_all_sg"
    vpc_id = aws_vpc.stand_vpc.id

    ingress {  # Q: Do I really need that?
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        "Name" = format("%s.sec_group.allow_all", var.stand_name)
    }
}

resource "aws_security_group" "sg_repo_access" {  # TODO: make more strict, needs testing
    name = "repo_access_sg"
    description = "Set of firewall rules allowing outbound access to yum repos"
    vpc_id = aws_vpc.stand_vpc.id

    egress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        "Name" = format("%s.sec_group.repo_access", var.stand_name)
    }
}

resource "aws_security_group" "sg_ansible_dns_server" {
    name = "ansible_dns_server_sg"
    description = "Security group for DNS and Ansible server"
    vpc_id = aws_vpc.stand_vpc.id
    
    egress {
        description = "dns tcp"  # DNS ports
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
    
    ingress {
        description = "ssh"  # SSH access ingoing and outgoing for Ansible
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

    egress {
        description = "git"  # git proto to access remote repo
        from_port = 9418
        to_port = 9418
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = format("%s.sec_group.ansible_dns_serv", var.stand_name)
    }
}

resource "aws_security_group" "sg_ovpn_server" {
    name = "ovpn_server_sg"
    vpc_id = aws_vpc.stand_vpc.id

    ingress {
        description = "ovpn tcp"  # Q: Do I need inbound SSH rule?
        from_port = 1194
        to_port = 1194
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        description = "ssh out"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [aws_vpc.stand_vpc.cidr_block]
    }

    tags = {
        Name = format("%s.sec_group.ovpn_serv", var.stand_name)
    }
}

# resource "aws_security_group" "sg_service_subnet" { }
#
# Every node in service should have its own security group for additional security.

resource "aws_security_group" "sg_load_balancers_subnet" {
    name = "load_balancer_subnet_sg"
    vpc_id = aws_vpc.stand_vpc.id

    ingress {
        description = "tcp 80"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "tcp 8080"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "haproxy stats"
        from_port = 9000
        to_port = 9000
        protocol = "tcp"
        cidr_blocks = ["172.35.0.0/24"]  # Give access from the service network for monitoring purposes
    }

    egress {
        description = "tcp 80"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["172.35.3.0/24", "172.35.4.0/24"]  # Give access to the backends network
    }

    egress {
        description = "tcp 8080"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["172.35.3.0/24", "172.35.4.0/24"]
    }

    ingress {
        description = "ssh in from service"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["172.35.0.0/24"]
    }

    egress {
        description = "ssh out to lbs"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["172.35.1.0/24", "172.35.2.0/24"]
    }

    tags = {
        Name = format("%s.sec_group.load_balancers_subnet", var.stand_name)
    }
}

resource "aws_security_group" "sg_backends_subnet" {
    name = "backends_subnet_sg"
    vpc_id = aws_vpc.stand_vpc.id

    ingress {
        description = "tcp 80"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["172.35.1.0/24", "172.35.2.0/24"]
    }

    ingress {
        description = "tcp 8080"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["172.35.1.0/24", "172.35.2.0/24"]
    }

    egress {
        description = "S3 endpoint IP address"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [format("%s/32", var.s3_endpoint_address), format("%s/32", var.s3_website_endpoint_address)]
    }

    ingress {
        description = "ssh in from service"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["172.35.0.0/24"]
    }

    egress {
        description = "ssh out to backends"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["172.35.3.0/24", "172.35.4.0/24"]
    }

    tags = {
        Name = format("%s.sec_group.backends_subnet", var.stand_name)
    }
}

##########################################
# Instances definition
##########################################

resource "aws_instance" "inst_ansible_dns_serv" {  # Remember: resource renaming triggers redeploy. Use terraform state mv command
    ami = var.template_centos82
    instance_type = "m5.small"
    availability_zone = aws_subnet.service_subnet_az0.availability_zone
    subnet_id = aws_subnet.service_subnet_az0.id
    key_name = var.ssh_key
    associate_public_ip_address = true
    vpc_security_group_ids = [ format("%s", aws_security_group.sg_allow_all.id) ]

    tags = {
        Name = format("%s.instance.service.ansible_dns_serv", var.stand_name)
    }
}

resource "aws_instance" "inst_repo_server" {
    ami = var.template_centos82
    instance_type = "m5.small"
    availability_zone = aws_subnet.service_subnet_az0.availability_zone
    subnet_id = aws_subnet.service_subnet_az0.id
    key_name = var.ssh_key
    associate_public_ip_address = false
    vpc_security_group_ids = [ format("%s", aws_security_group.sg_allow_all.id) ]

    tags = {
        Name = format("%s.instance.service.repo_serv", var.stand_name)
    }
}
