output "resource_group_name" {
  value       = azurerm_resource_group.shared.name
  description = "Resource group every other stack deploys into."
}

output "location" {
  value       = azurerm_resource_group.shared.location
  description = "Region of the shared substrate."
}

output "name_suffix" {
  value       = local.suffix
  description = "Random suffix applied to globally unique names this run. Downstream stacks reuse it so a rebuild stays internally consistent."
}

output "log_analytics_workspace_id" {
  value       = azurerm_log_analytics_workspace.shared.id
  description = "Consumed by 10-aks for the cluster's diagnostic settings."
}

output "log_analytics_workspace_name" {
  value       = azurerm_log_analytics_workspace.shared.name
  description = "Workspace name, for the Beat 10 KQL queries."
}

output "application_insights_connection_string" {
  value       = azurerm_application_insights.shared.connection_string
  description = "Injected into the API and worker at deploy time."
  sensitive   = true
}

output "container_registry_name" {
  value       = azurerm_container_registry.shared.name
  description = "Registry name, as passed to `az acr build --registry`."
}

output "container_registry_login_server" {
  value       = azurerm_container_registry.shared.login_server
  description = "Image prefix for the Helm values of every track."
}

output "container_registry_id" {
  value       = azurerm_container_registry.shared.id
  description = "Scope for the AcrPull role assignment granted to the AKS kubelet identity in 10-aks."
}

output "storage_account_name" {
  value       = azurerm_storage_account.shared.name
  description = "Correctly configured account the worker writes reports to."
}

output "planted_storage_account_name" {
  value       = var.plant_iac_findings ? azurerm_storage_account.planted_public[0].name : null
  description = "CF-IAC-040. Null when plant_iac_findings is false."
}
