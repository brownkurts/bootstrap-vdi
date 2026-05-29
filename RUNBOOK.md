# RUNBOOK — bootstrap-vdi

Day-2 operations, re-imaging, and troubleshooting for PVE VDI thin clients.

---

## Imaging a New PC

1. Boot the PC from a Ubuntu 22.04 or 24.04 USB (minimal server or desktop ISO)
2. Complete Ubuntu installation with:
   - Username: `ubuntu` (or any; will be replaced by `vdi` user)
   - Enable SSH server
   - Static or DHCP — either works
3. Once Ubuntu is up, run the bootstrap:

```bash
curl -fsSL https://raw.githubusercontent.com/brownkurts/bootstrap-vdi/main/bootstrap.sh | sudo bash
```

4. Machine reboots automatically. VDI login screen appears on next boot.

> **Note:** PXE/autoinstall support is a planned future addition for fully zero-touch imaging.

---

## Re-imaging an Existing Thin Client

The playbook is fully idempotent — safe to re-run at any time:

```bash
# From Ansible server
ansible-playbook test-remote.yml -i "<CLIENT_IP>," -u ubuntu --become
```

Or trigger ansible-pull directly on the client:

```bash
ssh ubuntu@<CLIENT_IP> "sudo ansible-pull -U https://github.com/brownkurts/bootstrap-vdi.git -i localhost, site.yml"
```

---

## Adding a New Proxmox Host

Edit `group_vars/vdi_clients.yml` and `site.yml`:

```yaml
vdi_hosts:
  "192.168.2.201": 8006
  "192.168.2.212": 8006
  "192.168.2.215": 8006
  "192.168.2.204": 8006
  "192.168.x.xxx": 8006   # ← add here
```

Then re-run the playbook on all thin clients to push the updated config.

---

## Changing the Auth Realm

Edit `vdi_auth_backend` in `roles/pve_vdi_thinclient/defaults/main.yml`:

```yaml
vdi_auth_backend: "ad"   # ad | pve | pam
```

Check available realms on Proxmox:
```bash
pvesh get /access/domains
```

Re-run the playbook — only `vdiclient.ini` changes.

---

## SSH Access to a Thin Client

The `vdi` user has the Ansible SSH key installed:

```bash
ssh ubuntu@<CLIENT_IP>   # cloud-init user (may not persist after re-image)
ssh vdi@<CLIENT_IP>      # VDI kiosk user — always present after bootstrap
```

The Ansible server key (`ansible` ed25519) is authorised on `vdi` by default.

---

## Troubleshooting

### VDI client doesn't appear after boot

```bash
# Check LightDM
sudo systemctl status lightdm
sudo journalctl -u lightdm -n 30

# Check Xorg
sudo cat /var/log/lightdm/x-0.log | grep -E "EE|Fatal"

# Check if vdi user is logged in
who

# Check vdiclient process
ps aux | grep vdiclient.py
```

**Common causes:**

| Symptom | Cause | Fix |
|---|---|---|
| LightDM fails, `no screens found` | VM VGA not `virtio` | `qm set <vmid> --vga virtio` |
| LightDM fails, `org.freedesktop.Accounts` | `accountsservice` missing | Re-run playbook |
| Two vdiclient.py processes | Old `.desktop` file | Re-run playbook (cleanup task removes it) |
| LightDM active but VDI not launched | `openbox/autostart` missing | Re-run playbook |

### VDI client launches but can't connect to Proxmox

```bash
# Check vdiclient config
cat /etc/vdiclient/vdiclient.ini

# Test Proxmox API from the client
curl -sk https://192.168.2.201:8006/api2/json/version
```

Check that:
- Auth backend matches your Proxmox realm (`pvesh get /access/domains`)
- TLS verify is `false` unless you have a valid cert on Proxmox
- The thin client can reach 192.168.2.201:8006 (firewall/VLAN)

### Login works but VM console won't open (black screen)

This is a SPICE/virt-viewer issue. Check:
- VM is set to use SPICE display in Proxmox
- `virt-viewer` is installed: `which remote-viewer`
- SPICE proxy is reachable from client network

### Re-run playbook after changes

```bash
# From Ansible server
cd /home/kurt/bootstrap-vdi
ansible-playbook test-remote.yml -i "<CLIENT_IP>," -u ubuntu --become
```

---

## Updating PVE-VDIClient

The role clones from `main` on every run. To update:

```bash
ansible-playbook test-remote.yml -i "<CLIENT_IP>," -u ubuntu --become
```

The `Install PVE-VDIClient from git` task will pull the latest version.

---

## Removing a Thin Client from Service

```bash
# Stop and destroy VM (if a VM)
ssh root@192.168.2.201 "qm stop <VMID> && qm destroy <VMID> --purge"

# Physical machine — just power off and wipe disk
# No K3s/cluster state to clean up
```
