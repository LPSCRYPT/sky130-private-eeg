"""Check strict 500-line, signed-24 interchange without proving or using human data."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("binary")
    p.add_argument("device_sk")
    args = p.parse_args()
    challenge = "2a" + "00" * 15
    valid = ["-8388608", "8388607", "-1", "0", "-"] + ["0"] * 495
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        for i, (name, lines, accept) in enumerate([
            ("complete input", valid, True),
            ("second identical input", valid, True),
            ("short input", valid[:-1], False),
            ("extra slot", valid + ["0"], False),
            ("high overflow", ["8388608"] + valid[1:], False),
            ("low overflow", ["-8388609"] + valid[1:], False),
            ("malformed token", ["NA"] + valid[1:], False),
            ("blank not missing", [""] + valid[1:], False),
        ]):
            source = tmp / "samples.txt"
            source.write_text("\n".join(lines) + "\n")
            dst = tmp / str(i)
            result = subprocess.run([args.binary, "capture", args.device_sk, challenge, "1", source, dst],
                                    capture_output=True, text=True)
            manifest = dst / "manifest.bin"
            if (result.returncode == 0) != accept or result.returncode < 0 or manifest.exists() != accept:
                raise RuntimeError(f"{name}: wrong outcome: {result.stderr}")
            if accept:
                w = (dst / "witness.bin").read_bytes()
                offset = len(b"EEG-WIT\x01") + 32
                expected = [0x1800000, 0x17fffff, 0x1ffffff, 0x1000000, 0]
                if any(int.from_bytes(w[offset+4*k:offset+4*k+4], 'little') != slot for k, slot in enumerate(expected)):
                    raise RuntimeError("incorrect signed-24 or missing encoding")
                if i == 1 and manifest.read_bytes() == (tmp / "0" / "manifest.bin").read_bytes():
                    raise RuntimeError("identical inputs should receive independent hiding blinds")
            print(f"{'accepted' if accept else 'rejected'}: {name}")


if __name__ == "__main__":
    main()
