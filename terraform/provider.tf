provider "azurerm" {
  version = "= 1.35.0"
}

terraform {
  required_version = "= 0.12.10"
  # ==============================================================================================================================
  # For local execution:
  #  1. comment the 'backend' section
  #  2. execute in Powershell:
  #     (https://www.terraform.io/docs/providers/azurerm/auth/service_principal_client_secret.html)
  #     $env:ARM_CLIENT_ID="00000000-0000-0000-0000-000000000000"
  #     $env:ARM_CLIENT_SECRET="00000000-0000-0000-0000-000000000000"
  #     $env:ARM_SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
  #     $env:ARM_TENANT_ID="00000000-0000-0000-0000-000000000000"
  #  3. execute: terraform init
  #     if errors, remove .terraform/ directory and retry
  #  4. execute: terraform validate -var-file="variables.locals.tfvars"
  #  5. execute: terraform plan -var-file="variables.locals.tfvars"
  #     if error "access_policy.0.object_id" isn't a valid UUID (""): uuid string is wrong length" => Service Principal is needed
  #  6. execute: terraform apply -var-file="variables.locals.tfvars"
  # ==============================================================================================================================
  backend "azurerm" {
    storage_account_name = "__application__sharedtfsa"
    container_name       = "terraform"
    key                  = "terraform-__environment__.tfstate"
    access_key           = "__tf_storage_account_key__"
  }
}
