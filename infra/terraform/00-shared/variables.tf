variable "subscription_id" {
  type        = string
  description = "Azure subscription the showcase deploys into. Set ARM_SUBSCRIPTION_ID instead if you prefer not to keep it in a tfvars file."
}

variable "name_prefix" {
  type        = string
  description = "Short lowercase prefix for every resource name. The registry and storage account names are built from it and are globally unique with tight length limits, so keep it short."
  default     = "ctsofab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,7}$", var.name_prefix))
    error_message = "name_prefix must be 3-8 characters, lowercase letters and digits only, starting with a letter."
  }
}

variable "location" {
  type        = string
  description = "Azure region for the shared substrate. Every track deploys into this one region so that Beats 9 and 10 look identical across tracks."
  default     = "swedencentral"
}

variable "log_retention_days" {
  type        = number
  description = "Log Analytics retention in days. 30 is the included floor; raising it is the easiest way to make this showcase unexpectedly expensive. See docs/cost-model.md."
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days must be between 30 and 730."
  }
}

variable "plant_iac_findings" {
  type        = bool
  description = "Deploy CF-IAC-040, the deliberately insecure storage account, so Beat 8 has a real misconfiguration to detect. Set this to false if this stack is ever reused outside the showcase."
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Additional tags merged over the defaults. Use this for the customer name or a cost centre."
  default     = {}
}
