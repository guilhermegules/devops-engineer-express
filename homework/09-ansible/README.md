# Homework 09 - Ansible

Provision a Go calculator microservice using **Ansible** with a proper **roles** structure.

The microservice (source from `../06-go`) is built and deployed as a `systemd` service on the target host, with Go installed from the official tarball and the OS base packages applied.

## Project Structure

```
09-ansible/
├── ansible.cfg                  # Ansible configuration
├── playbook.yml                 # Main playbook (applies all roles)
├── inventory/
│   ├── hosts.ini                # Inventory of target hosts
│   └── group_vars/all.yml       # Shared variables across roles
├── roles/
│   ├── base/                    # OS update + common packages
│   │   ├── tasks/main.yml       #   (Ubuntu/Debian and CentOS/RHEL)
│   │   └── defaults/main.yml
│   ├── go/                      # Proper Go installation
│   │   ├── tasks/main.yml       #   (downloads and extracts Go tarball)
│   │   └── defaults/main.yml
│   └── calculator/              # Build + deploy the microservice
│       ├── tasks/main.yml
│       ├── templates/calculator.service.j2   # systemd unit
│       └── files/               # Go source (main.go, go.mod)
└── scripts/
    └── check_microservice.sh    # PID check via Ansible
```

## Roles

| Role | Purpose |
|---|---|
| `base` | Updates the OS package cache and installs common packages. Works for both Ubuntu/Debian (`apt`) and CentOS/RHEL (`yum`) via `ansible_os_family` detection. |
| `go` | Downloads and installs Go from the official tarball into `/usr/local/go`, adds it to `PATH`, and is idempotent (skips if already installed). |
| `calculator` | Copies the Go source, builds the binary, installs a `systemd` unit, and enables/starts the service on port `8080`. |

## Prerequisites

- Target host reachable over SSH with the user/keys set in `inventory/hosts.ini`
- Ansible installed on the controller (see below).

## Installing Ansible

### Debian / Ubuntu (APT)

```bash
sudo apt update
sudo apt install -y ansible
```

To check the available version:

```bash
apt-cache policy ansible
```

### Debian / Ubuntu (pip — recommended for latest version)

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

pip install ansible
```

To auto-activate the venv on every shell session:

```bash
echo 'source ~/ansible-venv/bin/activate' >> ~/.bashrc
```

### Windows (via WSL2)

Ansible does not run natively on Windows. Use Windows Subsystem for Linux (WSL2).

**Step 1 — Enable WSL** (PowerShell as Administrator):

```powershell
wsl --install
```

Restart your computer, then open Ubuntu from the Start Menu.

**Step 2 — Install Ansible inside WSL** (same as Debian):

```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv

python3 -m venv ~/ansible-venv
source ~/ansible-venv/bin/activate

pip install ansible
```

> Keep project files in the WSL filesystem (`~/`) rather than `/mnt/c/` for better I/O performance.

### Verify installation

```bash
ansible --version
ansible localhost -m ping
```

## Usage

### 1. Provision the host

```bash
ansible-playbook -i inventory/hosts.ini playbook.yml
```

### 2. Verify it works

```bash
curl http://<host>:8080/calc/sum/2/3
curl http://<host>:8080/calc/mul/4/5
curl http://<host>:8080/calc/history
```

### 3. Check the microservice is running (PID check)

A bash helper that runs an Ansible ad-hoc command to look up the process PID:

```bash
./scripts/check_microservice.sh            # uses inventory/hosts.ini, [calculator] group
./scripts/check_microservice.sh inventory/hosts.ini vm1
```

It runs `pgrep -x calculator` on the target via Ansible, exiting `0` with `OK` if a PID is found, or a non-zero status with `FAIL` otherwise.

- `SERVICE_NAME=calculator ./scripts/check_microservice.sh` to override the process name.

## Using Ansible — Quick Reference

### Ad-hoc commands

Run single tasks without a playbook:

```bash
ansible all -i inventory/hosts.ini -m ping     # connectivity check
ansible all -i inventory/hosts.ini -m setup    # gather host facts
ansible calculator -m shell -a "uptime"        # run a command
```

### Playbooks

```bash
ansible-playbook -i inventory/hosts.ini playbook.yml
ansible-playbook playbook.yml --check --diff   # dry-run
ansible-playbook playbook.yml --limit vm1      # run on one host
ansible-playbook playbook.yml --tags base      # run a specific role
```

### Roles

```bash
ansible-galaxy init myrole                     # scaffold a new role
ansible-galaxy install -r requirements.yml     # install roles from a file
ansible-galaxy list                            # list installed roles
```

### Collections

```bash
ansible-galaxy collection install community.general
ansible-galaxy collection list
```

### Vault (secrets)

```bash
ansible-vault create secrets.yml
ansible-vault encrypt secrets.yml
ansible-vault decrypt secrets.yml
ansible-vault view secrets.yml
ansible-playbook playbook.yml --ask-vault-pass
```

## Configuration

- **Variables**: shared values (ports, paths, user) live in `inventory/group_vars/all.yml` and can be overridden per host.
- **Go version / architecture**: override in `roles/go/defaults/main.yml`.
- **Inventory**: edit `inventory/hosts.ini` to point at your target host(s).

## Provider Note

This homework targets a plain managed host (e.g. the VM from Homework 08). The roles are distro-agnostic and were designed to work with both Ubuntu and CentOS-style systems.
