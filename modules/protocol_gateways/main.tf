data "google_compute_subnetwork" "this" {
  count   = length(var.subnets_list)
  name    = var.subnets_list[count.index]
  project = local.network_project_id
  region  = var.region
}

locals {
  network_project_id      = var.network_project_id != "" ? var.network_project_id : var.project_id
  disk_size               = var.disk_size + var.traces_per_frontend * var.frontend_container_cores_num
  private_nic_first_index = var.assign_public_ip ? 1 : 0
  nics_numbers            = var.frontend_container_cores_num + 1
  init_script = templatefile("${path.module}/init.sh", {
    yum_repo_server     = var.yum_repo_server
    disk_size           = local.disk_size
    proxy_url           = var.proxy_url
    deploy_function_url = var.deploy_function_url
    report_function_url = var.report_function_url
    protocol            = lower(var.protocol)
  })

  setup_smb_protocol_script = templatefile("${path.module}/setup_smb.sh", {
    cluster_name       = var.smb_cluster_name
    domain_name        = var.smb_domain_name
    smbw_enabled       = var.smbw_enabled
    gateways_number    = var.gateways_number
    gateways_name      = var.gateways_name
    frontend_cores_num = var.frontend_container_cores_num
  })

  setup_s3_protocol_script = file("${path.module}/setup_s3.sh")

  setup_validation_script = templatefile("${path.module}/setup_validation.sh", {
    gateways_number     = var.gateways_number
    gateways_name       = var.gateways_name
    protocol            = lower(var.protocol)
    smbw_enabled        = var.smbw_enabled
    report_function_url = var.report_function_url
  })

  smb_protocol_script = var.protocol == "SMB" ? local.setup_smb_protocol_script : ""
  s3_protocol_script  = var.protocol == "S3" ? local.setup_s3_protocol_script : ""
  validation_script   = var.setup_protocol && (var.protocol == "SMB" || var.protocol == "S3") ? local.setup_validation_script : ""

  setup_protocol_script = var.setup_protocol ? compact([local.smb_protocol_script, local.s3_protocol_script]) : []

  custom_data_parts = concat([local.init_script, local.validation_script], local.setup_protocol_script)

  custom_data = join("\n", local.custom_data_parts)
}

# ======================== instance ============================
resource "google_compute_instance_template" "this" {
  name                    = var.gateways_name
  machine_type            = var.machine_type
  project                 = var.project_id
  tags                    = [var.gateways_name]
  metadata_startup_script = local.custom_data

  labels = {
    weka_protocol_gateway = var.gateways_name
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  }

  metadata = {
    apply-alias-ip-ranges = true
    ssh-keys              = "${var.vm_username}:${var.ssh_public_key}"
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
      subnetwork_project = local.network_project_id
      access_config {}
    }
  }
  # nic with private ip
  dynamic "network_interface" {
    for_each = range(local.private_nic_first_index, 1)
    content {
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].id
      subnetwork_project = local.network_project_id
    }
  }

  dynamic "network_interface" {
    for_each = range(1, local.nics_numbers)
    content {
      subnetwork         = data.google_compute_subnetwork.this[network_interface.value].id
      subnetwork_project = local.network_project_id
    }
  }
  lifecycle {
    ignore_changes = [network_interface]
    precondition {
      condition     = var.protocol == "NFS" || var.protocol == "S3" ? var.gateways_number >= 1 : var.gateways_number >= 3 && var.gateways_number <= 8
      error_message = "The amount of protocol gateways should be at least 1 for NFS and at least 3 and at most 8 for SMB."
    }
    precondition {
      condition     = var.protocol == "SMB" && var.setup_protocol ? var.smb_domain_name != "" : true
      error_message = "The SMB domain name should be set when deploying SMB protocol gateways."
    }
    precondition {
      condition     = var.protocol == "SMB" ? var.secondary_ips_per_nic <= 3 : true
      error_message = "The number of secondary IPs per single NIC per protocol gateway virtual machine must be at most 3 for SMB."
    }
    precondition {
      condition     = local.nics_numbers != -1 ? var.frontend_container_cores_num < local.nics_numbers : true
      error_message = "The number of frontends must be less than the number of NICs."
    }
  }
}

resource "google_compute_instance_from_template" "this" {
  count                    = var.protocol != "NFS" ? var.gateways_number : 0
  name                     = "${var.gateways_name}-instance-${count.index}"
  zone                     = var.zone
  source_instance_template = google_compute_instance_template.this.self_link
  can_ip_forward           = false
  depends_on               = [google_compute_instance_template.this]
  labels = {
    goog-partner-solution = "isol_plb32_0014m00001h34hnqai_by7vmugtismizv6y46toim6jigajtrwh"
  }
  lifecycle {
    ignore_changes = all
  }
}
