# ===========================================================================
# KEY VAULT + SECRETS (dans le RG de l'app)
# ===========================================================================

# Génère un session_secret robuste si l'utilisateur n'en fournit pas.
resource "random_password" "session_secret" {
  count   = var.session_secret == "" ? 1 : 0
  length  = 48
  special = false
}

locals {
  session_secret_value = var.session_secret != "" ? var.session_secret : random_password.session_secret[0].result

  # Secrets candidats : nom du secret KV => valeur.
  # Les valeurs vides sont filtrées (Key Vault refuse les valeurs vides).
  candidate_secrets = {
    "groq-api-key"                    = var.groq_api_key
    "session-secret"                  = local.session_secret_value
    "whatsapp-phone"                  = var.whatsapp_phone
    "callmebot-api-key"               = var.callmebot_api_key
    "azure-storage-connection-string" = azurerm_storage_account.main.primary_connection_string
  }

  secrets = { for k, v in local.candidate_secrets : k => v if v != "" }

  active_secret_names = toset(compact([
    nonsensitive(var.groq_api_key != "") ? "groq-api-key" : "",
    "session-secret",
    nonsensitive(var.whatsapp_phone != "") ? "whatsapp-phone" : "",
    nonsensitive(var.callmebot_api_key != "") ? "callmebot-api-key" : "",
    "azure-storage-connection-string",
  ]))
}

# ---------------------------------------------------------------------------
# Key Vault (mode RBAC)
# ---------------------------------------------------------------------------
resource "azurerm_key_vault" "main" {
  name                       = local.key_vault_name
  resource_group_name        = azurerm_resource_group.main.name
  location                   = azurerm_resource_group.main.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  purge_protection_enabled   = false
  soft_delete_retention_days = 7
  tags                       = var.tags
}

# ---------------------------------------------------------------------------
# L'identité qui exécute Terraform doit pouvoir écrire les secrets.
# (Le service principal de la CI a le rôle Owner sur la subscription, ce qui
#  lui permet de créer ce role assignment.)
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "tf_kv_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# Laisse la propagation RBAC se faire avant l'écriture des secrets.
resource "time_sleep" "wait_rbac" {
  depends_on      = [azurerm_role_assignment.tf_kv_officer]
  create_duration = "60s"
}

# ---------------------------------------------------------------------------
# Secrets (un par entrée non vide de local.secrets)
# ---------------------------------------------------------------------------
resource "azurerm_key_vault_secret" "app" {
  for_each     = local.active_secret_names
  name         = each.value
  value        = local.candidate_secrets[each.value]
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [
    azurerm_role_assignment.tf_kv_officer,
    time_sleep.wait_rbac,
  ]
}

# ---------------------------------------------------------------------------
# Références Key Vault à injecter dans les App Settings.
# Format : @Microsoft.KeyVault(SecretUri=<uri sans version>)
# Seuls les secrets réellement créés produisent une référence.
# ---------------------------------------------------------------------------
locals {
  app_secret_env_map = {
    "GROQ_API_KEY"                    = "groq-api-key"
    "SESSION_SECRET"                  = "session-secret"
    "WHATSAPP_PHONE"                  = "whatsapp-phone"
    "CALLMEBOT_API_KEY"               = "callmebot-api-key"
    "AZURE_STORAGE_CONNECTION_STRING" = "azure-storage-connection-string"
  }

  app_kv_refs = {
    for env_name, secret_name in local.app_secret_env_map :
    env_name => "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.app[secret_name].versionless_id})"
    if contains(keys(local.secrets), secret_name)
  }
}
