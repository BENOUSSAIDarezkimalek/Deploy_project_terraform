# ===========================================================================
# GROUPE DE RESSOURCES + STORAGE
# Tout le projet (app, batch, stockage, secrets) vit dans un seul RG,
# créé et géré par Terraform. Les ressources existantes créées à la main
# ne sont pas touchées.
# ===========================================================================

data "azurerm_client_config" "current" {}

locals {
  suffix = var.name_suffix

  storage_account_name = "${var.project}st${local.suffix}"   # <=24, lowercase
  key_vault_name       = "${var.project}-kv-${local.suffix}" # <=24

  # Noms des apps : dérivés du suffixe, surchargeables via tfvars.
  web_app_name      = var.web_app_name != "" ? var.web_app_name : "${var.project}-app-${local.suffix}"
  function_app_name = var.function_app_name != "" ? var.function_app_name : "${var.project}-func-${local.suffix}"
}

# ---------------------------------------------------------------------------
# Resource Group (nouveau, dédié au projet)
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

# ---------------------------------------------------------------------------
# Storage Account
# Sert à la fois :
#   - au stockage des mails anonymisés (container mails-anonymized)
#   - de backing store à la Function App (AzureWebJobsStorage)
# ---------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = var.tags
}

# Container où l'app dépose les mails anonymisés
resource "azurerm_storage_container" "mails" {
  name                  = var.blob_container_name
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}
