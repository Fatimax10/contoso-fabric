data "github_user" "production_reviewers" {
  for_each = toset(var.production_reviewers)
  username = each.value
}

# Stated explicitly rather than inferred. The ruleset targets ~DEFAULT_BRANCH, so
# whatever this is, is what gets protected.
resource "github_branch_default" "main" {
  repository = github_repository.showcase.name
  branch     = "main"
}

# Deployed to freely by CD. The contrast with production is the point: the same
# workflow reaches one environment unattended and stops at the other.
resource "github_repository_environment" "staging" {
  repository  = github_repository.showcase.name
  environment = "staging"
}

resource "github_repository_environment" "production" {
  repository  = github_repository.showcase.name
  environment = "production"

  wait_timer = var.production_wait_timer_minutes

  dynamic "reviewers" {
    for_each = length(var.production_reviewers) > 0 ? [1] : []

    content {
      users = [for u in data.github_user.production_reviewers : u.id]
    }
  }

  deployment_branch_policy {
    protected_branches     = true
    custom_branch_policies = false
  }
}
