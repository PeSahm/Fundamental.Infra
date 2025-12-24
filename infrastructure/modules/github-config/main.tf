# =============================================================================
# GitHub Configuration Module
# =============================================================================
# This module manages GitHub repository configuration including:
# - Repository settings and import
# - Deployment environments (dev, production)
# - Actions secrets for CI/CD deployment
# =============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------
provider "github" {
  owner = var.github_owner
  token = var.github_token
}

# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------
locals {
  # Repositories that need deployment configuration (environments + secrets)
  deployment_repos = {
    for name, config in var.repositories :
    name => config if config.has_deployments
  }

  # All repository names for iteration
  repo_names = keys(var.repositories)

  # Deployment secrets to create
  deployment_secrets = {
    VPS_IP   = var.vps_ip
    SSH_USER = var.ssh_user
    SSH_KEY  = var.ssh_private_key
  }
}

# -----------------------------------------------------------------------------
# Repository Configuration
# -----------------------------------------------------------------------------
# NOTE: This resource imports/manages existing repositories.
# Set `create_repository = true` in the repository config to create new ones.

resource "github_repository" "repos" {
  for_each = var.repositories

  name        = each.key
  description = each.value.description
  visibility  = each.value.visibility

  # Repository features
  has_issues      = each.value.has_issues
  has_projects    = each.value.has_projects
  has_wiki        = each.value.has_wiki
  has_downloads   = each.value.has_downloads
  has_discussions = each.value.has_discussions

  # Branch protection settings
  allow_merge_commit     = each.value.allow_merge_commit
  allow_squash_merge     = each.value.allow_squash_merge
  allow_rebase_merge     = each.value.allow_rebase_merge
  delete_branch_on_merge = each.value.delete_branch_on_merge

  # Vulnerability alerts
  vulnerability_alerts = each.value.vulnerability_alerts

  # Archive instead of delete
  archive_on_destroy = true

  # Topics/tags
  topics = each.value.topics

  lifecycle {
    # Prevent destruction of repositories
    prevent_destroy = false

    # Ignore changes that might be made outside Terraform
    ignore_changes = [
      auto_init,
      gitignore_template,
      license_template,
    ]
  }
}

# -----------------------------------------------------------------------------
# Repository Environments
# -----------------------------------------------------------------------------
# Create dev and production environments for deployment repos

resource "github_repository_environment" "dev" {
  for_each = local.deployment_repos

  repository  = github_repository.repos[each.key].name
  environment = "dev"

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "dev_branches" {
  for_each = local.deployment_repos

  repository     = github_repository.repos[each.key].name
  environment    = github_repository_environment.dev[each.key].environment
  branch_pattern = "develop"
}

resource "github_repository_environment" "production" {
  for_each = local.deployment_repos

  repository  = github_repository.repos[each.key].name
  environment = "production"

  # Optional: Add reviewers for production deployments
  # reviewers {
  #   users = var.production_reviewers
  # }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "prod_branches" {
  for_each = local.deployment_repos

  repository     = github_repository.repos[each.key].name
  environment    = github_repository_environment.production[each.key].environment
  branch_pattern = "main"
}

# -----------------------------------------------------------------------------
# Actions Secrets (Repository Level)
# -----------------------------------------------------------------------------
# Add deployment secrets to repositories with CI/CD

resource "github_actions_secret" "vps_ip" {
  for_each = local.deployment_repos

  repository      = github_repository.repos[each.key].name
  secret_name     = "VPS_IP"
  plaintext_value = var.vps_ip
}

resource "github_actions_secret" "ssh_user" {
  for_each = local.deployment_repos

  repository      = github_repository.repos[each.key].name
  secret_name     = "SSH_USER"
  plaintext_value = var.ssh_user
}

resource "github_actions_secret" "ssh_key" {
  for_each = local.deployment_repos

  repository      = github_repository.repos[each.key].name
  secret_name     = "SSH_KEY"
  plaintext_value = var.ssh_private_key
}

resource "github_actions_secret" "registry_user" {
  for_each = local.deployment_repos

  repository      = github_repository.repos[each.key].name
  secret_name     = "REGISTRY_USER"
  plaintext_value = var.registry_user
}

resource "github_actions_secret" "registry_password" {
  for_each = local.deployment_repos

  repository      = github_repository.repos[each.key].name
  secret_name     = "REGISTRY_PASSWORD"
  plaintext_value = var.registry_password
}

# -----------------------------------------------------------------------------
# Actions Variables (Repository Level)
# -----------------------------------------------------------------------------
# Non-sensitive configuration as Actions variables

resource "github_actions_variable" "domain" {
  for_each = local.deployment_repos

  repository    = github_repository.repos[each.key].name
  variable_name = "DOMAIN"
  value         = var.domain_name
}

resource "github_actions_variable" "registry" {
  for_each = local.deployment_repos

  repository    = github_repository.repos[each.key].name
  variable_name = "CONTAINER_REGISTRY"
  value         = var.container_registry
}

# -----------------------------------------------------------------------------
# Sentry Configuration
# -----------------------------------------------------------------------------
# Variables and secrets for Sentry error tracking integration

resource "github_actions_variable" "sentry_enabled" {
  for_each = local.deployment_repos

  repository    = github_repository.repos[each.key].name
  variable_name = "SENTRY_ENABLED"
  value         = var.sentry_enabled ? "true" : "false"
}

resource "github_actions_secret" "sentry_dsn" {
  for_each = var.sentry_dsn_configured ? local.deployment_repos : {}

  repository      = github_repository.repos[each.key].name
  secret_name     = "SENTRY_DSN"
  plaintext_value = var.sentry_dsn
}

resource "github_actions_secret" "sentry_auth_token" {
  for_each = var.sentry_auth_token_configured ? local.deployment_repos : {}

  repository      = github_repository.repos[each.key].name
  secret_name     = "SENTRY_AUTH_TOKEN"
  plaintext_value = var.sentry_auth_token
}

resource "github_actions_variable" "sentry_upload_sourcemaps" {
  for_each = local.deployment_repos

  repository    = github_repository.repos[each.key].name
  variable_name = "SENTRY_UPLOAD_SOURCEMAPS"
  value         = var.sentry_upload_sourcemaps ? "true" : "false"
}
