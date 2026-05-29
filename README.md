# bootstrap-vdi

Ansible automation to turn a bare Ubuntu machine into a **Proxmox VDI thin client** — zero interaction after the bootstrap command runs.

On completion the machine:
- Auto-logs in as `vdi` user on boot
- Launches the [PVE-VDIClient](https://github.com/joshpatten/PVE-VDIClient) full-screen in an Openbox session
- Presents a Proxmox login screen using the configured auth realm (default: `ad`)
- Connects to any of the four home-cluster Proxmox nodes

---

## Quick Start

Run this once on a fresh Ubuntu 22.04/24.04 machine (as root or with sudo):

```bash
curl -fsSL https://raw.githubusercontent.com/brownkurts/bootstrap-vdi/main/bootstrap.sh | sudo bash
```

The machine will reboot automatically when done. On the next boot the VDI login screen appears.

---

## Architecture

```
Fresh Ubuntu PC
      │
      ▼
bootstrap.sh  (installs ansible + git, runs ansible-pull)
      │
      ▼
site.yml  (ansible-pull, runs on localhost)
      │
      ▼
role: pve_vdi_thinclient
  ├── install.yml     — packages, SSH, PVE-VDIClient, Python venv, LightDM
  ├── xorg.yml        — fallback xorg.conf for VM/hardware compatibility
  ├── config.yml      — /etc/vdiclient/vdiclient.ini from template
  ├── autologin.yml   — LightDM autologin for vdi user
  └── autostart.yml   — openbox/autostart launches vdiclient on login
      │
      ▼
Reboot → LightDM autologin → Openbox → vdiclient.py
```

---

## Proxmox Hosts Configured

| Host         | IP              | Port |
|--------------|-----------------|------|
| PROXMOX-01   | 192.168.2.201   | 8006 |
| proxmox03    | 192.168.2.212   | 8006 |
| proxmox05    | 192.168.2.215   | 8006 |
| pve-4        | 192.168.2.204   | 8006 |

---

## Configuration

All defaults live in `roles/pve_vdi_thinclient/defaults/main.yml`.

| Variable | Default | Description |
|---|---|---|
| `vdi_auth_backend` | `ad` | Proxmox realm ID (`ad`, `pve`, `pam`) |
| `vdi_hosts` | home cluster ×4 | Dict of `"host": port` Proxmox nodes |
| `vdi_local_user` | `vdi` | Local OS user for autologin |
| `vdi_tls_verify` | `false` | Verify Proxmox TLS cert |
| `vdi_auth_totp` | `false` | Require TOTP 2FA |
| `vdi_fullscreen` | `true` | Launch client fullscreen |
| `vdi_guest_type` | `both` | Show VMs, LXC, or both |
| `vdi_enable_ssh` | `true` | Keep SSH accessible for management |
| `vdi_admin_ssh_pubkeys` | `[]` | SSH keys to add to vdi user |
| `vdi_reboot_after_install` | `true` | Auto-reboot on completion |

Override any variable in `group_vars/vdi_clients.yml` or pass `-e` on the command line.

---

## VM Requirements (for testing on Proxmox)

When running as a VM rather than physical hardware:

- **VGA must be `virtio`** — `vga: std` and `vga: vmware` do not create a DRM device on KVM
- Recommended: 4 vCPUs, 4 GB RAM, 20 GB disk
- Cloud-init user: `ubuntu` with the Ansible SSH key

```bash
qm clone <ubuntu-template-id> <vmid> --name vdi-test --full true --storage local-lvm
qm set <vmid> --vga virtio --memory 4096 --cores 4
qm resize <vmid> scsi0 20G
qm set <vmid> --ipconfig0 ip=dhcp --ciuser ubuntu --sshkey /root/.ssh/authorized_keys
qm start <vmid>
```

On physical hardware, Xorg auto-detects the GPU — no manual config needed.

---

## Testing Against a Remote Host

Use `test-remote.yml` to run the role from the Ansible server against an existing VM without ansible-pull:

```bash
ansible-playbook test-remote.yml -i "192.168.2.X," -u ubuntu --become
```

Set `vdi_reboot_after_install: false` in `test-remote.yml` to reboot manually after inspecting.

---

## Files

| File | Purpose |
|---|---|
| `site.yml` | Main playbook — targets localhost, used by `ansible-pull` |
| `bootstrap.sh` | One-liner bootstrap script for fresh machines |
| `test-remote.yml` | Development playbook — targets a remote VM from Ansible server |
| `group_vars/vdi_clients.yml` | Shared vars for all VDI clients (Proxmox hosts, auth) |
| `roles/pve_vdi_thinclient/` | The full role |

---

## Related

- [PVE-VDIClient upstream](https://github.com/joshpatten/PVE-VDIClient)
- Proxmox cluster: `proxmox.kbtech.org`
- Ansible server: `192.168.2.30`
