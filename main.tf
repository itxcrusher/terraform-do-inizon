locals {
  # when project_id is provided, use it otherwise resolve by name
  use_lookup       = length(var.project_id) == 0
  project_id_final = local.use_lookup ? data.digitalocean_project.by_name[0].id : var.project_id
}
# Fail fast if the Project isn't found (guarantees we deploy into the right team)
data "digitalocean_project" "by_name" {
  count = local.use_lookup ? 1 : 0
  name  = var.project_name
}
# --- PROD APP ---
resource "digitalocean_app" "insizon_angular_prod" {
  spec {
    name   = "insizon-angular-prod"
    region = var.region
    domain { name = var.prod_domain }
    domain { name = "www.${var.prod_domain}" }
    static_site {
      name          = "web"
      build_command = var.prod_build_cmd
      output_dir    = var.output_dir
      # Angular SPA routing on App Platform
      index_document    = "index.html"
      catchall_document = "index.html"
      env {
        key   = "NODE_VERSION"
        value = "20"
        scope = "BUILD_TIME"
      }
      github {
        repo           = var.github_repo
        branch         = var.prod_branch
        deploy_on_push = true
      }
    }
    alert { rule = "DEPLOYMENT_FAILED" }
  }
}
# Attach the app to the client's Project to guarantee correct team/account
resource "digitalocean_project_resources" "prod_attach" {
  project   = local.project_id_final
  resources = [digitalocean_app.insizon_angular_prod.urn]
}
# --- DEV APP ---
resource "digitalocean_app" "insizon_angular_dev" {
  spec {
    name   = "insizon-angular-dev"
    region = var.region
    domain { name = var.dev_domain }
    static_site {
      name              = "web"
      build_command     = var.dev_build_cmd
      output_dir        = var.output_dir
      index_document    = "index.html"
      catchall_document = "index.html"
      env {
        key   = "NODE_VERSION"
        value = "20"
        scope = "BUILD_TIME"
      }
      github {
        repo           = var.github_repo
        branch         = var.dev_branch
        deploy_on_push = true
      }
    }
    alert { rule = "DEPLOYMENT_FAILED" }
  }
}
resource "digitalocean_project_resources" "dev_attach" {
  project   = local.project_id_final
  resources = [digitalocean_app.insizon_angular_dev.urn]
}
