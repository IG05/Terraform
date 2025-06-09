provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Reserve a global static IP for load balancer and .nip.io domain
resource "google_compute_global_address" "lb_ip" {
  name = "static-ip-lb"
}

# Firewall rule to allow HTTP traffic to the VM (NGINX)
resource "google_compute_firewall" "allow-http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# Compute instance (NGINX VM)
resource "google_compute_instance" "nginx" {
  name         = "nginx-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip = google_compute_global_address.lb_ip.address
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx

    # Configure NGINX to proxy pass to Cloud Run
    cat > /etc/nginx/sites-available/default << EOF
    server {
      listen 80;
      location / {
        proxy_pass https://${google_cloud_run_service.app.status[0].url};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
      }
    }
    EOF

    systemctl restart nginx
  EOT
}

# Cloud Run service running demo app (hello world)
resource "google_cloud_run_service" "app" {
  name     = "demo-app"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/cloudrun/hello"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}

# Allow public (allUsers) to invoke Cloud Run service
resource "google_cloud_run_service_iam_member" "public" {
  location = var.region
  service  = google_cloud_run_service.app.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
