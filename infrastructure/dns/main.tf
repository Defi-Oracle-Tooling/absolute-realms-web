# Terraform configuration for DNS zones and records

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

resource "azurerm_dns_zone" "main" {
  name                = "absoluterealms.world"
  resource_group_name = var.resource_group_name
}

resource "azurerm_dns_cname_record" "www" {
  name                = "www"
  zone_name           = azurerm_dns_zone.main.name
  resource_group_name = var.resource_group_name
  ttl                 = 3600
  record              = "absoluterealms.azurewebsites.net"
}
