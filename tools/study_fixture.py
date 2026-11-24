#!/usr/bin/env python3
"""Public ten-minute digital quality benchmark, not a physiological recording."""
import sys

for window in range(300):
    # 73 is coprime to 300: distribute exactly 14 missing and 15 rail-fail windows.
    case = (73 * window) % 300
    clipped = 5 if 14 <= case < 29 else 4
    for tick in range(500):
        if case < 14 and tick == 250:
            slot = '-'
        elif tick < clipped:
            slot = -8388608 if tick % 2 else 8388607
        else:
            slot = ((window * 137 + tick * 73) % 30001) - 15000
        sys.stdout.write(f'{slot}\n')
