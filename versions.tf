# ---------------------------------------------------------------------------
# Versions de Terraform et des providers
# ---------------------------------------------------------------------------
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # ------------------------------------------------------------------------
  # State distant dans Azure Storage.
  # Le compte de stockage est créé automatiquement par la pipeline
  # (étape "Ensure tfstate storage"), donc rien à bootstrapper à la main.
  # Les valeurs sont fournies au `terraform init` via -backend-config.
  # ------------------------------------------------------------------------
  backend "azurerm" {
    container_name = "tfstate"
    key            = "agent-pa.tfstate"
    # resource_group_name  = fourni via -backend-config (projet_annuel)
    # storage_account_name = fourni via -backend-config (voir le workflow)
  }
}
