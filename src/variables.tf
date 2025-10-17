# Minimal variables — everything else comes from config.yaml
variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}
