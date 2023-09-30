locals {
  ssh_path             = "/tmp/${var.prefix}-${var.cluster_name}"
  ssh_public_key_path  = "${local.ssh_path}-public-key.pub"
  ssh_private_key_path = "${local.ssh_path}-private-key.pem"
  ssh_public_key       = var.ssh_public_key == null ? tls_private_key.ssh_key[0].public_key_openssh : var.ssh_public_key
}

resource "tls_private_key" "ssh_key" {
  count     = var.ssh_public_key == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "public_key" {
  count           = var.ssh_public_key == null ? 1 : 0
  content         = tls_private_key.ssh_key[count.index].public_key_openssh
  filename        = local.ssh_public_key_path
  file_permission = "0600"
}

resource "local_file" "private_key" {
  count           = var.ssh_public_key == null ? 1 : 0
  content         = tls_private_key.ssh_key[count.index].private_key_pem
  filename        = local.ssh_private_key_path
  file_permission = "0600"
}
