# The account the worker actually writes report output to. It is configured
# correctly, and it is in the same file as CF-IAC-040 on purpose — a scanner
# flagging one and not the other is far more convincing than a lone bad resource.
resource "azurerm_storage_account" "shared" {
  name                = "st${var.name_prefix}${local.suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"

  tags = local.tags
}

resource "azurerm_storage_container" "reports" {
  name                  = "reports"
  storage_account_id    = azurerm_storage_account.shared.id
  container_access_type = "private"
}

# ------------------------------------------------------------------------------
# CF-IAC-040 — PLANTED MISCONFIGURATION. Do not "fix" this resource.
#
# It deliberately allows anonymous blob reads, accepts cleartext HTTP, and sets a
# TLS floor that has been out of support for years. It exists so Beat 8 can show
# an IaC scanner and Defender for Cloud finding a real misconfiguration in real
# state, rather than a screenshot of one.
#
# The account holds no data and is guarded by var.plant_iac_findings. Remediation
# is performed live during Beat 11: invert the three attributes below, re-apply,
# and show the alert closing. See seeds/FINDINGS.md.
# ------------------------------------------------------------------------------
resource "azurerm_storage_account" "planted_public" {
  count = var.plant_iac_findings ? 1 : 0

  name                = "st${var.name_prefix}pub${local.suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location

  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = true     # CF-IAC-040 (a) anonymous blob access
  https_traffic_only_enabled      = false    # CF-IAC-040 (b) cleartext HTTP permitted
  min_tls_version                 = "TLS1_0" # CF-IAC-040 (c) obsolete TLS floor

  tags = merge(local.tags, {
    finding = "CF-IAC-040"
    beat    = "8"
    warning = "deliberately-insecure-do-not-copy"
  })
}

resource "azurerm_storage_container" "planted_public" {
  count = var.plant_iac_findings ? 1 : 0

  name                  = "public-reports"
  storage_account_id    = azurerm_storage_account.planted_public[0].id
  container_access_type = "blob"
}
