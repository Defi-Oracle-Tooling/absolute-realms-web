# Terraform configuration for Monitoring
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

resource "azurerm_application_insights" "main" {
  name                = "absolute-realms-monitoring"
  resource_group_name = var.resource_group_name
  location            = var.location
  application_type    = "web"
}

resource "azurerm_monitor_metric_alert" "error_rate" {
  name                = "error-rate-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.main.id]
  criteria {
    metric_name      = "requests/count"
    metric_namespace = "Microsoft.Insights/components"
    operator         = "GreaterThan"
    threshold        = 5
    aggregation      = "Total"
  }
}
