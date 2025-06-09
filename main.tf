provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

resource "google_compute_instance" "nginx_vm" {
  name         = var.vm_name
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network       = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    location / {
        proxy_pass https://${google_cloud_run_service.app.status[0].url};
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF
    systemctl restart nginx
  EOT
}

resource "google_cloud_run_service" "app" {
  name     = var.run_service_name
  location = var.region

  template {
    spec {
      containers {
        image = var.dummy_image
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}

resource "google_compute_global_address" "external_ip" {
  name = "external-ip"
}

resource "google_compute_instance_group" "nginx_group" {
  name        = "nginx-group"
  zone        = var.zone
  instances   = [google_compute_instance.nginx_vm.self_link]
  named_port {
    name = "http"
    port = 80
  }
}

resource "google_compute_backend_service" "default" {
  name                  = "cdn-backend"
  protocol              = "HTTP"
  load_balancing_scheme = "EXTERNAL"
  backend {
    group = google_compute_instance_group.nginx_group.self_link
  }
}

resource "google_compute_url_map" "default" {
  name            = "url-map"
  default_service = google_compute_backend_service.default.self_link
}

resource "google_compute_target_http_proxy" "default" {
  name    = "http-proxy"
  url_map = google_compute_url_map.default.self_link
}

resource "google_compute_global_forwarding_rule" "default" {
  name       = "http-rule"
  ip_address = google_compute_global_address.external_ip.address
  port_range = "80"
  target     = google_compute_target_http_proxy.default.self_link
}

output "access_url" {
  value = "http://${google_compute_global_address.external_ip.address}.nip.io"
}