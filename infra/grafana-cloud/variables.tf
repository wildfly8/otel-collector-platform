variable "cloud_access_policy_token" {
  description = "Cloud Portal token able to manage stacks, access policies, and stack service accounts."
  type        = string
  sensitive   = true
  default     = ""
}

variable "enable_stack" {
  description = "Look up the existing Grafana Cloud stack (stack_slug) and provision platform credentials."
  type        = bool
  default     = false
}

variable "stack_slug" {
  description = "Existing Grafana Cloud stack slug (e.g. microguava1468)."
  type        = string
  default     = "otelplatform"
}

variable "stack_id" {
  description = "Existing stack ID from Grafana Cloud portal. When set, skips stacks:read API lookup."
  type        = string
  default     = ""
}

variable "region_slug" {
  description = "Stack region (required when stack_id is set). Ignored when stack is looked up via API."
  type        = string
  default     = "prod-us-east-0"
}

