"""Exercise the public CLI on a real previously produced N>=2 bundle (no witness)."""
import argparse
from pathlib import Path
import subprocess
import tempfile


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for name in ("binary", "vk", "device_pub", "challenge", "count", "bundle"):
        p.add_argument(name)
    args = p.parse_args()
    n = int(args.count)
    if n < 2:
        p.error("need at least two real proofs to test ordering and omissions")
    source = Path(args.bundle).read_bytes()
    prefix = len(b"EEG-PROOF\x01")
    records = prefix + len(b"EEG-MANIFEST\x01QC01") + 16 + 2
    sig = records + n * 34
    salt0 = sig + 64
    steps = salt0 + 32 + 32
    size = 32 + 192  # link and compressed Groth16 A/B/C
    if len(source) != steps + n * size + 32 + 2:
        p.error("unexpected bundle length")

    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "case.bundle"

        def check(name, data, *, expected=False, ch=args.challenge, count=n, key=args.device_pub):
            path.write_bytes(data)
            process = subprocess.run([args.binary, "verify", args.vk, key, ch, str(count), path],
                                     stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if (process.returncode == 0) != expected or process.returncode < 0:
                raise RuntimeError(f"{name}: unexpected exit {process.returncode}: {process.stderr}")
            print(f"{'accepted' if expected else 'rejected'}: {name}")

        def change(offset, replacement):
            return source[:offset] + replacement + source[offset + len(replacement):]

        def flip(offset):
            return change(offset, bytes([source[offset] ^ 1]))

        check("original", source, expected=True)
        altered = bytearray.fromhex(args.challenge)
        altered[0] ^= 1
        check("replay against a fresh challenge", source, ch=altered.hex())
        check("wrong expected session length", source, count=n-1)
        alternate = Path(tmp) / "other.pub"
        # Valid unrelated Ed25519 public key from RFC 8032, test vector 1.
        alternate.write_bytes(bytes.fromhex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a"))
        check("untrusted device identity", source, key=alternate)
        check("changed signature", flip(sig))
        check("different policy", flip(prefix + len(b"EEG-MANIFEST\x01")))
        check("substituted signed root", change(records + 2, source[records + 36:records + 68]))
        check("reordered indexed manifest", change(records, source[records+34:records+68] + source[records:records+34]))
        check("truncated signed manifest", source[:records] + source[records+34:])
        check("changed initial counter opening", change(salt0, bytes(32)))
        check("broken hidden chain", change(steps, source[salt0+32:salt0+64]))
        check("swapped proofs under genuine manifest", change(steps+32, source[steps+size+32:steps+2*size]))
        check("omitted proof", source[:steps] + source[steps+size:])
        check("changed final counter opening", change(len(source)-34, bytes(32)))
        check("wrong published aggregate", change(len(source)-2, (int.from_bytes(source[-2:], 'little') ^ 1).to_bytes(2, 'little')))
        check("extra transcript bytes", source + b"\0")


if __name__ == "__main__":
    main()
