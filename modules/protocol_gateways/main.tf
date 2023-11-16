data "google_compute_subnetwork" "this" {
  count   = length(var.subnets_list)
  name    = var.subnets_list[count.index]
  project = var.project_id
  region  = var.region
}

locals {
  disk_size               = var.disk_size + var.traces_per_frontend * var.frontend_cores_num
  private_nic_first_index = var.assign_public_ip ? 1 : 0
  nics_numbers            = var.frontend_cores_num + 1
  init_script = templatefile("${path.module}/init.sh", {
    yum_repo_server  = var.yum_repo_server
    nics_num         = local.nics_numbers
    subnet_range     = join(" ", data.google_compute_subnetwork.this.*.ip_cidr_range)
    disk_size        = local.disk_size
    install_weka_url = var.install_weka_url
    weka_token_id    = var.weka_token_id == "" ? "NONE" : var.weka_token_id
    proxy_url        = var.proxy_url
  })

  deploy_script = templatefile("${path.module}/deploy_protocol_gateways.sh", {
    frontend_cores_num = var.frontend_cores_num
    subnet_prefixes    = join(" ", data.google_compute_subnetwork.this.*.ip_cidr_range)
    backend_lb_ip      = var.backend_lb_ip
    weka_token_id      = var.weka_token_id
    weka_password_id   = var.weka_password_id
  })

  setup_nfs_protocol_script = templatefile("${path.module}/setup_nfs.sh", {
    gateways_name        = var.gateways_name
    interface_group_name = var.interface_group_name
    client_group_name    = var.client_group_name
  })

  setup_smb_protocol_script = templatefile("${path.module}/setup_smb.sh", {
    cluster_name        = var.smb_cluster_name
    domain_name         = var.smb_domain_name
    domain_netbios_name = var.smb_domain_netbios_name
    smbw_enabled        = var.smbw_enabled
    dns_ip              = var.smb_dns_ip_address
    gateways_number     = var.gateways_number
    gateways_name       = var.gateways_name
    frontend_cores_num  = var.frontend_cores_num
    share_name          = var.smb_share_name
  })

  protocol_script = var.protocol == "NFS" ? local.setup_nfs_protocol_script : local.setup_smb_protocol_script

  setup_protocol_script = var.setup_protocol ? local.protocol_script : ""

  custom_data_parts = [
    local.init_script, local.deploy_script, local.setup_protocol_script
  ]
  custom_data = join("\n", local.custom_data_parts)
}

# ======================== instance ============================
resource "google_compute_instance_template" "this" {
  name                    = var.gateways_name
  machine_type            = var.machine_type
  project                 = var.project_id
  tags                    = [var.gateways_name]
  metadata_startup_script = local.custom_data
  metadata = {
    apply-alias-ip-ranges = true
  }

  disk {
    source_image = var.source_image_id
    auto_delete  = true
    disk_size_gb = 20
    boot         = true
  }

  disk {
    mode         = "READ_WRITE"
    disk_size_gb = local.disk_size
    disk_type    = "pd-standard"
  }
  service_account {
    email  = var.sa_email
    scopes = ["cloud-platform"]
  }

  # nic with external ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index)
    content {
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].id
      subnetwork_project = var.project_id
      access_config {}
      dynamic "alias_ip_range" {
        for_each = range(var.secondary_ips_per_nic)
        content {
          ip_cidr_range = "/32"
        }
      }
    }
  }
  # nic with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, 1)
    content {
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].id
      subnetwork_project = var.project_id
      dynamic "alias_ip_range" {
        for_each = range(var.secondary_ips_per_nic)
        content {
          ip_cidr_range = "/32"
        }
      }
    }
  }

  dynamic "network_interface" {
    for_each = range(1, local.nics_numbers)
    content {
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].id
      subnetwork_project = var.project_id
    }
  }
  lifecycle {
    ignore_changes = [network_interface]
    precondition {
      condition     = var.protocol == "NFS" ? var.gateways_number >= 1 : var.gateways_number >= 3 && var.gateways_number <= 8
      error_message = "The amount of protocol gateways should be at least 1 for NFS and at least 3 and at most 8 for SMB."
    }
    precondition {
      condition     = var.protocol == "SMB" ? var.smb_domain_name != "" : true
      error_message = "The SMB domain name should be set when deploying SMB protocol gateways."
    }
    precondition {
      condition     = var.protocol == "SMB" ? var.secondary_ips_per_nic <= 3 : true
      error_message = "The number of secondary IPs per single NIC per protocol gateway virtual machine must be at most 3 for SMB."
    }
    precondition {
      condition     = local.nics_numbers != -1 ? var.frontend_cores_num < local.nics_numbers : true
      error_message = "The number of frontends must be less than the number of NICs."
    }
  }
}

resource "google_compute_instance_from_template" "this" {
  count                    = var.gateways_number
  name                     = "${var.gateways_name}-instance-${count.index}"
  zone                     = var.zone
  source_instance_template = google_compute_instance_template.this.self_link
  can_ip_forward           = false
  depends_on               = [google_compute_instance_template.this]

  lifecycle {
    ignore_changes = all
  }
}
