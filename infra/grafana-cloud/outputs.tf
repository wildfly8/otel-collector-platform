output "stack_url" {
  value = var.enable_stack ? local.stack_url : null
}

output "otlp_gateway_hint" {
  value = var.enable_stack ? "https://otlp-gateway-${local.region_slug}.grafana.net/otlp" : null
}

output "otlp_instance_id" {
  value = var.enable_stack ? local.stack_id : null
}

output "otlp_write_token" {
  value     = try(grafana_cloud_access_policy_token.otlp_write[0].token, null)
  sensitive = true
}

output "producer_rules_token" {
  value     = try(grafana_cloud_access_policy_token.rules_write[0].token, null)
  sensitive = true
}

output "producer_provisioner_token" {
  value     = try(grafana_cloud_stack_service_account_token.producer_provisioner[0].key, null)
  sensitive = true
}

output "prometheus_url" {
  value = var.enable_stack && var.stack_id == "" ? try(data.grafana_cloud_stack.platform[0].prometheus_url, null) : null
}

output "prometheus_user_id" {
  value = var.enable_stack && var.stack_id == "" ? try(data.grafana_cloud_stack.platform[0].prometheus_user_id, null) : null
}

