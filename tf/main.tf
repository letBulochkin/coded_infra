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

    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {  # As we can not refernce to resource itself, we can not substitute availability_zone attribute
        Name = format("%s.%s.subnet.service", var.stand_name, var.azs[1])
    }
}

resource "aws_subnet" "load_balancers_subnet_az1" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.1.0/24"
    availability_zone = var.azs[1]

    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[1])
    }
}

resource "aws_subnet" "load_balancers_subnet_az0" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.2.0/24"
    availability_zone = var.azs[0]

    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[0])
    }
}

resource "aws_subnet" "backend_subnet_az1" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.3.0/24"
    availability_zone = var.azs[1]

    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[1])
    }
}

resource "aws_subnet" "backend_subnet_az0" {
    vpc_id = aws_vpc.stand_vpc.id
    cidr_block = "172.35.4.0/24"
    availability_zone = var.azs[0]

    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {
      "Name" = format("%s.%s.subnet.load_b", var.stand_name, var.azs[0])
    }
}

# TODO: separate monolith configuration into modules

##########################################
# Elastic IPs definition
##########################################

resource "aws_eip" "eip_service" {
    #instance = aws_instance.inst_ansible_dns_serv.id
    vpc = true
    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {
        Name = format("%s.eip.service.service_access", var.stand_name)
    }
}

resource "aws_eip" "eip_public" {
    vpc = true
    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {
        Name = format("%s.eip.load_b.public_access", var.stand_name)
    }
}

##########################################
# Security groups definition
##########################################

# TODO: add reposerver security group as soon as I figure it out
# TODO: refactor this!

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

    depends_on = [
      aws_vpc.stand_vpc
    ]

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

    depends_on = [
      aws_vpc.stand_vpc
    ]

    tags = {
        "Name" = format("%s.sec_group.repo_access", var.stand_name)
    }
}

resource "aws_security_group" "sg_ansible_dns_server" {
    name = "ansible_dns_server_sg"
    description = "Security group for DNS and Ansible server"
    vpc_id = aws_vpc.stand_vpc.id
    
    ingress = [ {
        description = "dns tcp"
        from_port = 53
        to_port = 53
        protocol = "tcp"
        cidr_blocks = [aws_vpc.stand_vpc.cidr_block]
        ipv6_cidr_blocks = null  # So this is extremely dull. You can add SG rules as repeatable nested blocks, or you can
        prefix_list_ids = null   # add them as single nested block for list of inbound/outbound rules. However, if you use
        security_groups = null   # second approach, you are forced to set all of the parameters explicitly, even those you
        self = null              # are not intend to use. You still need to assign them null value. Shit.
    },
    {
        description = "dns udp"
        from_port = 53
        to_port = 53
        protocol = "udp"
        cidr_blocks = [aws_vpc.stand_vpc.cidr_block]
        ipv6_cidr_blocks = null  # So you either use repeated ingress/egress blocks (as I do below), or keep setting same
        prefix_list_ids = null   # parameters to null. Either way is not beautifull at all.
        security_groups = null   # Also need to look at aws_security_group_rule resource as a better way to organize
        self = null              # firewall rules.
    },
    {
        description = "ssh"  # SSH access ingoing and outgoing for Ansible
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  # temp open for every address to gain outbound access
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups = null
        self = null
    } ]

    egress = [ {
        description = "ssh"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups = null
        self = null
    },
    {
        description = "git"  # git proto to access remote repo
        from_port = 9418
        to_port = 9418
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups = null
        self = null
    },
    {
        description = "dns udp"
        from_port = 53
        to_port = 53
        protocol = "udp"
        cidr_blocks = [ "77.88.8.8/32" ]
        ipv6_cidr_blocks = null
        prefix_list_ids = null
        security_groups = null
        self = null
    } ]

    depends_on = [
      aws_vpc.stand_vpc
    ]

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
        cidr_blocks = [aws_subnet.service_subnet_az0.cidr_block]  # Give access from the service network for monitoring
    }

    ingress {
        description = "ssh in from service"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [aws_subnet.service_subnet_az0.cidr_block]
    }

    egress {
        description = "tcp 80 to backends"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [
            aws_subnet.backend_subnet_az1.cidr_block,
            aws_subnet.backend_subnet_az0.cidr_block
        ]
    }

    egress {
        description = "tcp 8080 to backends"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = [
            aws_subnet.backend_subnet_az1.cidr_block,
            aws_subnet.backend_subnet_az0.cidr_block
        ]
    }

    egress {
        description = "ssh out to lbs"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [
            aws_subnet.load_balancers_subnet_az1.cidr_block,
            aws_subnet.load_balancers_subnet_az0.cidr_block
        ]
    }

    egress {
        description = "dns udp"
        from_port = 53
        to_port = 53
        protocol = "udp"
        cidr_blocks = [aws_subnet.service_subnet_az0.cidr_block]
    }

    tags = {
        Name = format("%s.sec_group.load_balancers_subnet", var.stand_name)
    }
}

resource "aws_security_group" "sg_backends_subnet" {
    name = "backends_subnet_sg"
    vpc_id = aws_vpc.stand_vpc.id

    ingress {
        description = "tcp 80 from lbs"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [
            aws_subnet.load_balancers_subnet_az1.cidr_block,
            aws_subnet.load_balancers_subnet_az0.cidr_block
        ]
    }

    ingress {
        description = "tcp 8080 from lbs"
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = [
            aws_subnet.load_balancers_subnet_az1.cidr_block,
            aws_subnet.load_balancers_subnet_az0.cidr_block
        ]
    }

    ingress {
        description = "ssh in from service"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [aws_subnet.service_subnet_az0.cidr_block]
    }

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

    egress {
        description = "S3 endpoint IP address"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [format("%s/32", var.s3_endpoint_address), format("%s/32", var.s3_website_endpoint_address)]
    }

    egress {
        description = "ssh out to backends"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [
            aws_subnet.backend_subnet_az1.cidr_block,
            aws_subnet.backend_subnet_az0.cidr_block
        ]
    }

    egress {
        description = "DNS UDP"
        from_port = 53
        to_port = 53
        protocol = "udp"
        cidr_blocks = [aws_subnet.service_subnet_az0.cidr_block]
    }

    tags = {
        Name = format("%s.sec_group.backends_subnet", var.stand_name)
    }
}

##########################################
# SSH keypairs definition
##########################################

resource "aws_key_pair" "infra_sshkey" {
    key_name = var.ssh_key
    public_key = var.ssh_pubkey
}

##########################################
# DHCP options definition
##########################################

resource "aws_vpc_dhcp_options" "dhcopts_stand_vpc" {
    domain_name = "soup-int.msk.ru"
    domain_name_servers = [ "172.35.0.10" ]
}

resource "aws_vpc_dhcp_options_association" "assoc_dhcpopts_stand_vps" {
    vpc_id = aws_vpc.stand_vpc.id
    dhcp_options_id = aws_vpc_dhcp_options.dhcopts_stand_vpc.id
}

##########################################
# Instances definition
##########################################

resource "aws_instance" "inst_service_host" {  # Remember: resource renaming triggers redeploy. Use terraform state mv command
    ami = var.template_centos82
    instance_type = "m5.medium"
    availability_zone = aws_subnet.service_subnet_az0.availability_zone
    key_name = var.ssh_key

    subnet_id = aws_subnet.service_subnet_az0.id
    private_ip = replace(aws_subnet.service_subnet_az0.cidr_block, "0/24", "10")
    associate_public_ip_address = true  # = false conflicts with aws_eip_association
    vpc_security_group_ids = [
        aws_security_group.sg_ansible_dns_server.id,
        aws_security_group.sg_repo_access.id
    ]

    monitoring = true

    ebs_block_device {
        delete_on_termination = false
        device_name = "disk1"
        volume_type = var.default_volume_type
        volume_size = 64

        tags = {
            # Better naming maybe?
            Name = format("%s.ebs.service.inst_service_host", var.default_volume_type)
        }
    }

    depends_on = [
      aws_vpc.stand_vpc,
      aws_subnet.service_subnet_az0,
      aws_key_pair.infra_sshkey
    ]

    tags = {
        Name = format("%s.instance.service.inst_service_host", var.stand_name)
    }
}

resource "aws_eip_association" "name" {
    instance_id = aws_instance.inst_service_host.id
    allocation_id = aws_eip.eip_service.id
}

resource "aws_instance" "inst_loadbalancer_01" {
    ami = var.template_centos82
    instance_type = "m5.medium"
    availability_zone = aws_subnet.load_balancers_subnet_az0.availability_zone
    key_name = var.ssh_key

    subnet_id = aws_subnet.load_balancers_subnet_az0.id
    private_ip = replace(aws_subnet.load_balancers_subnet_az0.cidr_block, "0/24", "10")
    associate_public_ip_address = true
    vpc_security_group_ids = [
        aws_security_group.sg_load_balancers_subnet.id,
        aws_security_group.sg_repo_access.id
    ]

    monitoring = true

    ebs_block_device {
        delete_on_termination = false
        device_name = "disk1"
        volume_type = var.default_volume_type
        volume_size = 64

        tags = {
            # Better naming maybe?
            Name = format("%s.ebs.backends.inst_loadbalancer_01", var.default_volume_type)
        }
    }

    depends_on = [
      aws_vpc.stand_vpc,
      aws_subnet.load_balancers_subnet_az0,
      aws_key_pair.infra_sshkey
    ]

    tags = {
        Name = format("%s.instance.load_balancers.inst_loadb_01", var.stand_name)
    }
}

resource "aws_eip_association" "public_to_loadbalancer_eip_assoc" {
    instance_id = aws_instance.inst_loadbalancer_01.id
    allocation_id = aws_eip.eip_public.id
}

resource "aws_instance" "inst_backend_01" {
    ami = var.template_centos82
    instance_type = "m5.medium"
    availability_zone = aws_subnet.backend_subnet_az0.availability_zone
    key_name = var.ssh_key

    subnet_id = aws_subnet.backend_subnet_az0.id
    private_ip = replace(aws_subnet.backend_subnet_az0.cidr_block, "0/24", "10")
    associate_public_ip_address = false
    vpc_security_group_ids = [
        aws_security_group.sg_backends_subnet.id,
        aws_security_group.sg_repo_access.id
    ]

    monitoring = true

    ebs_block_device {
        delete_on_termination = false
        device_name = "disk1"
        volume_type = var.default_volume_type
        volume_size = 64

        tags = {
            # Better naming maybe?
            Name = format("%s.ebs.backends.inst_backend_01", var.default_volume_type)
        }
    }

    depends_on = [
      aws_vpc.stand_vpc,
      aws_subnet.backend_subnet_az0,
      aws_key_pair.infra_sshkey
    ]

    tags = {
        Name = format("%s.instance.backends.inst_backend_01", var.stand_name)
    }
}

resource "aws_instance" "inst_backend_02" {
    ami = var.template_centos82
    instance_type = "m5.medium"
    availability_zone = aws_subnet.backend_subnet_az1.availability_zone
    key_name = var.ssh_key

    subnet_id = aws_subnet.backend_subnet_az1.id
    private_ip = replace(aws_subnet.backend_subnet_az1.cidr_block, "0/24", "10")
    associate_public_ip_address = false
    vpc_security_group_ids = [
        aws_security_group.sg_backends_subnet.id,
        aws_security_group.sg_repo_access.id
    ]

    monitoring = true

    ebs_block_device {
        delete_on_termination = false
        device_name = "disk1"
        volume_type = var.default_volume_type
        volume_size = 64

        tags = {
            # Better naming maybe?
            Name = format("%s.ebs.backends.inst_backend_02", var.default_volume_type)
        }
    }

    depends_on = [
      aws_vpc.stand_vpc,
      aws_subnet.backend_subnet_az1,
      aws_key_pair.infra_sshkey
    ]

    tags = {
        Name = format("%s.instance.backends.inst_backend_02", var.stand_name)
    }
}
