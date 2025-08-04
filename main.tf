resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.log_analytics_workspace_retention_in_days
  tags                = var.tags
}

#region Container App Environment
resource "azurerm_container_app_environment" "this" {
  name                               = var.container_app_environment_name
  location                           = var.location
  resource_group_name                = azurerm_resource_group.this.name
  infrastructure_resource_group_name = var.infrastructure_resource_group_enabled ? "${var.resource_group_name}-managed" : null
  infrastructure_subnet_id           = var.container_app_environment_subnet_id
  internal_load_balancer_enabled     = var.container_app_environment_internal_load_balancer_enabled
  zone_redundancy_enabled            = var.container_app_environment_zone_redundancy_enabled
  log_analytics_workspace_id         = azurerm_log_analytics_workspace.this.id
  logs_destination                   = "log-analytics"
  mutual_tls_enabled                 = false
  tags                               = var.tags

  dynamic "workload_profile" {
    for_each = var.container_app_environment_workload_profile
    content {
      name                  = workload_profile.value.name
      workload_profile_type = workload_profile.value.workload_profile_type
      minimum_count         = workload_profile.value.minimum_count
      maximum_count         = workload_profile.value.maximum_count
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diagnostic-${azurerm_container_app_environment.this.name}"
  target_resource_id             = azurerm_container_app_environment.this.id
  log_analytics_workspace_id     = azurerm_log_analytics_workspace.this.id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
#endregion Container App Environment

#region Container Apps
resource "azurerm_container_app" "this" {
  for_each = var.container_app

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = each.value.name
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = var.tags
  workload_profile_name        = each.value.workload_profile_name

  template {
    min_replicas = each.value.min_replicas
    max_replicas = each.value.max_replicas

    dynamic "container" {
      for_each = each.value.container
      content {
        name    = container.value.name
        image   = container.value.image
        cpu     = container.value.cpu
        memory  = container.value.memory
        command = try(container.value.command, null)
        args    = try(container.value.args, null)
        dynamic "env" {
          for_each = try(container.value.env, {})
          content {
            name        = env.key
            secret_name = try(env.value.secret_name, null)
            value       = try(env.value.value, null)
          }
        }
      }
    }

    dynamic "custom_scale_rule" {
      for_each = try(each.value.custom_scale_rule, null) != null ? [each.value.custom_scale_rule] : []
      content {
        name             = custom_scale_rule.value.name
        custom_rule_type = custom_scale_rule.value.custom_rule_type
        metadata         = custom_scale_rule.value.metadata
      }
    }
  }

  #TODO - Add more configurations as needed for the Container App
  #secret block

}
#endregion Container Apps
