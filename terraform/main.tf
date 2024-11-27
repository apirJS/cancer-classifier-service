terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.12.0"
    }
  }
}

provider "google" {
  credentials = file(var.service_account_key)
  project     = var.project_id
  region      = var.region
  zone        = var.zone
}


resource "google_storage_bucket" "bucket" {
  name          = "${var.project_id}-bucket-${var.region}"
  location      = var.region
  force_destroy = true
}

resource "google_storage_bucket_object" "model" {
  name       = "model.json"
  source     = "../model/model.json"
  bucket     = google_storage_bucket.bucket.name
  depends_on = [google_storage_bucket.bucket]
}

resource "google_storage_bucket_object" "model_bin_1of4" {
  name       = "group1-shard1of4.bin"
  source     = "../model/group1-shard1of4.bin"
  bucket     = google_storage_bucket.bucket.name
  depends_on = [google_storage_bucket.bucket]
}

resource "google_storage_bucket_object" "model_bin_2of4" {
  name       = "group1-shard2of4.bin"
  source     = "../model/group1-shard2of4.bin"
  bucket     = google_storage_bucket.bucket.name
  depends_on = [google_storage_bucket.bucket]
}

resource "google_storage_bucket_object" "model_bin_3of4" {
  name       = "group1-shard3of4.bin"
  source     = "../model/group1-shard3of4.bin"
  bucket     = google_storage_bucket.bucket.name
  depends_on = [google_storage_bucket.bucket]
}

resource "google_storage_bucket_object" "model_bin_4of4" {
  name       = "group1-shard4of4.bin"
  source     = "../model/group1-shard4of4.bin"
  bucket     = google_storage_bucket.bucket.name
  depends_on = [google_storage_bucket.bucket]
}


resource "google_artifact_registry_repository" "repository" {
  repository_id = "my-repository"
  location      = var.region
  format        = "DOCKER"
  depends_on    = [google_storage_bucket_object.model, google_storage_bucket_object.model_bin_1of4, google_storage_bucket_object.model_bin_2of4, google_storage_bucket_object.model_bin_3of4, google_storage_bucket_object.model_bin_4of4]
}


resource "null_resource" "build_and_push_image" {

  provisioner "local-exec" {
    command = "gcloud builds submit -t ${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repository.repository_id}/backend:latest ../"
  }

  depends_on = [google_artifact_registry_repository.repository]
}

resource "google_firestore_database" "database" {
  project     = var.project_id
  type        = "FIRESTORE_NATIVE"
  name        = "(default)"
  location_id = var.region
}

resource "google_cloud_run_v2_service" "backend" {
  name                = "backend"
  location            = var.region
  deletion_protection = false


  template {
    containers {
      image = "${google_artifact_registry_repository.repository.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.repository.repository_id}/backend:latest"
      ports {
        name = "http"
        container_port = 8080
      }
    }
  }

  depends_on = [null_resource.build_and_push_image, google_firestore_database.database]
}

data "archive_file" "app_engine_source_zip" {
  type        = "zip"
  source_dir  = "../sources"
  output_path = "../sources/frontend.zip"
}

resource "google_storage_bucket_object" "app_engine_source_zip" {
  name   = "frontend.zip"
  source = data.archive_file.app_engine_source_zip.output_path
  bucket = google_storage_bucket.bucket.name
}

resource "google_app_engine_application" "app" {
  project     = var.project_id
  location_id = var.region
}

resource "google_app_engine_standard_app_version" "app_version" {
  service    = "default"
  runtime    = "nodejs22"
  version_id = "v1"

  entrypoint {
    shell = "npm start"
  }

  deployment {
    zip {
      source_url = "https://storage.googleapis.com/${google_storage_bucket.bucket.name}/${google_storage_bucket_object.app_engine_source_zip.name}"
    }
  }

  handlers {
    url_regex = "/"
    static_files {
      path              = "index.html"
      upload_path_regex = "index.html"
    }
  }

  handlers {
    url_regex = "/images"
    static_files {
      path              = "src/images"
      upload_path_regex = "src/images/.*"
    }
  }

  handlers {
    url_regex = "/styles"
    static_files {
      path              = "src/styles"
      upload_path_regex = "src/styles/.*"
    }
  }

  handlers {
    url_regex = "/scripts"
    static_files {
      path              = "src/scripts"
      upload_path_regex = "src/scripts/.*"
    }
  }

  handlers {
    url_regex = "/(.*\\.(htm|html|css|js))$"
    static_files {
      path                 = "\\1"
      upload_path_regex    = ".*\\.(htm|html|css|js)$"
      application_readable = true
    }
  }

  env_variables = {
    BACKEND_URL = google_cloud_run_v2_service.backend.uri
    PORT        = "8080"
  }

  depends_on = [google_cloud_run_v2_service.backend, google_app_engine_application.app, google_storage_bucket_object.app_engine_source_zip]
}
