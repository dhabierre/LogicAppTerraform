data "azurerm_client_config" "current" {}

locals {
  subscription_id = data.azurerm_client_config.current.subscription_id
  domain          = "${var.application}-${var.environment}"
  
  # add new entries at the end of the array otherwise Terraform will destroy LogicApps containers (and logs...)
  logicapp_names = [ "hello" ]
	
  app_tags = {
    application  = var.application
    deployment   = "terraform"
    environment  = var.environment
  }
}

# ======================================================================================
# Resource Groups
# ======================================================================================

resource "azurerm_resource_group" "app_resource_group" {
  location = var.location
  name     = local.domain
  tags     = local.app_tags
}

# ======================================================================================
# Storage Account
# ======================================================================================

resource "azurerm_storage_account" "storage_account" {
  account_replication_type = "LRS"
  account_tier             = "Standard"
  account_kind             = "StorageV2"
  location                 = azurerm_resource_group.app_resource_group.location
  name                     = "${replace(local.domain, "-", "")}sa"
  resource_group_name      = azurerm_resource_group.app_resource_group.name
  tags                     = local.app_tags
}

# ======================================================================================
# KeyVault
# ======================================================================================

resource "azurerm_key_vault" "key_vault" {
  name                        = "${local.domain}-keyvault"
  location                    = azurerm_resource_group.app_resource_group.location
  resource_group_name         = azurerm_resource_group.app_resource_group.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  enabled_for_disk_encryption = true
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.service_principal_object_id
  
    key_permissions = [
      "get",
      "list",
      "create",
      "delete",
    ]
  
    secret_permissions = [
      "get",
      "list",
      "set",
      "delete",
    ]
  }

  lifecycle {
    ignore_changes = [access_policy]
  }

  tags = local.app_tags
}

# ======================================================================================
# LogicApps
# ======================================================================================

resource "azurerm_logic_app_workflow" "logic_app_workflow" {
  count               = length(local.logicapp_names)
  name                = "${local.domain}-logic-app-${element(local.logicapp_names, count.index)}"
  location            = azurerm_resource_group.app_resource_group.location
  resource_group_name = azurerm_resource_group.app_resource_group.name
  tags                = local.app_tags

  lifecycle {
    ignore_changes = [ parameters, tags ]
  }
}

resource "azurerm_log_analytics_workspace" "log_analytics_workspace" {
  name                = "${local.domain}-log-analytics-workspace"
  location            = azurerm_resource_group.app_resource_group.location
  resource_group_name = azurerm_resource_group.app_resource_group.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = local.app_tags
}

resource "azurerm_monitor_diagnostic_setting" "monitor_diagnostic_setting_workflow" {
  count                      = length(local.logicapp_names)
  name                       = "${local.domain}-monitor-diagnostic-setting-workflow-${element(local.logicapp_names, count.index)}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.log_analytics_workspace.id
  target_resource_id         = element(azurerm_logic_app_workflow.logic_app_workflow.*.id, count.index)
  storage_account_id         = azurerm_storage_account.storage_account.id

  log {
    category = "WorkflowRuntime"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = 7
    }
  }
}

resource "azurerm_log_analytics_solution" "log_analytics_solution" {
  solution_name         = "LogicAppsManagement"
  location              = "${azurerm_resource_group.app_resource_group.location}"
  resource_group_name   = "${azurerm_resource_group.app_resource_group.name}"
  workspace_resource_id = "${azurerm_log_analytics_workspace.log_analytics_workspace.id}"
  workspace_name        = "${azurerm_log_analytics_workspace.log_analytics_workspace.name}"

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/LogicAppsManagement"
  }
}
