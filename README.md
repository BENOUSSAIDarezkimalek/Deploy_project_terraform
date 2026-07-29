# Infrastructure Azure — Agent PA (Mail Manager)

Terraform déploie **uniquement les ressources Azure**. Le déploiement du code
applicatif est géré par une pipeline séparée.

Une seule pipeline ici, `terraform.yml`, avec deux jobs :

| Job | Déclenchement |
|-----|---------------|
| `plan` | automatique (push sur `main` touchant `infra/`, PR, ou manuel) |
| `apply` | **approbation manuelle requise** |

## Ce qui est créé

Tout est regroupé dans **un seul groupe de ressources neuf** (`rg-mailmanager`
par défaut), créé par Terraform :

| Ressource | Rôle |
|-----------|------|
| Resource Group | contient tout le projet |
| App Service Plan + Web App (Linux, Python) | héberge l'app NiceGUI |
| Storage Account + container `mails-anonymized` | mails anonymisés + backing store Function |
| Key Vault | secrets de l'application |
| Function App (sur le même plan que la Web App) | purge quotidienne des blobs (le batch) |

> **Rien n'est supprimé.** Les ressources créées manuellement dans
> `projet_annuel` et `batchdeletelastmail` ne sont ni lues, ni modifiées, ni
> détruites. Il y aura des doublons le temps que tu valides la nouvelle
> installation — tu supprimeras l'ancienne à la main quand tu voudras.
>
> Les noms portent un **suffixe fixe** (`tf` par défaut), ce qui les
> distingue des ressources existantes tout en restant prévisibles :
>
> | Ressource | Nom |
> |-----------|-----|
> | Web App | `mailmanager-app-tf` |
> | Function App | `mailmanager-func-tf` |
> | Storage Account | `mailmanagersttf` |
> | Key Vault | `mailmanager-kv-tf` |
>
> Change `name_suffix` dans `terraform.tfvars` si l'un de ces noms est déjà
> pris (les Storage Accounts, Key Vaults et App Services ont des noms uniques
> à l'échelle mondiale, pas seulement dans ton abonnement).

Les secrets sont écrits dans le Key Vault et exposés aux applications via des
références `@Microsoft.KeyVault(...)` dans leurs App Settings. Chaque app y
accède avec son identité managée (rôle *Key Vault Secrets User*).

---

## Mise en route (4 étapes, une seule fois)

### 1. Créer le service principal

```bash
SUB_ID=$(az account show --query id -o tsv)

az ad sp create-for-rbac \
  --name "gh-agent-pa-infra" \
  --role Owner \
  --scopes "/subscriptions/$SUB_ID"
```

> Le rôle **Owner** est nécessaire : Terraform crée des attributions de rôle
> RBAC (accès des identités au Key Vault). Sur *Azure for Students* tu es
> normalement Owner de ta souscription. Si la commande échoue
> (« Insufficient privileges »), ton établissement bloque la création
> d'app registrations.

Note les valeurs renvoyées : `appId`, `password`, `tenant`.

### 2. Renseigner les GitHub Secrets

Dans **Settings → Secrets and variables → Actions** :

**Accès Azure**
| Secret | Valeur |
|--------|--------|
| `AZURE_CLIENT_ID` | `appId` |
| `AZURE_CLIENT_SECRET` | `password` |
| `AZURE_TENANT_ID` | `tenant` |
| `AZURE_SUBSCRIPTION_ID` | ta souscription |

**Secrets applicatifs (écrits dans le Key Vault)**
| Secret | Requis |
|--------|:------:|
| `GROQ_API_KEY` | ✅ |
| `WHATSAPP_PHONE` | ⬜ optionnel |
| `CALLMEBOT_API_KEY` | ⬜ optionnel |

> `SESSION_SECRET` n'est pas à fournir : Terraform en génère un aléatoire.
>
> **Les identifiants Gmail ne sont pas ici** : chaque utilisateur saisit son
> adresse et son mot de passe d'application dans le formulaire de connexion
> de l'app. Ils vivent dans sa session (`app.storage.user`), jamais dans
> l'infrastructure.

### 3. Créer l'environnement d'approbation

**Settings → Environments → New environment**, nommé exactement
`production`. Coche **Required reviewers**, ajoute-toi, puis
**Save protection rules**.

> ⚠️ Sans cette étape, le job `apply` s'exécutera **sans rien demander**.
> C'est la règle de protection — pas le fichier YAML — qui rend l'apply manuel.
>
> Sur un repo **privé** avec un compte GitHub Free, les règles de protection
> ne sont pas disponibles. Solutions : rendre le repo public, activer GitHub
> Pro (gratuit via le *Student Developer Pack*), ou utiliser la variante en
> bas de page.

### 4. Choisir un nom unique pour le state

En haut de `.github/workflows/terraform.yml`, remplace `TFSTATE_SA` par un nom
**unique dans tout Azure** (minuscules/chiffres, ≤ 24 caractères).

Le groupe `rg-tfstate` qui l'héberge est créé automatiquement par la pipeline :
tu n'as rien à préparer côté Azure.

---

## Déployer

**Actions → Terraform (infra) → Run workflow**, puis :

1. le job `plan` s'exécute et publie le détail dans le résumé du run ;
2. le run se met en pause avec un bouton **Review deployments** ;
3. tu relis, tu approuves, `apply` crée les ressources ;
4. les noms générés s'affichent dans le résumé (section *Ressources déployées*).

Ensuite, toute modification dans `infra/` relance automatiquement le plan et
attend ton approbation.

---

## Passer le relais à ta pipeline de déploiement de code

Les noms étant générés avec un suffixe aléatoire, récupère-les à la fin de
l'apply (ils sont affichés dans le résumé du run, section *Ressources
déployées*) :

| Output | Utilité pour ta CI/CD |
|--------|----------------------|
| `web_app_name` | nom de la Web App cible |
| `function_app_name` | nom de la Function App cible |
| `resource_group_name` | le groupe qui contient les deux |
| `web_app_url` | URL publique de l'app |

Ou en local, après un `terraform init` :
```bash
terraform output
```

**Si ta pipeline utilise un publish profile** :
```bash
az webapp deployment list-publishing-profiles \
  --name <web_app_name> --resource-group rg-mailmanager --xml
```
Colle le résultat dans le secret `AZURE_WEBAPP_PUBLISH_PROFILE` de ton autre
projet.

**Si ta pipeline utilise un service principal**, réutilise celui de l'étape 1,
ou crée-lui des droits réduits sur le seul groupe du projet :
```bash
az role assignment create --assignee <appId> \
  --role "Website Contributor" \
  --scope "/subscriptions/$SUB_ID/resourceGroups/rg-mailmanager"
```

**Les noms sont prévisibles** : `mailmanager-app-tf` et
`mailmanager-func-tf` avec les valeurs par défaut. Tu peux donc les écrire en
dur dans ta pipeline de code sans attendre le premier apply.

Terraform ignore volontairement `WEBSITE_RUN_FROM_PACKAGE` sur les deux apps :
ta pipeline de code peut déployer librement sans qu'un `apply` ultérieur ne
défasse son travail.

---

## Réglages utiles

**Le `SESSION_SECRET` est critique ici** — l'app conserve le mot de passe
d'application Gmail de chaque utilisateur dans `app.storage.user`, un cookie
signé avec ce secret. Terraform en génère un aléatoire de 48 caractères et le
stocke dans le Key Vault. Ne le remplace pas par une valeur devinable.

**Passer la Web App en gratuit (F1)** — pour économiser le crédit étudiant,
dans `terraform.tfvars` :
```hcl
web_app_sku = "F1"
```
`always_on` est automatiquement désactivé sur F1 (l'app s'endort après
inactivité ; premier chargement plus lent).

**Variante sans environnement d'approbation** — remplace dans `terraform.yml`
la ligne `environment: production` du job `apply` par :
```yaml
    if: github.event_name == 'workflow_dispatch'
```
et retire la condition `if:` existante. L'apply ne partira alors que sur
lancement manuel du workflow.

---

## Dépannage

**Le job `apply` ne demande pas d'approbation** — l'environnement `production`
n'existe pas ou n'a pas de *required reviewer* (étape 3).

**L'app ne lit pas ses secrets juste après la création** — la propagation RBAC
prend 1 à 2 minutes :
```bash
az webapp restart      --name <web_app_name>      --resource-group rg-mailmanager
az functionapp restart --name <function_app_name> --resource-group rg-mailmanager
```

**« name is not available » / « already exists »** — un nom est déjà pris par
quelqu'un d'autre dans Azure. Change `name_suffix` dans `terraform.tfvars`
(par ex. `tf2`) : tous les noms sont régénérés d'un coup.

**« vault already exists in soft-deleted state »** — tu as détruit puis
recréé l'infra en moins de 7 jours. Avec un nom fixe, Azure conserve le Key
Vault supprimé. C'est déjà géré (`recover_soft_deleted_key_vaults = true`
dans `providers.tf`) : Terraform le récupère au lieu d'échouer.

**Warning `enable_rbac_authorization` déprécié** — normal, sans impact (le
nouveau nom sera adopté avec azurerm v5).
