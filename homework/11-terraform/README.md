# Terraform vs Ansible

## Terraform

Terraform is an Infrastructure as Code (IaC) tool created by HashiCorp. It is used to **provision and manage infrastructure** across cloud providers (AWS, Azure, GCP) and on-premises resources.

- Declarative language (HCL - HashiCorp Configuration Language)
- Manages infrastructure lifecycle: create, update, destroy
- Maintains state to track resource changes
- Provider-based architecture (plugins for each cloud/service)
- Best for **creating and destroying infrastructure**

## Ansible

Ansible is a Configuration Management and automation tool by Red Hat. It is used to **configure and maintain** servers and applications after they are created.

- Uses YAML for playbooks
- Agentless (connects via SSH/WinRM)
- Push-based execution model
- Manages packages, files, services, users, and application deployment
- Best for **configuring and maintaining existing infrastructure**

## Key Differences

| Aspect            | Terraform                    | Ansible                      |
|-------------------|------------------------------|------------------------------|
| Purpose           | Provision infrastructure     | Configure & maintain servers |
| State management  | Maintains state file         | Stateless                    |
| Language          | HCL (declarative)            | YAML (imperative/procedural) |
| Execution         | Plan → Apply                 | Push playbooks               |
| Learning curve    | Moderate                     | Easy                         |

## When to Use Each

- **Terraform**: When you need to create, modify, or destroy cloud resources (VPCs, EC2, databases, DNS).
- **Ansible**: When you need to install software, configure services, or deploy applications on existing servers.
- **Both together**: Use Terraform to provision infrastructure, then Ansible to configure what runs on it. This is a common and powerful pattern.
