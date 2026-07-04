#!/usr/bin/env bash
set -Eeuo pipefail

BASE_DIR="$(pwd)"
SRC_ISO="$BASE_DIR/ubuntu-24.04.3-live-server-amd64.iso"
OUT_ISO="$BASE_DIR/ubuntu-desktop-autoinstall.iso"

MNT="$BASE_DIR/mnt"
WORK="$BASE_DIR/work"
NOCLOUD="$BASE_DIR/nocloud"

sudo umount "$MNT" 2>/dev/null || true
sudo rm -rf "$MNT" "$WORK"
mkdir -p "$MNT" "$WORK"

sudo mount -o loop "$SRC_ISO" "$MNT"
rsync -aH --info=progress2 "$MNT"/ "$WORK"/
sudo umount "$MNT"

mkdir -p "$WORK/nocloud"
cp "$NOCLOUD/user-data" "$WORK/nocloud/user-data"
cp "$NOCLOUD/meta-data" "$WORK/nocloud/meta-data"

for cfg in "$WORK/boot/grub/grub.cfg" "$WORK/boot/grub/loopback.cfg"; do
  if [[ -f "$cfg" ]]; then
    sed -i 's/---/ autoinstall ds=nocloud\\;s=\/cdrom\/nocloud\/ ---/g' "$cfg"
  fi
done

cd "$WORK"

xorriso -as mkisofs \
  -r \
  -V "UBUNTU_AUTO" \
  -o "$OUT_ISO" \
  -J -joliet-long -l \
  -iso-level 3 \
  -partition_offset 16 \
  -b boot/grub/i386-pc/eltorito.img \
    -c boot.catalog \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
  -eltorito-alt-boot \
  -e EFI/boot/bootx64.efi \
    -no-emul-boot \
  .

echo "ISO built: $OUT_ISO"
