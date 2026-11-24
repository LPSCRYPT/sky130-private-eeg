#!/usr/bin/env python3
"""Render the five-corner setup comparison directly from the two OpenROAD logs."""
import argparse
import csv
import math
import re
from pathlib import Path

CORNERS = {'tt_025C_1v80': 'Typical · 25 °C · 1.80 V', 'ss_n40C_1v60': 'Slow · −40 °C · 1.60 V',
           'ss_100C_1v60': 'Slow · 100 °C · 1.60 V', 'ff_n40C_1v95': 'Fast · −40 °C · 1.95 V',
           'ff_100C_1v95': 'Fast · 100 °C · 1.95 V'}

def margins(path):
    rows = re.findall(r'^CORNER (\w+) [^\n]*\nworst slack max ([-\d.]+)\nworst slack min ([-\d.]+)$',
                      path.read_text(), re.MULTILINE)
    if len(rows) != len(CORNERS) or {r[0] for r in rows} != CORNERS.keys():
        raise ValueError(f'{path}: expected one complete max/min report per corner')
    return {key: (float(setup), float(hold)) for key, setup, hold in rows}

ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('report12', type=Path)
ap.add_argument('report10', type=Path)
a = ap.parse_args()
slow, fast = margins(a.report10), margins(a.report12)
out = Path(__file__).resolve().parents[1] / 'proposal'
with (out / 'timing.csv').open('w', newline='') as f:
    writer = csv.writer(f, lineterminator='\n')
    writer.writerow(['cell_corner', 'clock_mhz', 'worst_setup_slack_ns', 'worst_hold_slack_ns'])
    for key in CORNERS:
        for mhz, report in [(10, slow), (12, fast)]:
            writer.writerow([key, mhz, *(f'{v:.3f}' for v in report[key])])
xs = [v[0] for r in (slow, fast) for v in r.values()]
lo = min(-10, math.floor(min(xs)/10)*10)
hi = max(20, math.ceil(max(xs)/20)*20)
x = lambda v: 210 + (v-lo)/(hi-lo)*555
svg = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 211" role="img" aria-labelledby="title desc">',
       '<title id="title">Worst setup slack by cell library at 10 and 12 MHz</title>',
       '<desc id="desc">Circles denote 10 MHz; squares denote 12 MHz. A point left of zero misses setup. Placement estimates, not silicon.</desc>',
       '<rect width="800" height="211" rx="8" fill="#f7faf9"/><g font-family="DejaVu Sans,sans-serif" font-size="15" fill="#223c43">',
       '<text x="14" y="24" font-size="17" font-weight="bold">Worst setup slack (ns)</text>',
       '<circle cx="531" cy="18" r="5" stroke="#00696b" stroke-width="2.5" fill="white"/><text x="544" y="23">10 MHz</text>',
       '<rect x="652" y="13" width="10" height="10" fill="#864923"/><text x="671" y="23">12 MHz</text>']
for tick in [lo, *range(0, hi + 1, 20)]:
    color = '#52656b' if tick == 0 else '#d0dbdb'
    svg.append(f'<path d="M{x(tick):.1f} 38v135" stroke="{color}"/><text x="{x(tick):.1f}" y="198" text-anchor="middle">{tick}</text>')
for i, (key, label) in enumerate(CORNERS.items()):
    y = 51 + i*28
    x10, x12 = x(slow[key][0]), x(fast[key][0])
    svg.extend([f'<text x="14" y="{y+5}">{label}</text>',
                f'<path d="M{x10:.1f} {y}H{x12:.1f}" stroke="#9aaeb0" stroke-width="2"/>',
                f'<circle cx="{x10:.1f}" cy="{y}" r="5" fill="white" stroke="#00696b" stroke-width="2.5"/>',
                f'<rect x="{x12-5:.1f}" y="{y-5}" width="10" height="10" fill="#864923"/>'])
svg.append('</g></svg>')
(out / 'timing.svg').write_text('\n'.join(svg) + '\n', encoding='utf-8')
