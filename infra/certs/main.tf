# Terraform configuration for Certificates
provider "azurerm" {
  features {}
}

resource "azurerm_key_vault_certificate" "wildcard" {
  name         = "wildcard-cert"
  key_vault_id = var.key_vault_id
  certificate_policy {
    issuer_parameters {
      name = "Self" # Replace with ACME provider if needed
    }
  }
}
