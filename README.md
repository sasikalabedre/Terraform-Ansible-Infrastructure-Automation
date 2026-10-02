# Terraform + Ansible Infrastructure Automation

## Project Overview

This project demonstrates infrastructure provisioning and server configuration using **Terraform and Ansible** on Google Cloud Platform (GCP).

Terraform is used to create and manage the cloud infrastructure, while Ansible is used to configure the servers, install Nginx, manage the Nginx service, and deploy a website across multiple servers.

The project also demonstrates how Terraform and Ansible can work together in a DevOps workflow.

---

## Architecture

```text
                         GitHub
                           │
                           │
                           ▼
                    Terraform Code
                           │
                           ▼
                    Google Cloud
                           │
                 ┌─────────┴─────────┐
                 │                   │
                 ▼                   ▼
              VPC Network          Subnet
                                     │
                           ┌─────────┼─────────┐
                           │         │         │
                           ▼         ▼         ▼
                         VM 1      VM 2      VM 3
                           │         │         │
                           └─────────┼─────────┘
                                     │
                                     ▼
                              Ansible Inventory
                                     │
                                     ▼
                              Ansible Playbook
                                     │
                                     ▼
                              Nginx Configuration
                                     │
                                     ▼
                              Website Deployment
```

---

# Technologies Used

* Google Cloud Platform (GCP)
* Terraform
* Ansible
* Nginx
* Linux / Ubuntu
* Git
* GitHub
* YAML
* Jinja2 variable syntax

---

# 1. GCP Infrastructure Provisioning with Terraform

Terraform was used to provision the required GCP infrastructure.

### GCP Project

The infrastructure was created in the GCP project:

```text
learningproject-510004
```

### Region and Zone

The resources were created in:

```text
Region: us-central1
Zone: us-central1-a
```

---

## VPC Network

A custom VPC network was created:

```text
tf-web-vpc
```

The VPC provides the network environment for the Compute Engine instances.

---

## Subnet

A subnet was created inside the VPC:

```text
tf-web-subnet
```

CIDR range:

```text
10.20.0.0/24
```

The subnet provides private IP addresses to the VMs.

---

## Compute Engine Instances

Three Compute Engine VMs were used for the Ansible multi-server configuration.

```text
tf-web-server
tf-web-server-2
tf-web-server-3
```

The VM configuration included:

```text
Machine type: e2-micro
Operating system: Debian 12
Zone: us-central1-a
```

Terraform was used to provision the additional servers using the `count` meta-argument.

Example:

```hcl
resource "google_compute_instance" "web_servers" {
  count = 2
}
```

Using `count` allowed multiple similar VM resources to be created from a single Terraform resource block.

The VM names were generated using:

```hcl
name = "tf-web-server-${count.index + 2}"
```

This produced:

```text
tf-web-server-2
tf-web-server-3
```

---

# 2. Public IP Configuration

The VMs required public IP addresses so that the Ansible control machine could connect to them.

Terraform used:

```hcl
access_config {}
```

inside the network interface configuration.

This enabled external IP addresses for the VMs.

A GCP organization policy was also encountered during VM creation.

The policy:

```text
constraints/compute.vmExternalIpAccess
```

initially prevented the new VMs from receiving external IP addresses.

The required VM instances were then allowed by the project-level policy:

```text
tf-web-server
tf-web-server-2
tf-web-server-3
```

After the policy was updated and propagated, Terraform successfully created the VMs with public IP addresses.

---

# 3. Firewall Configuration

Firewall rules were configured to allow required traffic to the VMs.

### SSH

TCP port:

```text
22
```

This allows SSH connectivity from the Ansible control machine.

### HTTP

TCP port:

```text
80
```

This allows access to the Nginx web server.

The VMs use the tag:

```text
tf-web-server
```

The firewall rules target this tag so that the required traffic can reach the instances.

---

# 4. Terraform Outputs

Terraform was used to retrieve the public IP address of the infrastructure.

The public IPs were then used by Ansible to connect to the managed servers.

The overall flow was:

```text
Terraform
   ↓
Create VMs
   ↓
Assign Public IPs
   ↓
Get Public IPs
   ↓
Configure Ansible Inventory
```

---

# 5. Ansible Control Node and Managed Nodes

The Ubuntu workstation was used as the **Ansible Control Node**.

The three GCP VMs were used as **Ansible Managed Nodes**.

```text
Control Node
Ubuntu Workstation
      │
      ├──────────→ web1
      ├──────────→ web2
      └──────────→ web3
```

Ansible connects to the managed nodes using SSH.

---

# 6. Ansible Inventory

An Ansible inventory was created to define the managed servers.

The three servers were placed into the same inventory group:

```ini
[webservers]
web1 ansible_host=IP1
web2 ansible_host=IP2
web3 ansible_host=IP3
```

Here:

* `webservers` is the inventory group.
* `web1`, `web2`, and `web3` are host aliases.
* `ansible_host` contains the actual VM public IP address.

A group variable was also configured:

```ini
[webservers:vars]
ansible_user=YOUR_USERNAME
```

This allows the same SSH username configuration to be applied to all servers in the group.

---

# 7. Ansible Connectivity Testing

Ansible connectivity was tested using the ping module:

```bash
ansible webservers -i inventory -m ping
```

All three servers successfully responded.

This confirmed that:

* The inventory was correct.
* The host aliases were working.
* SSH connectivity was working.
* Ansible could communicate with all three managed nodes.

Commands were also executed against the entire group.

For example:

```bash
ansible webservers -i inventory -m command -a "hostname"
```

This demonstrated that a single Ansible command could be executed across multiple servers.

---

# 8. Ansible Playbook

A playbook named:

```text
nginx.yml
```

was created to automate Nginx configuration.

The playbook targeted:

```yaml
hosts: webservers
```

Therefore, the same playbook could configure all three servers.

---

# 9. Privilege Escalation

The playbook used:

```yaml
become: true
```

This allows Ansible to execute tasks with elevated privileges.

It was required because installing packages and managing system services normally requires administrative privileges.

---

# 10. Ansible Variables

A variable was used for the Nginx package name:

```yaml
web_package: nginx
```

Instead of hardcoding `nginx` in every task, the playbook uses:

```yaml
{{ web_package }}
```

This makes the playbook easier to maintain and reuse.

---

# 11. Separate Variables File

The variable was moved into a separate file:

```text
vars.yml
```

The file contains:

```yaml
web_package: nginx
```

The playbook loads this file using:

```yaml
vars_files:
  - vars.yml
```

This demonstrates separation of configuration data from the main playbook.

---

# 12. Nginx Installation

Ansible was used to install Nginx:

```yaml
- name: Install web server
  apt:
    name: "{{ web_package }}"
    state: present
    update_cache: true
```

This task:

* Updates the package cache.
* Installs Nginx.
* Uses the variable from `vars.yml`.
* Ensures the package is present.

---

# 13. Nginx Service Management

The Nginx service was started and enabled:

```yaml
- name: Start web server
  service:
    name: "{{ web_package }}"
    state: started
    enabled: true
```

This ensures:

* Nginx is running.
* Nginx starts automatically when the server boots.

---

# 14. Website Deployment

A custom website file:

```text
index.html
```

was created.

Ansible copies the file to the Nginx web root:

```yaml
- name: Deploy website
  copy:
    src: index.html
    dest: /var/www/html/index.html
    mode: '0644'
```

This demonstrates automated application/content deployment using Ansible.

---

# 15. Registered Variables

The `register` keyword was used to capture command output.

For example:

```yaml
- name: Check nginx installation
  command: nginx -v
  register: nginx_version
```

The result of the command is stored in:

```text
nginx_version
```

The registered output was displayed using:

```yaml
- name: Show nginx version
  debug:
    var: nginx_version.stderr
```

This demonstrated how Ansible can capture and use the output of a task.

---

# 16. Nginx Service Status Checking

The Nginx service status was also captured:

```yaml
- name: Check nginx service status
  command: systemctl is-active nginx
  register: nginx_status
```

The result was displayed using:

```yaml
- name: Show nginx service status
  debug:
    var: nginx_status.stdout
```

The output confirmed that Nginx was running on the managed servers.

---

# 17. Multi-Server Automation

The main objective of the project was to configure multiple servers using one Ansible playbook.

Instead of manually configuring each VM:

```text
VM 1 → Install Nginx manually
VM 2 → Install Nginx manually
VM 3 → Install Nginx manually
```

Ansible automates the process:

```text
             Ansible Playbook
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
        web1      web2      web3
          │         │         │
          ▼         ▼         ▼
        Nginx     Nginx     Nginx
          │         │         │
          ▼         ▼         ▼
       Website   Website   Website
```

The same configuration is applied consistently across all servers.

---

# 18. Git and GitHub

Git was used for version control.

The Terraform and Ansible configuration files were maintained in a GitHub repository.

The project repository contains the infrastructure and configuration code so that the environment can be recreated later.

Terraform-generated files such as `.terraform` and Terraform state files were excluded using:

```text
.gitignore
```

This prevents large provider binaries and local Terraform state from being pushed to GitHub.

---

# 19. Complete Workflow

The complete workflow practiced in this project is:

```text
GitHub
   │
   ▼
Terraform
   │
   ├── VPC
   ├── Subnet
   ├── Firewall
   └── 3 GCP VMs
          │
          ▼
     Public IPs
          │
          ▼
   Ansible Inventory
          │
          ▼
   Ansible Connectivity
          │
          ▼
   Ansible Playbook
          │
          ├── Install Nginx
          ├── Start Nginx
          ├── Enable Nginx
          ├── Check Nginx version
          ├── Check service status
          └── Deploy website
          │
          ▼
     3 Configured Web Servers
```

---

# Project Outcome

This project provided practical experience with:

* GCP infrastructure provisioning
* Terraform resource management
* Terraform `count`
* VPC and subnet configuration
* Compute Engine instances
* Firewall rules
* External IP configuration
* Terraform outputs
* Ansible control and managed nodes
* Inventory groups
* Multiple servers
* Host aliases
* Group variables
* Ad-hoc commands
* Multi-server playbooks
* Ansible variables
* External variable files
* `vars_files`
* `register`
* `debug`
* Registered command output
* Service status checking
* Nginx installation
* Nginx service management
* Website deployment
* Git version control
* GitHub repository management

The project demonstrates a practical **Infrastructure as Code + Configuration Management** workflow using Terraform and Ansible.
