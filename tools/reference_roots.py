#!/usr/bin/env python3
"""Independent integer oracle for public KATs; fixed blinds are NOT private capture."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
P = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001

def constants(name, n):
    values = [int(s, 16) for s in (ROOT / 'params' / name).read_text().splitlines()]
    if len(values) != n or not all(0 <= x < P for x in values):
        raise ValueError(name)
    return values

ARK, MDS = constants('ark.hex', 195), constants('mds.hex', 9)

def permute(s):
    for r in range(65):
        a = [(x + ARK[3*r+i]) % P for i, x in enumerate(s)]
        for i in range(3 if r < 4 or r >= 61 else 1):
            a[i] = pow(a[i], 5, P)
        s = [sum(a[j]*MDS[3*i+j] for j in range(3)) % P for i in range(3)]
    return s

def root(index, missing=False):
    s = permute([0x45454701 + (index << 32), 42, 100 + index])
    pack = 0
    for t in range(500):
        raw = (t*73 + index*11) % 0x700000
        if index == 0 and t < 4: raw = 0x800000
        if index == 1 and t < 5: raw = 0x7fffff
        slot = 0 if missing and t == 7 else (1 << 24) | raw
        pack |= slot << (25*(t % 10))
        if t % 10 == 9:
            s = permute([(s[0] + pack) % P, s[1], s[2]])
            pack = 0
    return f'{s[0]:064x}'

if __name__ == '__main__':
    print(root(0), root(1), root(0, missing=True), sep='\n')
