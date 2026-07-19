locals {
  foundation_enabled = var.enable_foundation || var.enable_runtime
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ])
  secrets = var.enable_runtime ? {
    ingest-token  = var.ingest_bearer_token
    backend-token = var.grafana_cloud_token
    backend-auth  = "Basic ${base64encode("${var.grafana_cloud_instance_id}:${var.grafana_cloud_token}")}"
  } : {}
}

resource "google_project_service" "required" {
  for_each = local.foundation_enabled ? local.required_apis : toset([])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "collector" {
  count = local.foundation_enabled ? 1 : 0

  location      = var.region
  repository_id = "otel-collector"
  format        = "DOCKER"
  description   = "Pinned central OpenTelemetry Collector images"

  depends_on = [google_project_service.required]
}

resource "google_service_account" "collector" {
  count = var.enable_runtime ? 1 : 0

  account_id   = "${var.service_name}-sa"
  display_name = "Central OpenTelemetry Collector"
}

resource "google_secret_manager_secret" "runtime" {
  for_each = local.secrets

  secret_id = "${var.service_name}-${each.key}"
  replication {
    auto {}
  }

  depends_on = [google_project_service.required]
}

resource "google_secret_manager_secret_version" "runtime" {
  for_each = local.secrets

  secret      = google_secret_manager_secret.runtime[each.key].id
  secret_data = each.value
}

resource "google_secret_manager_secret_iam_member" "collector" {
  for_each = local.secrets

  secret_id = google_secret_manager_secret.runtime[each.key].id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.collector[0].email}"
}

resource "google_cloud_run_v2_service" "collector" {
  count = var.enable_runtime ? 1 : 0

  name                = var.service_name
  location            = var.region
  ingress             = "INGRESS_TRAFFIC_ALL"
  deletion_protection = false

  template {
    service_account = google_service_account.collector[0].email
    timeout         = "60s"

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = var.collector_image

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
        # Collector queues, retries, and batch timers run after OTLP handlers
        # return. Request-only CPU can freeze that work.
        cpu_idle = false
      }

      env {
        name  = "OTEL_COLLECTOR_BEARER_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.runtime["ingest-token"].secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "GRAFANA_CLOUD_TOKEN"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.runtime["backend-token"].secret_id
            version = "latest"
          }
        }
      }
      env {
        name  = "GRAFANA_CLOUD_OTLP_ENDPOINT"
        value = var.grafana_cloud_otlp_endpoint
      }
      env {
        name  = "GRAFANA_CLOUD_INSTANCE_ID"
        value = var.grafana_cloud_instance_id
      }
      env {
        name  = "GRAFANA_CLOUD_AUTH_HEADER"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.runtime["backend-auth"].secret_id
            version = "latest"
          }
        }
      }

      ports {
        container_port = 4318
      }

      startup_probe {
        http_get {
          path = "/"
          port = 13133
        }
        period_seconds    = 5
        failure_threshold = 12
      }
    }
  }

  lifecycle {
    precondition {
      condition = (
        length(var.collector_image) > 0 &&
        length(var.ingest_bearer_token) >= 32 &&
        length(var.grafana_cloud_otlp_endpoint) > 0 &&
        length(var.grafana_cloud_instance_id) > 0 &&
        length(var.grafana_cloud_token) > 0
      )
      error_message = "Runtime requires a pinned image, 32+ character ingest token, and Grafana Cloud OTLP credentials."
    }
  }

  depends_on = [
    google_project_service.required,
    google_secret_manager_secret_iam_member.collector,
  ]
}

# Cloud Run terminates TLS publicly. The Collector's bearer token remains the
# application-layer ingest gate.
resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  count = var.enable_runtime ? 1 : 0

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.collector[0].name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

