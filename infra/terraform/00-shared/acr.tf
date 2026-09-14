# Basic is a costed decision, not a default. It includes the 10 GiB the showcase
# needs, and ACR Tasks vCPU time is billed at zero on every SKU — which matters
# because each track builds images with `az acr build` rather than a local Docker
# daemon. See docs/cost-model.md.
resource "azurerm_container_registry" "shared" {
  name                = "cr${var.name_prefix}${local.suffix}"
  resource_group_name = azurerm_resource_group.shared.name
  location            = azurerm_resource_group.shared.location
  sku                 = "Basic"

  # Every track authenticates with a workload or federated identity. The admin
  # account is precisely the credential that ends up pasted into a pipeline
  # variable and leaked, which is the opposite of the point of this showcase.
  admin_enabled = false

  tags = local.tags
}
