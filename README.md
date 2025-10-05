# **Terraform – DigitalOcean App Platform (Insizon Angular Deployment)**

## **Overview**

This Terraform configuration automates the deployment of the **Insizon Angular Web App** to **DigitalOcean App Platform**, including both **production** and **development** environments.

The setup ensures:

* Automated builds from GitHub on push (via branch tracking)
* Correct environment-specific build commands
* Automatic HTTPS provisioning
* Project attachment for centralized management under the Insizon DigitalOcean project

---

## **Repository Structure**

```bash
.
├── README.md                # Project documentation (this file)
├── env.tfvars               # Customizable input variables (tokens, project IDs, etc.)
├── main.tf                  # Core Terraform configuration (DO app resources)
├── providers.tf             # Provider and context setup
├── variables.tf             # Variable definitions and defaults
└── .terraform.lock.hcl      # Provider dependency lock file
```

---

## **Core Features**

* **Multi-Environment Deployment**

  * `insizon-angular-prod` → Production app
  * `insizon-angular-dev` → Development app

* **Automated GitHub Builds**

  * Each environment pulls from its respective branch:

    * `main` for production
    * `dev` for development
  * Auto-deploys on every push

* **Custom Build Commands**

  * Development: `npm ci && npm run build:dev`
  * Production: `npm ci && npm run build:prod`

* **Optimized Static Site Output**

  * `output_dir = "dist/client"`
  * SPA routing handled by:

    ```hcl
    index_document    = "index.html"
    catchall_document = "index.html"
    ```

* **TLS & DNS Integration**

  * Automatic HTTPS certificates via DigitalOcean
  * Custom domains managed through Porkbun DNS (A/AAAA records for App Platform ingress)

* **Alert Configuration**

  * Alerts on `DEPLOYMENT_FAILED` for both environments

---

## **Deployment Prerequisites**

1. **DigitalOcean Access Token**

   * Create and export your token:

     ```bash
     export DIGITALOCEAN_ACCESS_TOKEN="your_token_here"
     ```
  
   * Or specify it in `env.tfvars`:

     ```hcl
     do_token = "your_token_here"
     ```

2. **Terraform Installed**

   * Recommended version: `>= 1.7.0`
   * Verify:

     ```bash
     terraform -version
     ```

3. **GitHub Repository Access**

   * Repo: `insizon/insizonAngular`
   * Branches: `main`, `dev`
   * Ensure DigitalOcean App Platform has GitHub OAuth access.

---

## **Usage**

### **1️⃣ Initialize Terraform**

```bash
terraform init
```

### **2️⃣ Review the Plan**

```bash
terraform plan -var-file=env.tfvars
```

### **3️⃣ Apply Changes**

```bash
terraform apply -var-file=env.tfvars
```

### **4️⃣ Destroy Resources (if needed)**

```bash
terraform destroy -var-file=env.tfvars
```

---

## **Key Variables (env.tfvars)**

| Variable       | Description                    | Example Value                          |
| -------------- | ------------------------------ | -------------------------------------- |
| `do_token`     | DigitalOcean access token      | `do_abc123...`                         |
| `project_id`   | Target DO project ID           | `f14e8880-f4e3-4fad-b71f-a0ffa3ec58e2` |
| `project_name` | Project name (if not using ID) | `"insizon"`                            |
| `github_repo`  | GitHub repository              | `"insizon/insizonAngular"`             |
| `prod_branch`  | Branch for production builds   | `"main"`                               |
| `dev_branch`   | Branch for dev builds          | `"dev"`                                |
| `prod_domain`  | Production domain              | `"insizon.com"`                        |
| `dev_domain`   | Development domain             | `"dev.insizon.com"`                    |
| `region`       | DO App Platform region         | `"nyc"`                                |
| `output_dir`   | Angular build output directory | `"dist/client"`                        |

---

## **Deployment Validation**

After apply:

```bash
doctl apps list --context insizon
```

Expected:

```bash
insizon-angular-prod  https://insizon.com
insizon-angular-dev   https://dev.insizon.com
```

To trigger a manual redeploy:

```bash
doctl apps create-deployment <app-id> --context insizon
```

---

## **Troubleshooting**

| Issue                 | Cause                        | Fix                                                            |
| --------------------- | ---------------------------- | -------------------------------------------------------------- |
| 404 page on deploy    | `output_dir` mismatch        | Ensure `"dist/client"` in Terraform and Angular `angular.json` |
| Build logs skipped    | No code change / cache reuse | Trigger fresh deployment via `doctl apps create-deployment`    |
| DNS not resolving     | Porkbun TTL or A/AAAA delay  | Verify with `dig dev.insizon.com` or Cloudflare propagation    |
| App shows old version | DO App caching               | Force redeploy + clear CDN cache                               |

---

## **Credits**

**Project Author:** Muhammad Hassaan Javed
**Platform:** [DigitalOcean App Platform](https://www.digitalocean.com/docs/app-platform/)
**Stack:** Angular + Terraform + GitHub CI Deployments
**Domains:**

* Production → [https://insizon.com](https://insizon.com)
* Development → [https://dev.insizon.com](https://dev.insizon.com)
