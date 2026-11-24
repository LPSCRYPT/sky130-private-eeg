#!/bin/sh
# Receiver-side release check. Does not generate a recorder key or read a witness.
set -eu
cd "$(dirname "$0")/.."
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-"$PWD/build/cargo"}
export RAYON_NUM_THREADS=${RAYON_NUM_THREADS:-4}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
cargo test --locked --release --manifest-path proof/Cargo.toml
cargo build --locked --release --manifest-path proof/Cargo.toml
q=$CARGO_TARGET_DIR/release/eeg-proof
cargo run --quiet --locked --release --manifest-path tools/paramgen/Cargo.toml -- "$tmp"
cmp params/ark.hex "$tmp/ark.hex"
cmp params/mds.hex "$tmp/mds.hex"
python3 tools/reference_roots.py > "$tmp/oracle"
head -n 2 "$tmp/oracle" > "$tmp/two-roots"
"$q" roots > "$tmp/prover-roots"
cmp "$tmp/two-roots" "$tmp/prover-roots"
v=examples/verified
check_bundle() {
    msg=$("$q" verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/$1-challenge.txt")" "$2" "$v/$1.bundle")
    printf '%s\n' "$msg"
    [ "$msg" = "verified: $3 of $2 windows passed QC01" ]
}
check_bundle oz 2 1
check_bundle study 300 271
python3 proof/tests/reject.py "$q" "$v/vk.bin" "$v/device.pub" "$(cat "$v/oz-challenge.txt")" 2 "$v/oz.bundle"
