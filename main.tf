terraform {
  backend "gcs" {
    bucket  = "autopipelinesetup"  # replace with your actual bucket name
    prefix  = "terraform/state"       # folder path inside the bucket
  }
}


resource "google_compute_address" "nginx_ip" {
  name   = "${var.vm_name}-ip"
  region = var.region
}

resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
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

resource "google_compute_instance" "nginx_vm" {
  name         = var.vm_name
  machine_type = var.vm_machine_type
  zone         = var.zone

  depends_on = [google_cloud_run_service.demo_app]

  tags = ["http-server"]

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

    CLOUD_RUN_URL="${google_cloud_run_service.demo_app.status[0].url}"
    CLOUD_RUN_HOST=$(echo $CLOUD_RUN_URL | awk -F/ '{print $3}')

    cat > /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    location ~ ^${var.path_prefix}(/.*)?$ {
        proxy_pass $CLOUD_RUN_URL;

        proxy_ssl_server_name on;
        proxy_ssl_name $CLOUD_RUN_HOST;

        proxy_ssl_verify off;

        proxy_set_header Host $CLOUD_RUN_HOST;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;

        rewrite ^${var.path_prefix}/(.*)$ /\$1 break;

    }
}
EOF

    systemctl restart nginx
  EOT
}
