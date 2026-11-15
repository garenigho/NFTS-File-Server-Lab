data "azurerm_client_config" "current" {}

# Key Vault names must be globally unique, so add a random suffix
resource "random_id" "kv_suffix" {
  byte_length = 4
}

resource "azurerm_key_vault" "lab_kv" {
  name                       = "kv-fslab-${random_id.kv_suffix.hex}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = {
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

# Let whoever ran az login write and read secrets
resource "azurerm_role_assignment" "kv_deployer_access" {
  scope                = azurerm_key_vault.lab_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Wait for the role assignment to propagate before writing the secret
resource "time_sleep" "wait_for_kv_rbac" {
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.kv_deployer_access]
}

resource "azurerm_key_vault_secret" "admin_password" {
  name         = "vm-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.lab_kv.id
  depends_on   = [time_sleep.wait_for_kv_rbac]

  tags = {
    ManagedBy = "Terraform"
  }
}