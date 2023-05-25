output "service_access_ip" {
    value = aws_eip.eip_service.public_ip
    description = "Service access EIP"
}

output "main_public_ip" {
    value = aws_eip.eip_public.public_ip
    description = "Primary public EIP"
}
