output "vm_ip" {
  description = "Static external IP of the Nginx VM"
  value       = google_compute_address.nginx_ip.address
}

output "wildcard_domain" {
  description = "Wildcard nip.io domain for the VM IP"
  value       = "${google_compute_address.nginx_ip.address}.nip.io"
}

output "cloud_run_url" {
  description = "Cloud Run service URL"
  value       = google_cloud_run_service.demo_app.status[0].url
}
