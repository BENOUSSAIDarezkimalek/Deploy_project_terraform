# ===========================================================================
# OUTPUTS
# Ces valeurs sont à reporter dans la pipeline qui déploie le code.
# ===========================================================================

output "resource_group_name" {
  description = "Groupe de ressources créé (contient tout le projet)."
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Région des ressources."
  value       = azurerm_resource_group.main.location
}

output "web_app_name" {
  description = "Nom de la Web App — à utiliser dans la pipeline de déploiement du code."
  value       = azurerm_linux_web_app.main.name
}

output "web_app_url" {
  description = "URL publique de l'application."
  value       = "https://${azurerm_linux_web_app.main.default_hostname}"
}

output "function_app_name" {
  description = "Nom de la Function App — à utiliser dans la pipeline de déploiement du code."
  value       = azurerm_linux_function_app.main.name
}

output "storage_account_name" {
  description = "Nom du Storage Account."
  value       = azurerm_storage_account.main.name
}

output "blob_container_name" {
  description = "Container des mails anonymisés."
  value       = azurerm_storage_container.mails.name
}

output "key_vault_name" {
  description = "Nom du Key Vault."
  value       = azurerm_key_vault.main.name
}

output "created_secrets" {
  description = "Liste des secrets créés dans le Key Vault."
  value       = sort(keys(local.secrets))
}
