resource "github_repository" "showcase" {
  name        = var.repository_name
  description = "Contoso Fabric — the application under demonstration across all five showcase tracks."
  visibility  = var.repository_visibility

  has_issues   = true
  has_projects = true
  has_wiki     = false

  # Squash keeps the history readable when the Copilot coding agent's branch lands
  # in Beat 4. Rebase is off because it makes the merge-method rule in the ruleset
  # and the button in the UI disagree, which invites a question you cannot answer
  # quickly on stage.
  allow_squash_merge     = true
  allow_merge_commit     = true
  allow_rebase_merge     = false
  allow_auto_merge       = true
  delete_branch_on_merge = true

  # Beat 1 seeds this repository with a real backlog, so it must not be created
  # empty-and-unborn — the seeding scripts push before the first commit exists.
  auto_init = true

  dynamic "security_and_analysis" {
    # These blocks are only settable on non-public repositories. On a public
    # repository the features are always on and the API rejects the request.
    for_each = var.repository_visibility == "public" ? [] : [1]

    content {
      secret_scanning {
        status = "enabled"
      }
      secret_scanning_push_protection {
        status = "enabled"
      }
    }
  }

  lifecycle {
    # Losing the demo repository to a `terraform destroy` typo costs a rebuild of
    # every seeded issue, project item, and branch.
    prevent_destroy = true
  }
}

# Beat 6 opens with Dependabot alerts against the planted CF-DEP-02x dependencies.
# Without this they never appear.
resource "github_repository_vulnerability_alerts" "showcase" {
  repository = github_repository.showcase.name
  enabled    = true
}
