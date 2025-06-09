variable "project_id" {}
variable "region" {
  default = "us-central1"
}
variable "zone" {
  default = "us-central1-a"
}
variable "vm_name" {
  default = "nginx-vm"
}
variable "run_service_name" {
  default = "dummy-service"
}
variable "dummy_image" {
  default = "gcr.io/cloudrun/hello"
}