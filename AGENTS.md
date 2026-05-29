# AGENTS.md — bootstrap-vdi

Rules for AI agents (Claude, etc.) working in this repo.

---

## Repo Purpose

This repo turns a bare Ubuntu machine into a Proxmox VDI thin client via Ansible.
It is designed to run on the **target machine itself** via `ansible-pull` (site.yml targets `localhost`).
`test-remote.yml` exists for development/testing from the Ansible server.

---

## Safety Rules

- **Never run `site.yml` against a production host without confirming it's a disposable test VM or a dedicated thin client.** The role installs a full desktop environment and overwrites display manager config.
- **Always use `--check` before running against any host other than a test VM:**
  ```bash
  ansible-playbook test-remote.yml -i "<IP>," -u ubuntu --become --check
  ```
- **Never commit secrets.** `vdi_admin_ssh_pubkeys` should only reference public keys. No passwords, no tokens.
- **The `vdi` user is a kiosk account** — do not store credentials or sensitive data in its home directory.

---

## Architecture Notes

- `site.yml` — uses `hosts: localhost` + `connection: local` for ansible-pull. Do not change to remote hosts.
- `test-remote.yml` — uses `hosts: all` for development testing. Set `vdi_reboot_after_install: false` when iterating.
- Reboot is fire-and-forget (`async: 1, poll: 0, systemctl reboot`). Do NOT add `ansible.builtin.reboot` inside the role — it will block indefinitely when run via ansible-pull on localhost.
- The role is **fully idempotent** — safe to re-run at any time.

---

## Key Variables to Know

| Variable | Where set | Effect |
|---|---|---|
| `vdi_auth_backend` | `defaults/main.yml` | Proxmox auth realm — must match a realm in `pvesh get /access/domains` |
| `vdi_hosts` | `group_vars/vdi_clients.yml` + `site.yml` | Proxmox hosts the VDI client connects to |
| `vdi_reboot_after_install` | caller / defaults | Set `false` when testing to skip reboot |
| `vdi_admin_ssh_pubkeys` | `defaults/main.yml` | SSH pubkeys added to `vdi` user |

---

## Testing Workflow

1. Clone an Ubuntu 24.04 template on Proxmox (must use `vga: virtio`)
2. Run `test-remote.yml` against the VM IP
3. Reboot the VM manually and verify:
   - `systemctl is-active lightdm` → `active`
   - `who` shows `vdi  tty7  (:0)`
   - `ps aux | grep vdiclient.py | grep -v grep | wc -l` → `1` (exactly one instance)
   - `grep auth_backend /etc/vdiclient/vdiclient.ini` → correct realm
4. Destroy test VM when done

```bash
# Create test VM
ssh root@192.168.2.201 "qm clone 9001 <VMID> --name vdi-test --full true --storage local-lvm"
ssh root@192.168.2.201 "qm set <VMID> --vga virtio --memory 4096 --cores 4 && qm resize <VMID> scsi0 20G"
ssh root@192.168.2.201 "qm set <VMID> --ipconfig0 ip=dhcp --ciuser ubuntu --sshkey /root/.ssh/authorized_keys && qm start <VMID>"

# Run playbook
cd /home/kurt/bootstrap-vdi
ansible-playbook test-remote.yml -i "<VM_IP>," -u ubuntu --become

# Verify
ssh ubuntu@<VM_IP> "systemctl is-active lightdm && who && ps aux | grep vdiclient.py | grep -v grep | wc -l"

# Destroy
ssh root@192.168.2.201 "qm stop <VMID> && qm destroy <VMID> --purge"
```

---

## What NOT to Do

- Do not change `hosts: localhost` in `site.yml` to a remote host — it breaks the ansible-pull model
- Do not add a blocking `ansible.builtin.reboot` task inside the role
- Do not use `vga: std` or `vga: vmware` for test VMs — they produce `no screens found` on KVM
- Do not store the Proxmox API token or any credentials in this repo
- Do not add Tactical RMM enrollment keys to this repo — vault-encrypt them in AnsibleControl instead

---

## Ansible Server

All remote operations run from `192.168.2.30` (kurt@ansible) using the `id_ed25519` key.
The bootstrap-vdi repo is cloned at `/home/kurt/bootstrap-vdi`.
