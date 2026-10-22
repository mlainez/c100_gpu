# OKdo C100 / L4T R32.7.6 eMMC boot. CBoot trains the Micron RAM each boot.
# Stock C100 sysboot deletes that trained EMC node and replaces it with an
# untrained overlay. Boot this eMMC entry directly, retaining CBoot's node.
# The SD distro-boot target and Nerves chain-loader are not modified.

if fdt addr ${fdt_addr} && fdt get value c100_emc_trained /external-memory-controller@7001b000/emc-table@0/emc-table@1600000 nvidia,trained && itest ${c100_emc_trained} -eq 1; then
    echo [C100] Retaining CBoot-trained EMC for L4T
    # Leave the original CBoot DT and 0x83400000 training buffers intact.
    if fdt move ${fdt_addr} 0x83000000 0x100000; then
        fdt addr 0x83000000
        # Keep OKdo's SDMMC3 support, including the card's 3.3 V supply.
        if fdt get value c100_sd_compatible /sdhci@700b0400 compatible; then
            fdt rm /sdhci@700b0400
        fi
        if load mmc 0:1 0x90200000 /boot/tegra210-p3448-common-sdmmc3.dtbo && fdt apply 0x90200000 && part uuid mmc 0:1 c100_l4t_partuuid; then
            if load mmc 0:1 0x84000000 /boot/Image && itest ${filesize} -lt 0x6000000; then
                if load mmc 0:1 0x8a000000 /boot/initrd && itest ${filesize} -lt 0x6000000; then
                    setenv c100_l4t_initrd_size ${filesize}
                    setenv bootargs ${cbootargs} root=PARTUUID=${c100_l4t_partuuid} rw rootwait rootfstype=ext4 console=ttyS0,115200n8 console=tty0 fbcon=map:0 net.ifnames=0 sdhci_tegra.en_boot_part_access=1
                    booti 0x84000000 0x8a000000:${c100_l4t_initrd_size} 0x83000000
                fi
            fi
        fi
    fi
fi
echo "[C100] Trained-EMC L4T entry failed; returning to stock boot"
false
