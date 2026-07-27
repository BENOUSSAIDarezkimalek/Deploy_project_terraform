# ---------------------------------------------------------------------------
# Configuration du provider AzureRM
#
# Authentification via les variables d'environnement ARM_* :
#   - En CI    : service principal (ARM_CLIENT_ID, ARM_CLIENT_SECRET,
#                ARM_TENANT_ID, ARM_SUBSCRIPTION_ID) -> alimentées par les
#                GitHub Secrets dans le workflow.
#   - En local : `az login` suffit (le provider lit le contexte az CLI).
# ---------------------------------------------------------------------------
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}
