#!/usr/bin/env python3
"""Draw the public Oz replay; a missing conversion is a gap, not zero volts."""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DROP = 610  # Same injected fault as the published Oz proof example.
values = subprocess.check_output([sys.executable, ROOT / 'tools/replay_slots.py',
                                  '--drop-slot', str(DROP)], text=True).splitlines()
assert len(values) == 1000 and values[DROP] == '-' and values.count('-') == 1


def x(i):
    return 73 + 792 * i / 1000


def y(uv):
    return 115 - 0.30 * uv


parts = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 233" role="img" aria-labelledby="title desc">',
         '<title id="title">Four seconds of recorded Oz EEG, replayed as two test windows</title>',
         '<desc id="desc">The first window is complete. A single simulated conversion at 2.44 seconds is withheld from the second. The trace is public test input, not verifier output.</desc>',
         '<rect width="900" height="233" rx="9" fill="#f7faf9"/>',
         '<g font-family="DejaVu Sans, sans-serif" font-size="15" fill="#233c47">',
         '<text x="74" y="27" font-weight="bold">Window 1 · 500 present</text>',
         '<text x="492" y="27" font-weight="bold">Window 2 · 499 present</text>',
         '<text x="13" y="44">µV</text>']
for level in (-200, 0, 200):
    parts += [f'<path d="M73 {y(level)}h792" stroke="#cfdbdc"/>',
              f'<text x="62" y="{y(level)+5}" text-anchor="end">{level}</text>']
parts.append(f'<path d="M{x(500)} 37v145" stroke="#768b92" stroke-dasharray="4 4"/>')
for i in range(5):
    parts.append(f'<text x="{x(i*250)}" y="202" text-anchor="middle">{i} s</text>')
for lo, hi in [(0, DROP), (DROP + 1, len(values))]:
    path = []
    prev = None
    for i in range(lo, hi):
        level = int(values[i]) / 1000  # 1 nV per code; ordinate in µV.
        assert -200 <= level <= 200
        if prev is None:
            path.append(f'M{x(i):.2f} {y(level):.2f}')
        elif level != prev:
            path.append(f'H{x(i):.2f}V{y(level):.2f}')
        prev = level
    path.append(f'H{x(hi):.2f}')
    parts.append(f'<path d="{"".join(path)}" fill="none" stroke="#00696b" stroke-width="1.45"/>')
parts += [f'<path d="M{x(DROP):.2f} 52v127" stroke="#a45127" stroke-width="1.8" stroke-dasharray="3 3"/>',
          f'<text x="{x(DROP)+9:.1f}" y="49" fill="#91431b">Injected gap · 2.44 s</text>',
          '<text x="73" y="225" font-size="13">Public test input · PhysioNet EEGMMIDB, S001 R02, Oz · 160 Hz held on a 250 Hz slot clock</text>',
          '</g></svg>']
(ROOT / 'proposal/replay.svg').write_text('\n'.join(parts) + '\n', encoding='utf-8')
