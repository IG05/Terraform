output "app_url" {
  value = "http://${google_compute_global_address.lb_ip.address}.nip.io"
}
