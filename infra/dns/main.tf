# Terraform configuration for DNS
provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = "absoluterealms-dns-rg" # Updated with actual value
    storage_account_name = "absoluterealmsdnsstorage" # Updated with actual value
    container_name       = "tfstate" # Updated with actual value
    key                  = "terraform.tfstate"
  }
}

resource "azurerm_dns_zone" "main" {
  name                = "absoluterealms.world"
  resource_group_name = var.resource_group_name
}

output "dns_zone_id" {
  value = azurerm_dns_zone.main.id
}

variable "resource_group_name" {
  description = "Resource group for the DNS zone"
  type        = string
  default     = "example-resource-group"
}
