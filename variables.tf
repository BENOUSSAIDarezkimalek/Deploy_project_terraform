# ===========================================================================
# VARIABLES GÉNÉRALES
# ===========================================================================

variable "project" {
  description = "Préfixe court utilisé pour nommer les ressources (lowercase, sans espaces)."
  type        = string
  default     = "mailmanager"

  validation {
    condition     = can(regex("^[a-z0-9]{3,15}$", var.project))
    error_message = "project doit contenir 3 à 15 caractères en minuscules/chiffres uniquement."
  }
}

# ===========================================================================
# GROUPE DE RESSOURCES (créé par Terraform, dédié au projet)
# ===========================================================================

variable "resource_group_name" {
  description = "Nom du groupe de ressources à créer. Tout le projet y est déployé."
  type        = string
  default     = "rg-mailmanager"
}

# La policy « Allowed resource deployment regions » de cette souscription
# n'autorise que : norwayeast, uaenorth, spaincentral, swedencentral,
# germanywestcentral. Toute autre région échoue avec RequestDisallowedByAzure.
# Liste à jour : az policy assignment list \
#   --query "[?displayName=='Allowed resource deployment regions'].parameters"
variable "location" {
  description = "Région Azure. Doit faire partie des régions autorisées par la policy de la souscription."
  type        = string
  default     = "spaincentral"

  validation {
    condition = contains([
      "norwayeast", "uaenorth", "spaincentral",
      "swedencentral", "germanywestcentral",
    ], var.location)
    error_message = "Région refusée par la policy Azure de la souscription. Autorisées : norwayeast, uaenorth, spaincentral, swedencentral, germanywestcentral."
  }
}

variable "name_suffix" {
  description = "Suffixe fixe ajouté aux noms des ressources (permet de coexister avec l'existant)."
  type        = string
  default     = "tf"

  validation {
    condition     = can(regex("^[a-z0-9]{1,8}$", var.name_suffix))
    error_message = "name_suffix doit contenir 1 à 8 caractères en minuscules/chiffres."
  }
}

variable "tags" {
  description = "Tags appliqués aux ressources créées."
  type        = map(string)
  default = {
    project    = "agent-pa"
    managed_by = "terraform"
  }
}

# ===========================================================================
# NOMS DES APPS (uniques dans tout Azure)
# Par défaut : <project>-app-<name_suffix>, ce qui évite la collision avec
# les ressources déjà créées à la main.
# ===========================================================================

variable "web_app_name" {
  description = "Nom global de la Web App. Vide = <project>-app-<name_suffix>."
  type        = string
  default     = ""
}

variable "function_app_name" {
  description = "Nom global de la Function App. Vide = <project>-func-<name_suffix>."
  type        = string
  default     = ""
}

# ===========================================================================
# DIMENSIONNEMENT
# ===========================================================================

variable "web_app_sku" {
  description = "SKU du plan App Service de la Web App. F1 = gratuit (sans always_on), B1 ≈ 13€/mois, B2 ≈ 26€/mois."
  type        = string
<<<<<<< HEAD
  default     = "B3"
=======
  default     = "B2"
>>>>>>> c733150507b44132332ee87bc6cc3c1a1b54b195
}

variable "python_version" {
  description = "Version de Python pour la Web App et la Function App."
  type        = string
  default     = "3.11"
}

# ===========================================================================
# CONFIGURATION APPLICATIVE NON SENSIBLE (-> App Settings directs)
# ===========================================================================

variable "groq_model" {
  description = "Modèle Groq utilisé par l'app."
  type        = string
  default     = "llama-3.3-70b-versatile"
}

variable "mail_max_results" {
  description = "Nombre de mails chargés par défaut."
  type        = string
  default     = "10"
}

variable "mail_preview_length" {
  description = "Longueur de l'extrait de mail affiché."
  type        = string
  default     = "220"
}

variable "mail_retention_days" {
  description = "Fenêtre de rétention des mails (jours) côté application."
  type        = string
  default     = "30"
}

variable "debug" {
  description = "Active les logs verbeux de l'app (true/false)."
  type        = string
  default     = "false"
}

variable "blob_container_name" {
  description = "Nom du container Blob où sont stockés les mails anonymisés."
  type        = string
  default     = "mails-anonymized"
}

# ===========================================================================
# CONFIGURATION DE LA FUNCTION (purge quotidienne)
# ===========================================================================

variable "retention_cron" {
  description = "Planification NCRONTAB de la purge. Défaut : tous les jours à 03:00 UTC."
  type        = string
  default     = "0 0 3 * * *"
}

variable "function_retention_days" {
  description = "Nombre de jours au-delà duquel la Function supprime les blobs."
  type        = string
  default     = "30"
}

# ===========================================================================
# SECRETS (-> Key Vault). Fournis via TF_VAR_* (GitHub Secrets) en CI.
# Un secret laissé vide n'est pas créé.
# ===========================================================================

variable "groq_api_key" {
  description = "Clé API Groq (gsk_...)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "session_secret" {
  description = "Secret de session NiceGUI. Vide = généré automatiquement."
  type        = string
  sensitive   = true
  default     = ""
}

variable "whatsapp_phone" {
  description = "Numéro WhatsApp pour les notifications (optionnel)."
  type        = string
  sensitive   = true
  default     = ""
}

variable "callmebot_api_key" {
  description = "Clé API CallMeBot pour WhatsApp (optionnel)."
  type        = string
  sensitive   = true
  default     = ""
}
