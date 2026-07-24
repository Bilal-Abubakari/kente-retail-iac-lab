module "networking" {
  source = "./modules/networking"

  vpc_cidr    = var.vpc_cidr
  project_tag = var.project_tag
}
