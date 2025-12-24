# =============================================================================
# GitHub Configuration Module - Outputs
# =============================================================================

output "repositories" {
  description = "Map of repository names to their details"
  value = {
    for name, repo in github_repository.repos : name => {
      id        = repo.repo_id
      name      = repo.name
      full_name = repo.full_name
      html_url  = repo.html_url
      ssh_url   = repo.ssh_clone_url
      https_url = repo.http_clone_url
    }
  }
}

output "repository_urls" {
  description = "Map of repository names to their HTML URLs"
  value = {
    for name, repo in github_repository.repos : name => repo.html_url
  }
}

output "deployment_repos" {
  description = "List of repositories configured for deployment"
  value       = keys(local.deployment_repos)
}

output "environments" {
  description = "Map of repositories to their configured environments"
  value = {
    for name in keys(local.deployment_repos) : name => {
      dev        = github_repository_environment.dev[name].environment
      production = github_repository_environment.production[name].environment
    }
  }
}

output "secrets_configured" {
  description = "List of secrets configured for each deployment repository"
  value = {
    for name in keys(local.deployment_repos) : name => [
      "VPS_IP",
      "SSH_USER",
      "SSH_KEY",
      "REGISTRY_USER",
      "REGISTRY_PASSWORD"
    ]
  }
  sensitive = false
}

output "variables_configured" {
  description = "Map of variables configured for each deployment repository"
  value = {
    for name in keys(local.deployment_repos) : name => {
      DOMAIN             = var.domain_name
      CONTAINER_REGISTRY = var.container_registry
      SENTRY_ENABLED     = var.sentry_enabled ? "true" : "false"
    }
  }
}
