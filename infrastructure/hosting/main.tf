# Terraform configuration for Static Web App and Function App hosting

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
}

variable "location" {
  description = "The Azure region for the resources."
  type        = string
}

resource "azurerm_static_site" "website" {
  name                = "absolute-realms-website"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Free"
}
