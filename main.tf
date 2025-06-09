provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Reserve static IP
resource "google_compute_global_address" "lb_ip" {
  name = "static-ip-lb"
}

# NGINX VM
resource "google_compute_instance" "nginx" {
  name         = "nginx-vm"
  machine_type = "e2-micro"
  zone         = var.zone

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
    sudo apt update
    sudo apt install -y nginx
    cat <<EOF > /etc/nginx/sites-available/default
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

# Firewall for HTTP
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

# Cloud Run app
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

resource "google_cloud_run_service_iam_member" "public" {
  location        = var.region
  service         = google_cloud_run_service.app.name
  role            = "roles/run.invoker"
  member          = "allUsers"
}
