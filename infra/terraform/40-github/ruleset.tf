# Mirrors seeds/rulesets/main-protection.json. If you change one, change the other:
# the JSON is what gets imported by hand on tracks that have no Terraform provider,
# and a drift between them is a drift between what the tracks actually enforce.
resource "github_repository_ruleset" "main" {
  name        = "main protection"
  repository  = github_repository.showcase.name
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = ["~DEFAULT_BRANCH"]
      exclude = []
    }
  }

  dynamic "bypass_actors" {
    for_each = var.copilot_bypass_actor_id == null ? [] : [var.copilot_bypass_actor_id]

    content {
      actor_id    = bypass_actors.value
      actor_type  = "Integration"
      bypass_mode = "always"
    }
  }

  rules {
    deletion         = true
    non_fast_forward = true

    pull_request {
      required_approving_review_count   = 1
      dismiss_stale_reviews_on_push     = true
      require_code_owner_review         = false
      require_last_push_approval        = false
      required_review_thread_resolution = true
    }

    required_status_checks {
      # Require the branch to be up to date with main before merging. This is what
      # makes Beat 7 show a re-run rather than a stale green tick.
      strict_required_status_checks_policy = true

      dynamic "required_check" {
        for_each = var.required_status_checks

        content {
          context = required_check.value
        }
      }
    }
  }
}
