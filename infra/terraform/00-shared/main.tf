locals {
  suffix = random_string.suffix.result

  tags = merge({
    showcase   = "contoso-fabric"
    stack      = "00-shared"
    managed-by = "terraform"
  }, var.tags)
}

# Registry and storage account names are globally unique. A fresh suffix on every
# rebuild is deliberate: it means a destroyed demo never collides with the next one,
# and it removes the soft-delete waiting game entirely.
resource "random_string" "suffix" {
  length  = 6
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_resource_group" "shared" {
  name     = "rg-${var.name_prefix}-shared"
  location = var.location
  tags     = local.tags
}

# One workspace for every track. Beat 10 tells the same story five times over, and
# it only lands if the query being run is visibly the same query each time.
resource "azurerm_log_analytics_workspace" "shared" {
  name                = "log-${var.name_prefix}-${local.suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.tags
}

resource "azurerm_application_insights" "shared" {
  name                = "appi-${var.name_prefix}-${local.suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  workspace_id        = azurerm_log_analytics_workspace.shared.id
  application_type    = "web"
  tags                = local.tags
}
