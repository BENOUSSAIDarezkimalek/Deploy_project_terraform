# ===========================================================================
# FUNCTION APP (purge quotidienne des blobs) — RG batchdeletelastmail
# ===========================================================================

# ---------------------------------------------------------------------------
# Pas de plan dédié : la Function partage le plan App Service de la Web App.
#
# Le plan Consumption (Y1) serait le choix naturel pour un timer, mais Azure
# le refuse dans les régions autorisées par la policy de cette souscription :
#   "Requested features are not supported in region" (ExtendedCode 59911)
# malgré des métadonnées qui l'annoncent disponible.
#
# Partager asp-<project> ne coûte rien de plus et convient à une purge
# quotidienne. Contrainte : sur un plan dédié (non-Consumption), un timer
# trigger n'est fiable que si always_on est activé — d'où le réglage plus bas.
# ---------------------------------------------------------------------------
resource "azurerm_linux_function_app" "main" {
  name                = local.function_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.web.id
  https_only          = true
  tags                = var.tags

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  functions_extension_version = "~4"

  identity {
    type = "SystemAssigned"
  }

  site_config {
    # Obligatoire sur un plan dédié : sans always_on, l'app est déchargée après
    # inactivité et le timer trigger ne se déclenche plus. Non supporté sur F1.
    always_on = var.web_app_sku != "F1"

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
