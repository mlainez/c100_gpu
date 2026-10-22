# C100 L4T memory training and SD boot

Installed and verified on L4T R32.7.6, 2026-10-22. The fix restores actual
1600 MHz EMC operation without changing CPU/GPU governors, voltage settings,
bootloader binaries, saved U-Boot environment or SD files. EMC frequency
scaling now works; the memory clock is not forcibly pinned.

## Boot configuration

CBoot trains this C100's Micron RAM every boot. OKdo's patched `sysboot`
deletes the trained EMC node and applies a static PCN211181 overlay. Its
1600 MHz table is untrained, so NVIDIA's driver rejects rates above204MHz.
The serial capture confirms CBoot's training flag is1 before replacement.

`priv/l4t/preboot-trained-emc.cmd` wraps only `bootcmd_mmc0`, retaining the
original command as fallback. The existing target order remains
`mmc1 mmc0 usb0 nvme0 pxe dhcp`; `bootcmd_mmc1` remains stock. Nerves' SD
`boot.scr` therefore still chain-loads its own U-Boot before eMMC is reached.
The SD card was absent during the L4T tests. The user subsequently booted
Nerves from SD: bootID `a1415b28-a332-4bfe-9652-7069b9fc2819`, kernel6.18.57,
validated slotB, actual EMC1600MHz and a fresh GPU log with zero errors.
This verifies the installed configuration preserves the Nerves SD boot path.

`priv/l4t/boot-trained-emc.cmd` checks this board's RAM-code0 training flag,
copies CBoot's current DT to0x83000000 and applies only the SDMMC3 overlay.
The full EMC node, phandles and training buffers0x83400000–0x8341ffff remain
intact. Kernel/initrd load at0x84000000/0x8a000000. A partition UUID selects
the eMMC root independently of card numbering. Returning from the new entry
runs the stock eMMC command.

The dedicated entry loads the current `/boot/Image` and `/boot/initrd`, and
uses the recorded console/rootfs arguments plus CBoot's arguments. It does
not parse custom extlinux.conf additions; future path/argument changes must
also be reflected in this entry.

## Reproduce and roll back

Copy the original `/u-boot-preboot.scr` from L4T, then build on the host:

```sh
MKIMAGE=/path/to/mkimage DUMPIMAGE=/path/to/dumpimage \
  bash scripts/build_l4t_emc_boot.sh stock-preboot.scr new-output-directory
```

The helper validates the legacy image, extracts text after its64-byte header
and8-byte size table, and rejects NUL bytes or an already wrapped input. It
uses upstream U-Boot tools. Test the generated boot entry from the serial
console before staging the output directory on L4T and installing as root:

```sh
sudo bash scripts/install_l4t_emc_boot.sh /path/to/staged-output-directory
```

The installer saves the original preboot image, installs the new eMMC entry,
then atomically replaces preboot. The vendor script is retained after the
new hook; extlinux.conf is checked unchanged. On this board, roll back with:

```sh
sudo cp /var/backups/c100-l4t-emc-20261022T184950Z/u-boot-preboot.scr /u-boot-preboot.scr
sync
```

The restored image takes effect on reboot. No flash or `saveenv` is needed.

## Evidence

`scripts/test_l4t_emc_overlay.sh CBOOT.dtb SDMMC3.dtbo STOCK_EMC.dtbo`
reproduces stock training loss and verifies the fixed path preserves the
entire EMC subtree and enables SDMMC3. This regression and shellcheck pass.
A one-shot boot and an unattended boot reach1600MHz; the unattended boot ID
is548701d7-ed83-4ae0-bee2-850587c8751b. Four correctness probes and four
timing probes pass, with zero new kernel GPU errors. All timing frequency
samples show EMC1600MHz. CPU/GPU governors remain schedutil/nvhost_podgov;
maximum frequencies remain1479/921.6MHz.

| Same D64 resident-input graph | Before, EMC204MHz | After, EMC1600MHz |
|---|---:|---:|
| 640x480, cached serial | 17.02 FPS | 45.80 FPS |
| 1280x720, cached serial | 5.68 FPS | 15.59 FPS |
| 640x480, four asynchronous calls | 17.10 FPS | 45.93 FPS |
| 1280x720, four asynchronous calls | 5.33 FPS | 15.57 FPS |

Three timing repetitions; reference maps match at absolute tolerance0.0001.
These exclude camera/network input and output readback. Sync benchmark
exports use batch_size1; async batching uses an actual coarse-fence ABI.
They do not establish full Elixir/video throughput or a hardware ceiling.

Raw JSON, guards, frequency samples and serial/source/build evidence are in
`~/.cache/stereo-bench/l4t-emc-20261022/`. The portable comparison is in
`../nx_iree/docs/reference/stereo-nvidia-20261022/README.md`.
