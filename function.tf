# ===========================================================================
# FUNCTION APP (purge quotidienne des blobs) — RG batchdeletelastmail
# ===========================================================================

# Plan Consumption (Linux) — facturation à l'exécution, idéal pour un timer.
resource "azurerm_service_plan" "function" {
  name                = "asp-func-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1"
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Function App
# Le backing store (AzureWebJobsStorage) réutilise le Storage Account de l'app.
# ---------------------------------------------------------------------------
resource "azurerm_linux_function_app" "main" {
  name                = local.function_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.function.id
  https_only          = true
  tags                = var.tags

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  functions_extension_version = "~4"

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = var.python_version
    }
  }

  app_settings = {
    # Variables lues par azure_function/function_app.py
    "MAILS_CONTAINER" = var.blob_container_name
    "RETENTION_DAYS"  = var.function_retention_days
    "RETENTION_CRON"  = var.retention_cron

    # Connection string du Storage, injectée depuis Key Vault
    "MAILS_CONN_STR" = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.app["azure-storage-connection-string"].versionless_id})"

    # Build distant des dépendances Python au déploiement (Oryx)
    "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    "ENABLE_ORYX_BUILD"              = "true"
  }

  lifecycle {
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# Autorise l'identité de la Function App à LIRE les secrets du Key Vault
resource "azurerm_role_assignment" "function_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}
