"""Replay a real public fixture, then refuse noncanonical 32-byte wire fields."""
from pathlib import Path
import subprocess
import sys
import tempfile


def replay(directory):
    return subprocess.run([sys.executable, 'tools/check_record.py', directory]).returncode


def main(capture):
    # Positive control: missing tools, bad inputs or a broken bench cannot pass this test.
    if replay(capture) != 0:
        raise SystemExit('the original capture failed')
    manifest = (capture / 'manifest.bin').read_bytes()
    witness = (capture / 'witness.bin').read_bytes()
    with tempfile.TemporaryDirectory() as d:
        out = Path(d)
        for name, pos in [('manifest.bin', 37), ('witness.bin', 8)]:
            (out / 'manifest.bin').write_bytes(manifest)
            (out / 'witness.bin').write_bytes(witness)
            field_file = out / name
            buf = bytearray(field_file.read_bytes())
            # Same low 255 bits as the authentic first root or opening. Narrowing
            # before range checking would make the corrupt copy replay perfectly.
            buf[pos + 31] |= 0x80
            field_file.write_bytes(buf)
            if replay(out) != 1:
                raise SystemExit(f'{name}: expected rejection of out-of-range wire field')
            print(f'rejected: high bit in {name}', flush=True)


if __name__ == '__main__':
    main(Path(sys.argv[1]))
