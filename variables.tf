variable "container_image" {
  description = "Docker image (registry/repo:tag) to run on each ASG instance"
  type        = string
  default     = "ghcr.io/roddan-hue/ha-infra-welcomepage:latest"
}

variable "container_port" {
  description = "Port the container listens on, mapped to host port 80"
  type        = number
  default     = 4000
}
