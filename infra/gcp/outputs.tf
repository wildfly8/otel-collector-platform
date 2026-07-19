output "runtime_enabled" {
  value = var.enable_runtime
}

output "foundation_enabled" {
  value = var.enable_foundation || var.enable_runtime
}

output "artifact_registry_repository" {
  value = try(google_artifact_registry_repository.collector[0].name, null)
}

output "collector_image_prefix" {
  value = (var.enable_foundation || var.enable_runtime) ? "${var.region}-docker.pkg.dev/${var.project_id}/otel-collector/collector" : null
}

output "cloud_run_uri" {
  value = try(google_cloud_run_v2_service.collector[0].uri, null)
}

output "producer_environment_hint" {
  description = "Operational hint only; normative producer behavior is contracts/public/otel-ingest."
  value = var.enable_runtime ? join("\n", [
    "OTEL_EXPORTER_OTLP_ENDPOINT=${google_cloud_run_v2_service.collector[0].uri}",
    "OTEL_EXPORTER_OTLP_HEADERS=Authorization=Bearer <ingest-token>",
    "OTEL_SERVICE_NAME=<required-bounded-service-name>",
  ]) : null
}

