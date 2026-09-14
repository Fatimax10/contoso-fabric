terraform {
  required_version = ">= 1.9.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# Authentication comes from GITHUB_TOKEN. Use a fine-grained token or a GitHub App
# installation token with Administration: read/write on the organisation — a classic
# PAT with `repo` alone cannot create rulesets.
provider "github" {
  owner = var.organization
}
