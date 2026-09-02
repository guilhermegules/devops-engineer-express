# Homework 08 - Vagrant

Provision a virtual machine using **Vagrant** with shell provisioning to deploy the calculator microservice and Go toolchain.

## Prerequisites

- [Vagrant](https://www.vagrantup.com/downloads) installed
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads) (default) or [libvirt](https://libvirt.org/) as the provider

## Quick Start

```bash
# Start and provision the VM
vagrant up

# SSH into the VM
vagrant ssh

# Access the microservice from the host
curl http://localhost:8080/calc/sum/2/3
curl http://localhost:8080/calc/mul/4/5
curl http://localhost:8080/calc/history
```

## Common Commands

| Command | Description |
|---|---|
| `vagrant up` | Create and provision the VM |
| `vagrant halt` | Stop the VM gracefully |
| `vagrant destroy` | Delete the VM entirely |
| `vagrant provision` | Re-run provisioning scripts |
| `vagrant reload` | Restart the VM (halt + up) |
| `vagrant ssh` | Open an SSH session into the VM |

## What Gets Provisioned

1. **Base box**: Ubuntu 22.04 (Jammy)
2. **System packages**: `curl`, `build-essential`
3. **Go 1.21**: Downloaded and installed to `/usr/local/go`
4. **Calculator microservice**: Built from `../06-go` and started on port `8080`

Source code from `../06-go` and provisioning scripts from `scripts/` are synced into the VM automatically via `synced_folder`. Changes on the host are reflected inside the VM in real time.

## Providers

The Vagrantfile supports both VirtualBox and libvirt. To use libvirt:

```bash
vagrant up --provider=libvirt
```

## Troubleshooting

- **Port 8080 already in use**: The Vagrantfile sets `auto_correct: true`, so Vagrant will pick the next available port. Check `vagrant port` to see the actual mapping.
- **Provisioning fails**: Run `vagrant provision` to re-execute the shell scripts.
- **Rebuild from scratch**: `vagrant destroy -f && vagrant up`
