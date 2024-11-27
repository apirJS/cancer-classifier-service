variable "service_account_key" {
  type = string
  description = "The path to the service account key file"
}

variable "project_id" {
  type = string
  description = "The GCP project ID"
}

variable "region" {
  type = string
  description = "The GCP region"
}

variable "zone" {
  type = string
  description = "The GCP zone"
}