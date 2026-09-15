#!/usr/bin/env bash
# provision-calculator.sh — Packer shell provisioner.
# Installs Go 1.21, builds the calculator microservice, and registers a systemd unit.
set -euo pipefail

# Install Go 1.21
curl -fsSL -o /tmp/go.tgz https://go.dev/dl/go1.21.13.linux-amd64.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tgz
rm /tmp/go.tgz
export PATH=/usr/local/go/bin:$PATH
go version

# Build the microservice (source uploaded via the file provisioner to /tmp/calculator)
cd /tmp/calculator
go build -o calculator main.go

# Install the binary and source to /opt/calculator
sudo mkdir -p /opt/calculator
sudo cp calculator /opt/calculator/
sudo cp go.mod main.go /opt/calculator/
sudo chown -R root:root /opt/calculator

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
