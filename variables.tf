variable "kong_admin_uri" {
 description = "The URI of the Kong Admin API"
 type        = string
}

variable "kube_config_path" {
  description = "The path to the Kubernetes config file"
  type        = string
}
