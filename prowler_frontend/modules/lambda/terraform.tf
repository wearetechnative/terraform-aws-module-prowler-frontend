terraform {
  required_version = ">= 1.1.0"

  required_providers {
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.0"
    }
  }
}
