variable "do_token" {
  type = string
}
variable "project_id" {
  type    = string
  default = "f14e8880-f4e3-4fad-b71f-a0ffa3ec58e2"
}
variable "project_name" {
  type    = string
  default = "insizon"
}
variable "github_repo" {
  type    = string
  default = "insizon/insizonAngular"
}
variable "prod_branch" {
  type    = string
  default = "main"
}
variable "dev_branch" {
  type    = string
  default = "dev"
}
variable "prod_domain" {
  type    = string
  default = "insizon.com"
}
variable "dev_domain" {
  type    = string
  default = "dev.insizon.com"
}
variable "region" {
  type    = string
  default = "nyc"
}
variable "output_dir" {
  type    = string
  default = "dist/client/browser"
}
variable "prod_build_cmd" {
  type    = string
  default = "npm ci && npm run build:prod"
}
variable "dev_build_cmd" {
  type    = string
  default = "npm ci && npm run build:dev"
}
