provider "grafana" {
  cloud_access_policy_token = var.cloud_access_policy_token
}

resource "grafana_cloud_stack" "platform" {
  count = var.enable_stack ? 1 : 0

  name        = var.stack_name
  slug        = var.stack_slug
  region_slug = var.region_slug

  lifecycle {
    precondition {
      condition     = var.cloud_access_policy_token != ""
      error_message = "enable_stack=true requires cloud_access_policy_token."
    }
  }
}

resource "grafana_cloud_access_policy" "otlp_write" {
  count = var.enable_stack ? 1 : 0

  name   = "${var.stack_slug}-collector-otlp-write"
  region = var.region_slug
  scopes = ["metrics:write", "logs:write", "traces:write"]

  realm {
    type       = "stack"
    identifier = grafana_cloud_stack.platform[0].id
  }
}

resource "grafana_cloud_access_policy_token" "otlp_write" {
  count = var.enable_stack ? 1 : 0

  region           = var.region_slug
  access_policy_id = grafana_cloud_access_policy.otlp_write[0].policy_id
  name             = "${var.stack_slug}-collector-otlp-write-token"
}

# Producer repositories use this least-privilege credential to publish their
# own recording rules without owning the platform stack.
resource "grafana_cloud_access_policy" "rules_write" {
  count = var.enable_stack ? 1 : 0

  name   = "${var.stack_slug}-producer-rules"
  region = var.region_slug
  scopes = ["rules:read", "rules:write"]

  realm {
    type       = "stack"
    identifier = grafana_cloud_stack.platform[0].id
  }
}

resource "grafana_cloud_access_policy_token" "rules_write" {
  count = var.enable_stack ? 1 : 0

  region           = var.region_slug
  access_policy_id = grafana_cloud_access_policy.rules_write[0].policy_id
  name             = "${var.stack_slug}-producer-rules-token"
}

resource "grafana_cloud_stack_service_account" "producer_provisioner" {
  count = var.enable_stack ? 1 : 0

  stack_slug = grafana_cloud_stack.platform[0].slug
  name       = "producer-observability-provisioner"
  role       = "Admin"
}

resource "grafana_cloud_stack_service_account_token" "producer_provisioner" {
  count = var.enable_stack ? 1 : 0

  stack_slug         = grafana_cloud_stack.platform[0].slug
  name               = "producer-observability-provisioner-key"
  service_account_id = grafana_cloud_stack_service_account.producer_provisioner[0].id
}

