variable "organization" {
  type        = string
  description = "GitHub organisation that hosts the showcase. This stack does not create the organisation — GHEC organisations are created against an enterprise account, which is a billing operation Terraform has no business performing."
}

variable "repository_name" {
  type        = string
  description = "Repository name for the showcase."
  default     = "contoso-fabric"
}

variable "repository_visibility" {
  type        = string
  description = "Repository visibility. Keep this private: several beats depend on features that behave differently, or are free, on public repositories, and a private repository is what the customer will actually have."
  default     = "private"

  validation {
    condition     = contains(["private", "internal", "public"], var.repository_visibility)
    error_message = "repository_visibility must be one of: private, internal, public."
  }
}

variable "required_status_checks" {
  type        = list(string)
  description = "Status check contexts that must pass before main accepts a merge. These must match the job names in .github/workflows/ci.yml exactly — a typo here does not fail, it silently blocks every pull request forever."
  default = [
    "dotnet / build & test",
    "node / build & typecheck",
    "python / lint & test",
  ]
}

variable "copilot_bypass_actor_id" {
  type        = number
  description = <<-EOT
    Integration (GitHub App) ID of the Copilot coding agent, added to the ruleset as a
    bypass actor. Without it the agent's push to its own branch is rejected by the
    pull_request rule and the task appears to silently do nothing — the single most
    common Track 1 failure.

    This ID is per-installation and is deliberately not hardcoded. Retrieve it with:

      gh api "/orgs/<org>/installations" \
        --jq '.installations[] | select(.app_slug=="copilot-swe-agent") | .app_id'

    Leave null to create the ruleset with no bypass actors, then add Copilot through
    Settings -> Rules and import the change.
  EOT
  default     = null
}

variable "production_reviewers" {
  type        = list(string)
  description = "GitHub usernames required to approve a deployment to the production environment. Beat 9 needs at least one, or the approval gate never appears."
  default     = []
}

variable "production_wait_timer_minutes" {
  type        = number
  description = "Delay before a production deployment proceeds. Zero for a live demo — nobody watches a timer on stage."
  default     = 0

  validation {
    condition     = var.production_wait_timer_minutes >= 0 && var.production_wait_timer_minutes <= 43200
    error_message = "production_wait_timer_minutes must be between 0 and 43200."
  }
}
