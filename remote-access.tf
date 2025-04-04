resource "google_compute_subnetwork" "vsensor_bastion" {
  count = local.bastion ? 1 : 0

  name          = "${local.deployment_id}-vsensor-bastion-subnet"
  ip_cidr_range = var.bastion_subnet_cidr
  project       = var.project_id
  region        = var.region

  network                  = local.network_name
  private_ip_google_access = true
}

resource "google_service_account" "vsensor_bastion" {
  count = local.bastion ? 1 : 0

  display_name = "Darktrace vSensor Quickstart bastion"
  description  = "Allows Bastion to send logs / metrics from Monitoring Ops Agent"
  account_id   = "${local.deployment_id}-bastion-sa"
  project      = var.project_id
}

resource "google_project_iam_member" "vsensor_bastion_mon" {
  count = local.bastion ? 1 : 0

  project = data.google_project.project.number
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vsensor_bastion[0].email}"
}

resource "google_project_iam_member" "vsensor_bastion_log" {
  count = local.bastion ? 1 : 0

  project = data.google_project.project.number
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vsensor_bastion[0].email}"
}

resource "google_compute_address" "vsensor_bastion_external" {
  count = local.bastion ? 1 : 0

  name = "${local.deployment_id}-vsensor-bastion-ip-external"

  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  project      = var.project_id
  region       = var.region
}

resource "google_compute_instance_template" "vsensor_bastion" {
  count = local.bastion ? 1 : 0

  name_prefix = "${local.deployment_id}-bastion-template"
  project     = var.project_id

  tags = [
    "darktrace-vsensor-bastion"
  ]

  network_interface {
    subnetwork = google_compute_subnetwork.vsensor_bastion[0].self_link
  }

  machine_type = "e2-micro"

  service_account {
    email  = google_service_account.vsensor_bastion[0].email
    scopes = ["cloud-platform"]
  }

  disk {
    source_image = "projects/ubuntu-os-cloud/global/images/family/ubuntu-minimal-2404-lts-amd64"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
    disk_type    = "pd-balanced"

  }
  metadata = {
    startup-script = templatefile("${path.module}/source/bastion.sh.tftpl", {})

    ssh-keys = var.bastion_ssh_user_key
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_instance_from_template" "vsensor_bastion_vm" {
  count = local.bastion ? 1 : 0

  name    = "${local.deployment_id}-vsensor-bastion-vm"
  project = var.project_id
  zone    = local.mig_zone[0]

  source_instance_template = google_compute_instance_template.vsensor_bastion[0].self_link_unique

  network_interface {
    subnetwork = google_compute_subnetwork.vsensor_bastion[0].self_link
    access_config {
      nat_ip       = google_compute_address.vsensor_bastion_external[0].address
      network_tier = "PREMIUM"
    }
  }

  depends_on = [google_compute_address.vsensor_bastion_external]
}

resource "google_compute_firewall" "vsensor_bastion_fw" {
  count = local.bastion_fw ? 1 : 0

  name        = "${local.deployment_id}-bastion-fw"
  network     = local.network_name
  project     = var.project_id
  description = "Allow ssh to bastion."

  priority = "1000"

  source_ranges = var.bastion_ssh_cidr
  direction     = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  target_tags = ["darktrace-vsensor-bastion"]
}
