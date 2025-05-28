# Terraform configuration for DNS
provider "azurerm" {
  features {}
}

terraform {
  backend "azurerm" {
    resource_group_name  = var.resource_group_name
    storage_account_name = var.storage_account_name
    container_name       = var.container_name
    key                  = "terraform.tfstate"
  }
}

resource "azurerm_dns_zone" "main" {
  name                = "absoluterealms.world"
  resource_group_name = var.resource_group_name
  location            = var.location
}

output "dns_zone_id" {
  value = azurerm_dns_zone.main.id
}
