terraform {
  required_version = ">= 1.0.0"
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.0.6"
    }
  }
  # backend "remote" {
  #   hostname     = "app.terraform.io"
  #   token        = ""
  #   organization = "SoftServe-Academy"
  #   workspaces {
  #     name = "Sprint9-Task1"
  #   }
  # }
  backend "local" {
    path = "./terraform.tfstate"
  }
}

variable "github_token" {
  description = "GitHub token used for authentication"
  type        = string
  sensitive   = true
  default     = ""
}

provider "github" {
  token = var.github_token
  owner = "Practical-DevOps-GitHub"
}

data "github_repository" "repo" {
  full_name = "Practical-DevOps-GitHub/github-terraform-task-PTarasyuk"
}

data "github_branch" "main" {
  repository = data.github_repository.repo.name
  branch     = "main"
}

resource "github_repository_collaborator" "softservedata" {
  repository = data.github_repository.repo.name
  username   = "softservedata"
  permission = "push"
}

resource "github_repository_file" "pull_request_template" {
  repository          = data.github_repository.repo.name
  commit_message      = "Add pull request template"
  file                = ".github/pull_request_template.md"
  overwrite_on_create = true
  content             = <<EOT
## Describe your changes

## Issue ticket number and link

## Checklist before requesting a review
- [ ] I have performed a self-review of my code
- [ ] If it is a core feature, I have added thorough tests
- [ ] Do we need to implement analytics?
- [ ] Will this be part of a product update? If yes, please write one phrase about this update
EOT
}

resource "github_branch" "develop" {
  repository    = data.github_repository.repo.name
  branch        = "develop"
  source_branch = data.github_branch.main.branch
}

resource "github_branch_default" "develop_default" {
  repository = data.github_repository.repo.name
  branch     = github_branch.develop.branch
}

resource "github_repository_file" "codeowners" {
  repository     = data.github_repository.repo.name
  branch         = data.github_branch.main.branch
  file           = ".github/CODEOWNERS"
  content        = "* @softservedata"
  commit_message = "Add CODEOWNERS"

  depends_on = [github_branch.develop]
}

resource "github_branch_protection" "main" {
  repository_id = data.github_repository.repo.node_id
  pattern       = "main"
  required_pull_request_reviews {
    required_approving_review_count = 0
    require_code_owner_reviews      = true
  }
  allows_force_pushes = true
  allows_deletions    = true
}

resource "github_branch_protection" "develop" {
  repository_id = data.github_repository.repo.node_id
  pattern       = "develop"
  required_pull_request_reviews {
    required_approving_review_count = 2
  }
  allows_force_pushes = true
  allows_deletions    = true
}

resource "tls_private_key" "deploy_key" {
  algorithm = "ED25519"
}

resource "github_repository_deploy_key" "deploy_key" {
  repository = data.github_repository.repo.name
  title      = "DEPLOY_KEY"
  key        = tls_private_key.deploy_key.public_key_openssh
  read_only  = false
}

output "deploy_private_key" {
  value     = tls_private_key.deploy_key.private_key_pem
  sensitive = true
}

resource "github_repository_webhook" "discord" {
  repository = data.github_repository.repo.name

  configuration {
    url          = "https://discord.com/api/webhooks/1312440035492237414/VEmnZQwVAXvHWBV3bS6AbXeVdapEyjB65YgshMPswlF6J_g11tItEUtxC-qYtyoiOXkJ/github"
    content_type = "json"
    insecure_ssl = false
  }

  events = [
    "pull_request",
    "pull_request_review_comment",
    "pull_request_review",
    "pull_request_review_thread"
  ]
}

resource "github_actions_secret" "pat" {
  repository      = data.github_repository.repo.name
  secret_name     = "PAT"
  plaintext_value = var.github_token
}
