#!/usr/bin/env bash
# Regression using an actual pre-U-Boot CBoot DT and the vendor overlays.
set -euo pipefail
if (( $# != 3 )); then
  echo 'usage: test_l4t_emc_overlay.sh CBOOT.dtb SDMMC3.dtbo STOCK_EMC.dtbo' >&2
  exit 2
fi
emc_test=$(mktemp -d)
trap 'rm -rf -- "$emc_test"' EXIT
emc_path=/external-memory-controller@7001b000
emc_table=$emc_path/emc-table@0/emc-table@1600000
[[ $(fdtget -t x "$1" "$emc_table" nvidia,trained) == 1 ]]
cp -- "$1" "$emc_test/stock.dtb"
fdtput -r "$emc_test/stock.dtb" /sdhci@700b0400 "$emc_path"
fdtoverlay -i "$emc_test/stock.dtb" -o "$emc_test/red.dtb" "$2" "$3"
[[ $(fdtget -t x "$emc_test/red.dtb" "$emc_table" nvidia,trained) == 0 ]]
cp -- "$1" "$emc_test/fixed.dtb"
fdtput -r "$emc_test/fixed.dtb" /sdhci@700b0400
fdtoverlay -i "$emc_test/fixed.dtb" -o "$emc_test/green.dtb" "$2"
[[ $(fdtget -t x "$emc_test/green.dtb" "$emc_table" nvidia,trained) == 1 ]]
[[ $(fdtget -t s "$emc_test/green.dtb" /sdhci@700b0400 status) == okay ]]
emc_subtree() {
  dtc -q -I dtb -O dts "$1" | awk '
    /^\texternal-memory-controller@7001b000 \{/ {in_emc=1}
    in_emc {print; if ($0 == "\t};") exit}
  '
}
emc_subtree "$1" > "$emc_test/before.dts"
emc_subtree "$emc_test/green.dtb" > "$emc_test/after.dts"
test -s "$emc_test/before.dts"
cmp -- "$emc_test/before.dts" "$emc_test/after.dts"
echo 'PASS: stock path loses training; fixed path preserves the full EMC node and SDMMC3'
