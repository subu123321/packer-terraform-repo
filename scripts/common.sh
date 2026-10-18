#!/usr/bin/env bash
# Sourced by pipeline steps. Needs an active `az login` session (AzureCLI@2 provides it).
SUB_ID=$(az account show --query id -o tsv)
export ARM_SUBSCRIPTION_ID="$SUB_ID"

# Deterministic storage account name derived from the subscription id, so every run/stage
# finds the same Terraform state account without passing values around.
export TFSTATE_SA="tf$(printf '%s' "$SUB_ID" | md5sum | cut -c1-16)"

# Terraform's azurerm provider/backend cannot use `az login` when it is a service principal.
# AzureCLI@2 with addSpnToEnvironment: true exposes these variables, so hand them to Terraform.
if [ -n "${servicePrincipalId:-}" ]; then
  export ARM_CLIENT_ID="$servicePrincipalId"
  export ARM_TENANT_ID="$tenantId"
  if [ -n "${servicePrincipalKey:-}" ]; then
    export ARM_CLIENT_SECRET="$servicePrincipalKey"          # secret-based service connection
  else
    export ARM_USE_OIDC=true                                  # workload identity federation
    export ARM_OIDC_TOKEN="${idToken:-}"
  fi
fi
