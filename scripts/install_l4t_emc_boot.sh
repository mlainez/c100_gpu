#!/usr/bin/env bash
# Run on L4T as root after testing the boot entry from the serial console.
set -euo pipefail
if (( EUID != 0 || $# != 1 )); then
  echo 'usage (as root): install_l4t_emc_boot.sh STAGED_DIRECTORY' >&2
  exit 2
fi
boot_stage=$1
[[ $(uname -r) == 4.9.337-tegra ]]
[[ $(tr -d '\0' < /proc/device-tree/compatible) == *nvidia,tegra210* ]]
boot_device=$(findmnt -n -o SOURCE /)
[[ $boot_device =~ ^/dev/(mmcblk[0-9]+)p1$ ]]
[[ $(cat "/sys/class/block/${BASH_REMATCH[1]}/device/type") == MMC ]]
cmp -- /u-boot-preboot.scr "$boot_stage/stock-preboot.scr"
test -s "$boot_stage/c100-l4t-trained-emc.scr"
test -s "$boot_stage/u-boot-preboot.scr"
test ! -e /boot/c100-l4t-trained-emc.scr
boot_backup="/var/backups/c100-l4t-emc-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -m 0700 -- "$boot_backup"
cp -a -- /u-boot-preboot.scr "$boot_backup/u-boot-preboot.scr"
cp -a -- /boot/extlinux/extlinux.conf "$boot_backup/extlinux.conf"
install -m 0644 -- "$boot_stage/c100-l4t-trained-emc.scr" /boot/.c100-l4t-trained-emc.scr.new
mv -- /boot/.c100-l4t-trained-emc.scr.new /boot/c100-l4t-trained-emc.scr
install -m 0644 -- "$boot_stage/u-boot-preboot.scr" /.u-boot-preboot.scr.new
sync
mv -- /.u-boot-preboot.scr.new /u-boot-preboot.scr
sync
cmp -- /u-boot-preboot.scr "$boot_stage/u-boot-preboot.scr"
cmp -- /boot/extlinux/extlinux.conf "$boot_backup/extlinux.conf"
printf 'Installed; original preboot image: %s/u-boot-preboot.scr\n' "$boot_backup"
printf 'Rollback: cp %q/u-boot-preboot.scr /u-boot-preboot.scr && sync\n' "$boot_backup"
