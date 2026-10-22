#!/usr/bin/env bash
# Build a file-only C100 L4T boot fix from the board's original preboot image.
set -euo pipefail
if (( $# != 2 )); then
  echo 'usage: build_l4t_emc_boot.sh STOCK_PREBOOT.scr OUTPUT_DIRECTORY' >&2
  exit 2
fi
boot_source=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../priv/l4t" && pwd)
boot_output=$2
: "${MKIMAGE:=mkimage}"
: "${DUMPIMAGE:=dumpimage}"
mkdir -- "$boot_output"
cp -- "$1" "$boot_output/stock-preboot.scr"
"$DUMPIMAGE" -l "$1"
# A legacy script has a 64-byte image header and an 8-byte size table.
# Old dumpimage -p leaves that size table in its output for script images.
dd if="$1" of="$boot_output/stock-preboot.cmd" bs=1 skip=72 status=none
boot_text_bytes=$(wc -c < "$boot_output/stock-preboot.cmd")
boot_nonzero_bytes=$(tr -d '\000' < "$boot_output/stock-preboot.cmd" | wc -c)
(( boot_text_bytes == boot_nonzero_bytes ))
if rg -q 'c100_stock_bootcmd_mmc0' "$boot_output/stock-preboot.cmd"; then
  echo 'Preboot image already contains the EMC hook; use the original backup.' >&2
  exit 1
fi
cat -- "$boot_source/preboot-trained-emc.cmd" > "$boot_output/preboot.cmd"
printf '\n' >> "$boot_output/preboot.cmd"
cat -- "$boot_output/stock-preboot.cmd" >> "$boot_output/preboot.cmd"
"$MKIMAGE" -A arm64 -T script -C none -n 'C100 L4T trained EMC' \
  -d "$boot_source/boot-trained-emc.cmd" "$boot_output/c100-l4t-trained-emc.scr"
"$MKIMAGE" -A arm64 -T script -C none -n 'C100 SD and L4T preboot' \
  -d "$boot_output/preboot.cmd" "$boot_output/u-boot-preboot.scr"
