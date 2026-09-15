#!/usr/bin/env bash
# Paste this script into the EC2 "User data" field when launching an instance.
set -euo pipefail

# Install Go 1.21
curl -fsSL -o /tmp/go.tgz https://go.dev/dl/go1.21.13.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tgz
rm /tmp/go.tgz
export PATH=/usr/local/go/bin:$PATH

# Create app directory
sudo mkdir -p /opt/calculator

# Build the microservice from uploaded source (uploaded separately or via S3)
# When using manually: upload homework/06-go/ contents to /tmp/calculator first,
# or download from a git repo / S3 bucket.
cd /tmp/calculator
go build -o calculator main.go

sudo cp calculator /opt/calculator/
sudo cp go.mod main.go /opt/calculator/

# Create systemd service
sudo tee /etc/systemd/system/calculator.service >/dev/null <<'UNIT'
[Unit]
Description=Go Calculator Microservice
After=network.target

[Service]
ExecStart=/opt/calculator/calculator
WorkingDirectory=/opt/calculator
Restart=always

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable calculator
sudo systemctl start calculator
