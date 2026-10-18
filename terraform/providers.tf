terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Values are passed by the pipeline with -backend-config
  backend "azurerm" {}
}

# Auth: ARM_CLIENT_ID / ARM_TENANT_ID / ARM_CLIENT_SECRET (or ARM_USE_OIDC + ARM_OIDC_TOKEN) are exported by the pipeline.
# Subscription comes from the ARM_SUBSCRIPTION_ID env var set by the pipeline.
provider "azurerm" {
  features {}
}
