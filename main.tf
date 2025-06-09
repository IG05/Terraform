resource "google_compute_address" "nginx_ip" {
  name   = "${var.vm_name}-ip"
  region = var.region
}

resource "google_compute_instance" "nginx_vm" {
  name         = var.vm_name
  machine_type = var.vm_machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.nginx_ip.address
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y nginx

    CLOUD_RUN_URL="https://${var.cloud_run_service_name}-${var.region}.a.run.app"

    cat > /etc/nginx/sites-available/default <<EOF
    server {
      listen 80;
      location / {
        proxy_pass $CLOUD_RUN_URL;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
      }
    }
    EOF

    systemctl restart nginx
  EOT
}

resource "google_cloud_run_service" "demo_app" {
  name     = var.cloud_run_service_name
  location = var.region

  template {
    spec {
      containers {
        image = var.container_image
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_member" "public_invoker" {
  service  = google_cloud_run_service.demo_app.name
  location = google_cloud_run_service.demo_app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
