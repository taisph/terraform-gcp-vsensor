#this is for not enabled logging and versioning
# kics-scan ignore-block
resource "google_storage_bucket" "vsensor_pcaps" {
  count = var.retention_time_days == 0 ? 0 : 1

  name          = "${local.deployment_id}-vsensor-pcaps"
  project       = var.project_id
  location      = var.region
  storage_class = "STANDARD"
  force_destroy = true

  public_access_prevention    = "enforced"
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = var.retention_time_days
    }
    action {
      type = "Delete"
    }
  }

  retention_policy {
    retention_period = local.retention_time_secs
    is_locked        = false
  }

}

