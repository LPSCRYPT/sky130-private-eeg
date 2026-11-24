#!/usr/bin/env python3
"""Convert the bundled public recording to two 500-slot *simulation* windows."""
import argparse
import csv
from decimal import Decimal, ROUND_HALF_EVEN
from hashlib import sha256
from pathlib import Path

source = Path(__file__).resolve().parents[1] / 'examples/oz/eeg_oz.csv'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--drop-slot', type=int, choices=range(1000), metavar='0..999',
                    help='inject one explicit missing conversion into the replay')
args = parser.parse_args()
if sha256(source.read_bytes()).hexdigest() != 'bc2e0c6320aabdbf6a39b248b57158143a956ae21b363467e51ce10e121007f1':
    raise SystemExit('unexpected recording hash')
with source.open() as f:
    rows = list(csv.DictReader(f))
if len(rows) != 640 or any(Decimal(r['t_s']) * 160 != i for i, r in enumerate(rows)):
    raise SystemExit('expected a complete 4 s recording at 160 Hz')
# A held sample (not new information), with a chosen bench LSB of 1 nV.
for slot in range(1000):
    value = Decimal(rows[slot * 160 // 250]['v_V']) * 10**9
    code = int(value.to_integral_value(rounding=ROUND_HALF_EVEN))
    if not -(1 << 23) <= code < (1 << 23):
        raise SystemExit('recorded voltage is out of range for bench encoding')
    print('-' if slot == args.drop_slot else code)
