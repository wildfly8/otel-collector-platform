variable "project_id" {
  description = "GCP project that owns the collector."
  type        = string
}

variable "region" {
  description = "Cloud Run and Artifact Registry region."
  type        = string
  default     = "us-central1"

  validation {
    condition     = contains(["us-west1", "us-central1", "us-east1"], var.region)
    error_message = "Use a Cloud Run free-tier region: us-west1, us-central1, or us-east1."
  }
}

variable "enable_foundation" {
  description = "Enable required APIs and create Artifact Registry so an image can be pushed."
  type        = bool
  default     = false
}

variable "enable_runtime" {
  description = "Create secrets and Cloud Run after the pinned image exists."
  type        = bool
  default     = false
}

variable "service_name" {
  description = "Cloud Run service name."
  type        = string
  default     = "otel-collector-platform"
}

variable "collector_image" {
  description = "Pinned image URI built from this repository."
  type        = string
  default     = ""
}

variable "ingest_bearer_token" {
  description = "Producer-facing bearer token, at least 32 characters."
  type        = string
  sensitive   = true
  default     = ""
}

variable "grafana_cloud_otlp_endpoint" {
  description = "Grafana Cloud OTLP gateway URL."
  type        = string
  default     = ""
}

variable "grafana_cloud_instance_id" {
  description = "Grafana Cloud OTLP basic-auth username."
  type        = string
  default     = ""
}

variable "grafana_cloud_token" {
  description = "Grafana Cloud OTLP write token."
  type        = string
  sensitive   = true
  default     = ""
}

