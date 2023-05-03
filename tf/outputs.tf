output "service_access_ip" {
    value = aws_eip.eip_service.public_ip
    description = "Service access EIP"
}
