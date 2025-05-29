# Terraform configuration for Certificates
provider "azurerm" {
  features {}
}

variable "key_vault_id" {
  description = "The ID of the Key Vault."
  type        = string
}

resource "azurerm_key_vault_certificate" "wildcard" {
  name         = "wildcard-cert"
  key_vault_id = var.key_vault_id
  certificate_policy {
    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }
    secret_properties {
      content_type = "application/x-pkcs12"
    }
    issuer_parameters {
      name = "Self" # Replace with ACME provider if needed
    }
  }
}
