output "resource_group_name" {
  description = "Name of the POC resource group."
  value       = azurerm_resource_group.poc.name
}

output "haproxy_private_ip" {
  description = "Private IP address of the HAProxy VM."
  value       = azurerm_network_interface.haproxy.private_ip_address
}

output "haproxy_public_ip" {
  description = "Public IP address of the HAProxy VM."
  value       = azurerm_public_ip.haproxy.ip_address
}

output "backend_private_ips" {
  description = "Private IP addresses assigned to the backend VM."
  value       = azurerm_network_interface.backend.private_ip_addresses
}

output "backend_dns_name" {
  description = "Private DNS name used by HAProxy for its backend."
  value       = "syntax.${azurerm_private_dns_zone.demo.name}"
}
