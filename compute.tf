module "compute" {
  source = "./modules/compute"

  subnet_id         = module.networking.subnet_id
  security_group_id = module.networking.security_group_id

  # instance_type and instance_count come from the per-workspace map in
  # locals.tf — staging is sized up, dev stays small, from one code path.
  instance_type   = local.cfg.instance_type
  instance_count  = local.cfg.instance_count
  name_prefix     = "kente-app-${terraform.workspace}"
  public_key_path = var.public_key_path

  # NOTE: no `depends_on = [module.networking]` here anymore. It was in the
  # starter and it was redundant: passing module.networking.vpc_id / subnet_id /
  # security_group_id as inputs already creates an implicit dependency edge, so
  # Terraform orders networking before compute on its own. This is the same
  # implicit-reference mechanism that the planted defect in monitoring.tf failed
  # to use. Removing the explicit depends_on is the corrected counter-example.
}
