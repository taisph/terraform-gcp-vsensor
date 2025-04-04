resource "google_service_account" "vsensor" {
  display_name = "Darktrace vSensor Quickstart"
  description  = "Allows permission to Darktrace vSensors for logging/monitoring and to read/write PCAPs to Storage Bucket (if enabled)"
  account_id   = "${local.deployment_id}-sa"
  project      = var.project_id
}

resource "google_project_iam_member" "vsensor" {
  for_each = toset([
    "roles/monitoring.metricWriter",
    "roles/logging.logWriter",
  ])
  project = data.google_project.project.number
  role    = each.value
  member  = "serviceAccount:${google_service_account.vsensor.email}"
}

resource "google_project_iam_member" "vsensor-hmac" {
  count = var.retention_time_days == 0 ? 0 : 1

  project = data.google_project.project.number
  role    = "roles/storage.hmacKeyAdmin"
  member  = "serviceAccount:${google_service_account.vsensor.email}"
}

#IAM policies for Secret Manager Secret
resource "google_secret_manager_secret_iam_member" "update_key" {
  project   = data.google_project.project.project_id
  secret_id = data.google_secret_manager_secret.update_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vsensor.email}"
}

resource "google_secret_manager_secret_iam_member" "sm_push_token" {
  project   = data.google_project.project.project_id
  secret_id = data.google_secret_manager_secret.push_token.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vsensor.email}"
}

resource "google_secret_manager_secret_iam_member" "sm_ossensor_hmac" {
  count = length(var.sm_ossensor_hmac) == 0 ? 0 : 1

  project   = data.google_project.project.project_id
  secret_id = data.google_secret_manager_secret.ossensor_hmac[0].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.vsensor.email}"
}

#IAM policies for Cloud Storage Bucket
resource "google_storage_bucket_iam_member" "object_admin_po" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.objectAdmin"
  member = "projectOwner:${var.project_id}"
}

resource "google_storage_bucket_iam_member" "object_admin_sa" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.vsensor.email}"
}

resource "google_storage_bucket_iam_member" "legacy_bucket_owner_po" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.legacyBucketOwner"
  member = "projectOwner:${var.project_id}"
}

resource "google_storage_bucket_iam_member" "legacy_bucket_reader_sa" {
  count = var.retention_time_days == 0 ? 0 : 1

  bucket = google_storage_bucket.vsensor_pcaps[0].name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.vsensor.email}"
}
