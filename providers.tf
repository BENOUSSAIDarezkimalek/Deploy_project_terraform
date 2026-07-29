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
  # Par défaut (mode "legacy"), le provider tente d'enregistrer une longue liste
  # de resource providers Azure à chaque démarrage. Sur cette souscription
  # (Azure for Students, 238 non enregistrés) cela fait stagner le plan plus de
  # 15 minutes — inexploitable en CI.
  #
  # Les seuls resource providers nécessaires ici (Microsoft.Web,
  # Microsoft.Storage, Microsoft.KeyVault, Microsoft.ManagedIdentity) sont déjà
  # enregistrés. Si un apply échoue un jour avec « MissingSubscriptionRegistration » :
  #   az provider register --namespace <Namespace> --wait
  resource_provider_registrations = "none"

  features {
    key_vault {
      purge_soft_delete_on_destroy    = false
      recover_soft_deleted_key_vaults = true
    }
  }
}
