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
  }

  # State is local by design. This stack is rebuilt from nothing between customers,
  # and a remote backend would mean a chicken-and-egg storage account that lives
  # outside the lifecycle everything else follows. See README.md if you need shared
  # state because more than one person is driving the demo.
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {
    resource_group {
      # The showcase is torn down and rebuilt on purpose. Let destroy mean destroy,
      # rather than failing because a track left something behind.
      prevent_deletion_if_contains_resources = false
    }
  }
}
