module "networking" {
  source = "./modules/networking"

  # vpc_cidr comes from the per-workspace map in locals.tf, so dev and staging
  # get non-overlapping ranges from the same code.
  vpc_cidr         = local.cfg.vpc_cidr
  allowed_ssh_cidr = var.allowed_ssh_cidr
  allowed_app_cidr = var.allowed_app_cidr
  app_port         = var.app_port
}
