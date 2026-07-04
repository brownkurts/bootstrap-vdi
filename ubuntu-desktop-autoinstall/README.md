# ubuntu-desktop-autoinstall

Builder for the unattended Ubuntu Desktop install ISO used to spin up new admin/VDI
desktops. Backed up here from `ATLANTIS-ADMIN:C:\Users\kbadmin\Desktop\ubuntu-desktop-auto`
on 2026-07-04 (the local build workspace was deleted to reclaim disk).

## What it does

`build-iso.sh` remasters the stock **ubuntu-24.04.3-live-server-amd64.iso** into
`ubuntu-desktop-autoinstall.iso`, injecting the `nocloud/` autoinstall seed. The seed:

- installs a minimal server, then on **first boot** runs `firstboot-desktop.sh` which
  installs `ubuntu-desktop-minimal` + GDM and runs `ansible-pull` against
  `github.com/brownkurts/ansible_pull_desktop` (`local.yml`), then reboots into the desktop.
- user `kurt`; **set `identity.password` to a real hash before building** (currently a
  `PASTE_HASH_HERE` placeholder — `mkpasswd -m sha-512`).

## Build

Run on a Linux box with `xorriso` + `rsync`:

```bash
# place the stock server ISO next to build-iso.sh as ubuntu-24.04.3-live-server-amd64.iso
# (also available on the Proxmox ISO share)
./build-iso.sh
```

Output `ubuntu-desktop-autoinstall.iso` is what lives on the Proxmox ISO share as
`ISO:iso/ubuntu-desktop-autoinstall.iso`.
