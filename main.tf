terraform {
  required_version = ">= 1.4.0"
}

variable "pool" {
  description = "Slurm pool of compute nodes"
  default = []
}

variable "eyaml_key" { }

module "aws" {
  source         = "./aws"
  config_git_url = "https://github.com/ComputeCanada/puppet-magic_castle.git"
  config_version = "14.1.0"

  cluster_name = "sc24"
  domain       = "magiccastle.live"
  # Rocky Linux 9.4 -  ca-central-1
  # https://rockylinux.org/download
  image        = "ami-07fbc9d69b1aa88b9"

  instances = {
    mgmt  = { type = "t3.large",  count = 1, tags = ["mgmt", "puppet", "nfs"], disk_size = 100 },
    login = { type = "t3.xlarge", count = 1, tags = ["login", "public"], disk_size = 100 },
    proxy = { type = "t3.medium", count = 1, tags = ["proxy", "public"] },
    node  = { type = "t3.large", count = 1, tags = ["node"] },
  }

  # var.pool is managed by Slurm through Terraform REST API.
  # To let Slurm manage a type of nodes, add "pool" to its tag list.
  # When using Terraform CLI, this parameter is ignored.
  # Refer to Magic Castle Documentation - Enable Magic Castle Autoscaling
  pool = var.pool

  volumes = {
    nfs = {
      home     = { size = 100, type = "gp2" }
    }
  }

  public_keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBblyJ+6JynjS7kxzawodNvRrOTGVGj7266zcFJuq01N 1password_ed25519",
  ]

  nb_users     = 50
  # Shared password, randomly chosen if blank
  guest_passwd = ""
  hieradata = file("data.yaml")

  # AWS specifics
  region            = "ca-central-1"

  eyaml_key = var.eyaml_key
}

output "accounts" {
  value = module.aws.accounts
}

output "public_ip" {
  value = module.aws.public_ip
}

## Uncomment to register your domain name with CloudFlare
module "dns" {
  source           = "./dns/cloudflare"
  name             = module.aws.cluster_name
  domain           = module.aws.domain
  public_instances = module.aws.public_instances
}

## Uncomment to register your domain name with Google Cloud
# module "dns" {
#   source           = "./dns/gcloud"
#   project          = "your-project-id"
#   zone_name        = "you-zone-name"
#   name             = module.aws.cluster_name
#   domain           = module.aws.domain
#   public_instances = module.aws.public_instances
# }

# output "hostnames" {
# 	value = module.dns.hostnames
# }
