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

  workload_profile {
    name                  = "Consumption"
    workload_profile_type = "Consumption"
    minimum_count         = 0
    maximum_count         = 0
  }
}

resource "azurerm_container_app" "this" {
  for_each = var.container_app

  container_app_environment_id = azurerm_container_app_environment.this.id
  name                         = each.value.name
  resource_group_name          = azurerm_resource_group.this.name
  revision_mode                = "Single"
  tags                         = var.tags

  template {
    min_replicas = each.value.min_replicas
    max_replicas = each.value.max_replicas

    container {
      name   = each.value.container.name
      image  = each.value.container.image
      cpu    = each.value.container.cpu
      memory = each.value.container.memory
    }

    container {
      name   = "another-container"
      image  = "mcr.microsoft.com/k8se/quickstart:latest"
      cpu    = each.value.container.cpu
      memory = each.value.container.memory
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
