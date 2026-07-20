provider "grafana" {
  cloud_access_policy_token = var.cloud_access_policy_token
}

data "grafana_cloud_stack" "platform" {
  count = var.enable_stack && var.stack_id == "" ? 1 : 0

  slug = var.stack_slug
}

locals {
  stack_id    = var.stack_id != "" ? var.stack_id : data.grafana_cloud_stack.platform[0].id
  region_slug = var.stack_id != "" ? var.region_slug : data.grafana_cloud_stack.platform[0].region_slug
  stack_slug  = var.stack_slug
  stack_url   = var.stack_id != "" ? "https://${var.stack_slug}.grafana.net" : data.grafana_cloud_stack.platform[0].url
}

resource "grafana_cloud_access_policy" "otlp_write" {
  count = var.enable_stack ? 1 : 0

  name   = "${var.stack_slug}-collector-otlp-write"
  region = local.region_slug
  scopes = ["metrics:write", "logs:write", "traces:write"]

  realm {
    type       = "stack"
    identifier = local.stack_id
  }

  lifecycle {
    precondition {
      condition     = var.cloud_access_policy_token != ""
      error_message = "enable_stack=true requires cloud_access_policy_token."
    }
    precondition {
      condition     = !var.enable_stack || var.stack_id == "" || var.region_slug != ""
      error_message = "region_slug is required when stack_id is set."
    }
  }
}

resource "grafana_cloud_access_policy_token" "otlp_write" {
  count = var.enable_stack ? 1 : 0

  region           = local.region_slug
  access_policy_id = grafana_cloud_access_policy.otlp_write[0].policy_id
  name             = "${var.stack_slug}-collector-otlp-write-token"
}

# Producer repositories use this least-privilege credential to publish their
# own recording rules without owning the platform stack.
resource "grafana_cloud_access_policy" "rules_write" {
  count = var.enable_stack ? 1 : 0

  name   = "${var.stack_slug}-producer-rules"
  region = local.region_slug
  scopes = ["rules:read", "rules:write"]

  realm {
    type       = "stack"
    identifier = local.stack_id
  }
}

resource "grafana_cloud_access_policy_token" "rules_write" {
  count = var.enable_stack ? 1 : 0

  region           = local.region_slug
  access_policy_id = grafana_cloud_access_policy.rules_write[0].policy_id
  name             = "${var.stack_slug}-producer-rules-token"
}

resource "grafana_cloud_stack_service_account" "producer_provisioner" {
  count = var.enable_stack ? 1 : 0

  stack_slug = local.stack_slug
  name       = "producer-observability-provisioner"
  role       = "Admin"
}

resource "grafana_cloud_stack_service_account_token" "producer_provisioner" {
  count = var.enable_stack ? 1 : 0

  stack_slug         = local.stack_slug
  name               = "producer-observability-provisioner-key"
  service_account_id = grafana_cloud_stack_service_account.producer_provisioner[0].id
}

# Read-only credential for cloud E2E verification (Prometheus, Loki, Tempo query APIs).
resource "grafana_cloud_access_policy" "e2e_query" {
  count = var.enable_stack ? 1 : 0

  name   = "${var.stack_slug}-e2e-query"
  region = local.region_slug
  scopes = ["metrics:read", "logs:read", "traces:read"]

  realm {
    type       = "stack"
    identifier = local.stack_id
  }
}

resource "grafana_cloud_access_policy_token" "e2e_query" {
  count = var.enable_stack ? 1 : 0

  region           = local.region_slug
  access_policy_id = grafana_cloud_access_policy.e2e_query[0].policy_id
  name             = "${var.stack_slug}-e2e-query-token"
}
