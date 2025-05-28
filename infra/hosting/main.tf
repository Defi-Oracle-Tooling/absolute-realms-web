# Terraform configuration for Hosting
provider "azurerm" {
  features {}
}

resource "azurerm_static_site" "website" {
  name                = "absolute-realms-website"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Standard"
}

resource "azurerm_function_app" "did_resolver" {
  name                = "absolute-realms-did-resolver"
  resource_group_name = var.resource_group_name
  location            = var.location
  app_service_plan_id = var.app_service_plan_id
}

output "static_web_app_url" {
  value = azurerm_static_site.website.default_hostname
}

output "function_app_url" {
  value = azurerm_function_app.did_resolver.default_hostname
}
