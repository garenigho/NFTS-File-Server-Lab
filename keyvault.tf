# Generate a random suffix for globally unique Key Vault naming
resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

# Fetch current Azure client configuration (needed for Tenant ID)
data "azurerm_client_config" "current" {}

# Azure Key Vault for storing lab secrets
resource "azurerm_key_vault" "lab_kv" {
  name                        = "lab-kv-${random_string.kv_suffix.result}"
  location                    = var.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  sku_name                    = "standard"

  tags = { 
    Environment = "Lab" 
    ManagedBy   = "Terraform" 
  }
}