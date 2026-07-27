# ===========================================================================
# WEB APP (application NiceGUI - mail_manager) — RG projet_annuel
# ===========================================================================

resource "azurerm_service_plan" "web" {
  name                = "asp-${var.project}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.web_app_sku
  tags                = var.tags
}

# ---------------------------------------------------------------------------
# Web App
#
# Démarrage : l'app NiceGUI lit le port via os.getenv("PORT"), qu'App Service
# injecte automatiquement. On lance donc directement le script Python
# (on n'utilise PAS startup.sh, qui passe des arguments Streamlit
# incompatibles avec NiceGUI).
#
# always_on n'est pas supporté sur le plan gratuit F1 : on l'active seulement
# hors F1.
# ---------------------------------------------------------------------------
resource "azurerm_linux_web_app" "main" {
  name                = local.web_app_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_service_plan.web.location
  service_plan_id     = azurerm_service_plan.web.id
  https_only          = true
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on        = var.web_app_sku != "F1"
    ftps_state       = "Disabled"
    app_command_line = "python mail_manager/nicegui_app.py"

    application_stack {
      python_version = var.python_version
    }
  }

  app_settings = merge(
    {
      # ---- Config non sensible (App Settings directs) ----
      "GROQ_MODEL"              = var.groq_model
      "GOOGLE_REDIRECT_URI"     = "https://${local.web_app_name}.azurewebsites.net"
      "STREAMLIT_REDIRECT_URI"  = "https://${local.web_app_name}.azurewebsites.net"
      "MAIL_MAX_RESULTS"        = var.mail_max_results
      "MAIL_PREVIEW_LENGTH"     = var.mail_preview_length
      "MAIL_RETENTION_DAYS"     = var.mail_retention_days
      "DEBUG"                   = var.debug
      "AZURE_STORAGE_CONTAINER" = var.blob_container_name
      "AZURE_STORAGE_ENABLED"   = "true"

      # ---- Build : Oryx installe requirements.txt au déploiement ----
      "SCM_DO_BUILD_DURING_DEPLOYMENT" = "true"
    },
    # ---- Secrets référencés depuis Key Vault ----
    local.app_kv_refs,
  )

  lifecycle {
    # Le code est déployé par une CI/CD externe : on ignore les réglages
    # qu'elle positionne, pour que Terraform ne les écrase pas à chaque apply.
    ignore_changes = [
      site_config[0].application_stack,
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# Autorise l'identité de la Web App à LIRE les secrets du Key Vault
resource "azurerm_role_assignment" "web_kv_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}
