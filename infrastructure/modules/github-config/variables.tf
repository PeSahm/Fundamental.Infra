# =============================================================================
# GitHub Configuration Module - Variables
# =============================================================================

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

variable "github_token" {
  description = "GitHub Personal Access Token with repo and admin permissions"
  type        = string
  sensitive   = true
}

variable "github_owner" {
  description = "GitHub organization or user that owns the repositories"
  type        = string
}

# -----------------------------------------------------------------------------
# Deployment Configuration
# -----------------------------------------------------------------------------

variable "vps_ip" {
  description = "IP address of the VPS for deployment"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.vps_ip))
    error_message = "The vps_ip must be a valid IPv4 address."
  }
}

variable "ssh_user" {
  description = "SSH username for deployment connections"
  type        = string
  default     = "deploy"
}

variable "ssh_private_key" {
  description = "SSH private key for deployment (base64 encoded recommended)"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The domain name for the application"
  type        = string
  default     = "academind.ir"
}

variable "container_registry" {
  description = "Container registry URL"
  type        = string
  default     = "registry.academind.ir"
}

variable "registry_user" {
  description = "Username for container registry authentication"
  type        = string
  default     = ""
}

variable "registry_password" {
  description = "Password for container registry authentication"
  type        = string
  sensitive   = true
  default     = ""
}

# -----------------------------------------------------------------------------
# Sentry Configuration
# -----------------------------------------------------------------------------

variable "sentry_enabled" {
  description = "Enable Sentry integration for error tracking"
  type        = bool
  default     = false
}

variable "sentry_dsn" {
  description = "Sentry DSN for frontend error tracking"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sentry_auth_token" {
  description = "Sentry auth token for source map uploads"
  type        = string
  sensitive   = true
  default     = ""
}

variable "sentry_dsn_configured" {
  description = "Whether Sentry DSN is configured (non-sensitive flag for for_each)"
  type        = bool
  default     = false
}

variable "sentry_auth_token_configured" {
  description = "Whether Sentry auth token is configured (non-sensitive flag for for_each)"
  type        = bool
  default     = false
}

variable "sentry_upload_sourcemaps" {
  description = "Enable Sentry source map uploads (requires sentry_auth_token)"
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Repository Configuration
# -----------------------------------------------------------------------------

variable "repositories" {
  description = "Map of repository configurations"
  type = map(object({
    description            = string
    visibility             = optional(string, "public")
    has_issues             = optional(bool, true)
    has_projects           = optional(bool, true)
    has_wiki               = optional(bool, false)
    has_downloads          = optional(bool, true)
    has_discussions        = optional(bool, false)
    allow_merge_commit     = optional(bool, true)
    allow_squash_merge     = optional(bool, true)
    allow_rebase_merge     = optional(bool, true)
    delete_branch_on_merge = optional(bool, true)
    vulnerability_alerts   = optional(bool, true)
    has_deployments        = optional(bool, false)
    topics                 = optional(list(string), [])
  }))

  default = {
    "Fundamental.Backend" = {
      description     = "ASP.NET Core backend API for Fundamental application"
      has_deployments = true
      topics          = ["dotnet", "aspnetcore", "api", "backend"]
    }
    "Fundamental.FrontEnd" = {
      description     = "Angular frontend for Fundamental application"
      has_deployments = true
      topics          = ["angular", "typescript", "frontend"]
    }
    "Fundamental.Infra" = {
      description     = "Infrastructure as Code - Ansible, Helm, ArgoCD, Terraform"
      has_deployments = false
      topics          = ["infrastructure", "gitops", "kubernetes", "terraform", "ansible"]
    }
  }
}

# -----------------------------------------------------------------------------
# Optional: Branch Protection
# -----------------------------------------------------------------------------

variable "enable_branch_protection" {
  description = "Whether to enable branch protection rules"
  type        = bool
  default     = false
}

variable "protected_branch" {
  description = "Branch name to protect (usually main)"
  type        = string
  default     = "main"
}

variable "required_status_checks" {
  description = "List of required status checks before merging"
  type        = list(string)
  default     = []
}
