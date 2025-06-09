output "app_url" {
  description = "Access your app at this .nip.io URL"
  value       = "http://${google_compute_global_address.lb_ip.address}.nip.io"
}
