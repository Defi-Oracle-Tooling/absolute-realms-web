# Terraform configuration for Hosting
provider "azurerm" {
  features {}
}

variable "resource_group_name" {
  description = "The name of the resource group."
  type        = string
  default     = "absoluterealmsdidresolve"
}

variable "location" {
  description = "The location of the resources."
  type        = string
  default     = "West Europe"
}

variable "service_plan_id" {
  description = "The ID of the App Service Plan."
  type        = string
}

resource "azurerm_static_web_app" "website" {
  name                = "absolute-realms-website"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku_tier            = "Standard"
}

resource "azurerm_linux_function_app" "did_resolver" {
  name                = "absolute-realms-did-resolver"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = var.service_plan_id
  storage_account_name = "validstorageacct" # Replace with a valid name
  storage_account_access_key = "valid-access-key" # Replace with actual value

  site_config {
    # Removed `linux_fx_version` as it is automatically determined
  }
}

output "static_web_app_url" {
  value = azurerm_static_web_app.website.default_host_name
}

output "function_app_url" {
  value = azurerm_linux_function_app.did_resolver.default_hostname
}
