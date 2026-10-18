#!/usr/bin/env bash
# Idempotent. Creates everything the pipeline needs. Safe to run on every pipeline run.
# Inputs (env): LOCATION GALLERY_RG GALLERY_NAME TFSTATE_RG TFSTATE_CONTAINER
set -euo pipefail
source "$(dirname "$0")/common.sh"

echo "Subscription: $SUB_ID"
echo "Terraform state account: $TFSTATE_SA"

echo ">> Registering resource providers (needed by Packer/Terraform)"
for ns in Microsoft.Compute Microsoft.Network Microsoft.Storage Microsoft.KeyVault; do
  az provider register --namespace "$ns" --wait -o none
done

echo ">> Resource groups"
az group create -n "$GALLERY_RG" -l "$LOCATION" -o none
az group create -n "$TFSTATE_RG" -l "$LOCATION" -o none

echo ">> Azure Compute Gallery: $GALLERY_NAME"
if ! az sig show -g "$GALLERY_RG" --gallery-name "$GALLERY_NAME" -o none 2>/dev/null; then
  az sig create -g "$GALLERY_RG" --gallery-name "$GALLERY_NAME" -l "$LOCATION" -o none
fi

echo ">> Image definitions"
create_def () {  # name offer sku ostype
  if ! az sig image-definition show -g "$GALLERY_RG" --gallery-name "$GALLERY_NAME" \
        --gallery-image-definition "$1" -o none 2>/dev/null; then
    az sig image-definition create -g "$GALLERY_RG" --gallery-name "$GALLERY_NAME" \
      --gallery-image-definition "$1" \
      --publisher LabImages --offer "$2" --sku "$3" \
      --os-type "$4" --os-state Generalized --hyper-v-generation V2 -l "$LOCATION" -o none
    echo "   created $1"
  else
    echo "   $1 already exists"
  fi
}
create_def ubuntu-2404  ubuntu        24_04-lts        Linux
create_def windows-2025 windowsserver 2025-datacenter  Windows

echo ">> Terraform state storage"
if ! az storage account show -g "$TFSTATE_RG" -n "$TFSTATE_SA" -o none 2>/dev/null; then
  az storage account create -g "$TFSTATE_RG" -n "$TFSTATE_SA" -l "$LOCATION" \
    --sku Standard_LRS --min-tls-version TLS1_2 --allow-blob-public-access false -o none
fi
KEY=$(az storage account keys list -g "$TFSTATE_RG" -n "$TFSTATE_SA" --query '[0].value' -o tsv)
az storage container create --account-name "$TFSTATE_SA" --account-key "$KEY" \
  -n "$TFSTATE_CONTAINER" -o none

echo "Bootstrap complete."
