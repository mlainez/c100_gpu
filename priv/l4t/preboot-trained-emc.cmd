# Include before the existing OKdo preboot script. This hook only replaces the
# eMMC target, after the existing SD target. Do not save this RAM environment.
if test -z "${c100_stock_bootcmd_mmc0}"; then
    setenv c100_stock_bootcmd_mmc0 "${bootcmd_mmc0}"
    setenv bootcmd_mmc0 'if load mmc 0:1 ${scriptaddr} /boot/c100-l4t-trained-emc.scr; then source ${scriptaddr}; fi; run c100_stock_bootcmd_mmc0'
fi
