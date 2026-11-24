#!/usr/bin/env python3
"""Verify test-recorded roots in RTL. For PUBLIC examples only: reads the witness."""
import argparse
import os
from pathlib import Path
import struct
import subprocess
import tempfile

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('capture_dir', type=Path)
a = ap.parse_args()
le = lambda buf: int.from_bytes(buf, 'little')
m = (a.capture_dir / 'manifest.bin').read_bytes()
w = (a.capture_dir / 'witness.bin').read_bytes()
if not m.startswith(b'EEG-MANIFEST\x01QC01') or not w.startswith(b'EEG-WIT\x01'):
    raise SystemExit('unknown capture format')
n = le(m[33:35])
if not n or len(m) != 35 + 34*n + 64 or len(w) != 8 + 2032*n:
    raise SystemExit('incomplete capture')
# Avoid publishing the test-only opening/slot vector or leaving it in the build tree.
with tempfile.TemporaryDirectory() as tmp:
    vect = Path(tmp) / 'stimulus'
    with vect.open('w') as f:
        print(n, f'{le(m[17:33]):032x}', file=f)
        for i in range(n):
            rec = m[35+34*i:35+34*(i+1)]
            row = w[8+2032*i:8+2032*(i+1)]
            if le(rec[:2]) != i: raise SystemExit('nonsequential index')
            print(f'{le(row[:32]):064x} {le(rec[2:]):064x}', file=f)
            for (slot,) in struct.iter_unpack('<I', row[32:]):
                if slot and not 1<<24 <= slot < 1<<25: raise SystemExit('noncanonical slot')
                print(f'{slot:07x}', file=f)
    vdir = Path(os.getenv('VERILATOR_DIR', 'build/verilated-replay')).resolve()
    subprocess.run(['verilator', '--binary', '--timing', '-j', '2', '--top-module', 'tb_record', '--Mdir', vdir,
                    *sorted(Path('rtl').glob('*.sv')), 'tests/tb_record.sv'], check=True)
    subprocess.run([vdir / 'Vtb_record', f'+PUBLIC_FIXTURE={vect}'], check=True)
