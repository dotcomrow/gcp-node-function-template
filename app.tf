resource "random_id" "bucket_prefix" {
  byte_length = 8
}


resource "google_service_account" "default" {
  project = google_project.project.project_id
  account_id   = var.project_id
  display_name = "${var.project_id}-service-account"
}

resource "google_pubsub_topic" "default" {
  project = google_project.project.project_id
  name = "${var.project_id}-topic"
}

resource "google_storage_bucket" "default" {
  project = google_project.project.project_id
  name                        = "${random_id.bucket_prefix.hex}-${var.project_id}-source-bucket" # Every bucket name must be globally unique
  location                    = "US"
  uniform_bucket_level_access = true
}

data "archive_file" "default" {
  type        = "zip"
  output_path = "function-source.zip"
  source_dir  = "${path.module}"
}

resource "google_storage_bucket_object" "default" {
  name   = "function-source.zip"
  bucket = google_storage_bucket.default.name
  source = data.archive_file.default.output_path # Path to the zipped function source code
}

resource "google_cloudfunctions2_function" "default" {
  project = google_project.project.project_id
  name        = "${var.project_id}-function"
  location    = var.region
  description = "${var.project_id}-function"

  build_config {
    runtime     = "nodejs18"
    entry_point = "onMessage" # Set the entry point
    
    source {
      storage_source {
        bucket = google_storage_bucket.default.name
        object = google_storage_bucket_object.default.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    min_instance_count = 0
    available_memory   = "128Mi"
    timeout_seconds    = 60
    
    environment_variables = {
      GCP_BIGQUERY_PROJECT_ID      = var.GCP_BIGQUERY_PROJECT_ID
      SHARED_SERVICE_ACCOUNT_EMAIL = var.SHARED_SERVICE_ACCOUNT_EMAIL
      GCP_LOGGING_CREDENTIALS      = var.GCP_LOGGING_CREDENTIALS
      GCP_LOGGING_PROJECT_ID       = var.GCP_LOGGING_PROJECT_ID
    }

    ingress_settings               = "ALLOW_INTERNAL_ONLY"
    all_traffic_on_latest_revision = true
    service_account_email          = google_service_account.default.email
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = google_pubsub_topic.default.id
    retry_policy   = "RETRY_POLICY_RETRY"
  }
}
