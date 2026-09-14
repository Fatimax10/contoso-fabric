output "repository_full_name" {
  value       = github_repository.showcase.full_name
  description = "owner/name, as passed to the seeding scripts and `gh repo` commands."
}

output "repository_clone_url_ssh" {
  value       = github_repository.showcase.ssh_clone_url
  description = "Clone URL for pushing the application source."
}

output "default_branch" {
  value       = github_branch_default.main.branch
  description = "Branch the ruleset targets via ~DEFAULT_BRANCH."
}

output "ruleset_id" {
  value       = github_repository_ruleset.main.ruleset_id
  description = "Needed if you add the Copilot bypass actor through the UI and want to import it afterwards."
}

output "copilot_bypass_configured" {
  value       = var.copilot_bypass_actor_id != null
  description = "False means the Copilot coding agent's pushes will be rejected by the ruleset. Check this before demonstrating Beat 4."
}

output "environments" {
  value       = [github_repository_environment.staging.environment, github_repository_environment.production.environment]
  description = "Environment names referenced by the deploy workflow."
}
