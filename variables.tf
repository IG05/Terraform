variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "vm_name" {
  description = "Name for the Compute Engine VM"
  type        = string
  default     = "nginx-vm"
}

variable "vm_machine_type" {
  description = "Machine type for the VM"
  type        = string
  default     = "e2-micro"
}

variable "cloud_run_service_name" {
  description = "Cloud Run service name"
  type        = string
  default     = "demo-cloud-run"
}

variable "container_image" {
  description = "Container image for Cloud Run"
  type        = string
  default     = "gcr.io/google-samples/hello-app:1.0"
}
