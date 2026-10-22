#!/usr/bin/env python3
"""Disassemble the Nth encoded shader of a NAK_DEBUG=print log with nvdisasm.

Usage: nakdis.py <log> <shader-index from 1> [extra nvdisasm args...]
"""
import struct
import subprocess
import sys

import os

# NVDISASM names the nvdisasm binary; NAKDIS_OUT the scratch file for the extracted code.
NVDISASM = os.environ.get("NVDISASM", "nvdisasm")
OUT = os.environ.get("NAKDIS_OUT", "/tmp/nakdis.bin")

log, idx = sys.argv[1], int(sys.argv[2])
k, words, grab = 0, [], False
for line in open(log, errors="replace"):
    if line.startswith("Encoded shader:"):
        k += 1
        grab = k == idx
        continue
    if grab:
        parts = line.split()
        if parts and all(len(p) == 8 for p in parts):
            words += [int(p, 16) for p in parts]
        else:
            grab = False
with open(OUT, "wb") as f:
    f.write(struct.pack(f"<{len(words)}I", *words))
subprocess.run([NVDISASM, "-b", "SM53", *sys.argv[3:], OUT], check=False)
