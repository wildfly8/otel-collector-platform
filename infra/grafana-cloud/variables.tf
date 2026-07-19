variable "cloud_access_policy_token" {
  description = "Cloud Portal token able to manage stacks, access policies, and stack service accounts."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_stack" {
  description = "Create the Grafana Cloud stack and credentials."
  type        = bool
  default     = false
}

variable "stack_name" {
  type    = string
  default = "otel-platform"
}

variable "stack_slug" {
  type    = string
  default = "otelplatform"
}

variable "region_slug" {
  type    = string
  default = "prod-us-east-0"
}

