# Reproduce the endpoint

Use the project root as working directory. No hardware purchase, confidential file, AI service or live electrode signal is required. All public known-answer values, seeds and replay data are **test-only**.

## RTL and independent known answers

Use the published `hpretl/iic-osic-tools:2026.10` image (the digest below was used on arm64). Docker must be allowed to mount this checkout. These commands use Docker's active context.

```sh
img=hpretl/iic-osic-tools@sha256:4091b82d77a63e61ff29f4f6de9fd5f00935ae5163c3144d373f6443f7af01c1
docker run --rm -d --name eeg-quality -v "$PWD:/foss/designs" "$img" --wait
eda() { docker exec -w /foss/designs eeg-quality bash -lc 'exec "$@"' eda "$@"; }
eda sh tools/check_capture.sh
eda sh tools/map_area.sh
eda sta -exit tools/timing.tcl
eda openroad -threads 3 -exit tools/place.tcl
eda openroad -threads 3 -exit tools/repair_slow.tcl
for corner in tt_025C_1v80 ss_n40C_1v60 ss_100C_1v60 ff_n40C_1v95 ff_100C_1v95; do
  eda env EEG_LIB_CORNER="$corner" EEG_PLACEMENT_DB=build/corner-optimized.odb openroad -threads 2 -exit tools/corners.tcl
  eda env EEG_LIB_CORNER="$corner" EEG_PERIOD_NS=100 EEG_PLACEMENT_DB=build/corner-optimized.odb openroad -threads 2 -exit tools/corners.tcl
done
docker stop eeg-quality
```

`check_capture.sh` runs an independent Python integer implementation and checks the parallel and byte-wide interfaces against complete 500-slot roots. `map_area.sh` uses the Sky130A high-density typical/25 °C/1.80 V standard-cell Liberty. The initial unbuffered map fails timing. Placement, control-net buffering, slow-cold resizing and five-library STA use estimated layer RC and an ideal clock; there is no CTS, detailed routing or extracted sign-off. The floorplan is a **trial rectangle**, not an organizer-assigned slot.

## Proof/verifier reference on a host

Install stable Rust and Cargo. Start in a fresh, non-public build directory. Development setup generates a **new** recorder identity and Groth16 keypair; an independent verifier must pin the expected recorder public key and verification key in advance, not take them from a proof sender. No private key, PK/VK from a trusted ceremony or witness is distributed here.

```sh
export CARGO_TARGET_DIR="$PWD/build/cargo" RAYON_NUM_THREADS=4
cargo build --locked --release --manifest-path proof/Cargo.toml
q="$CARGO_TARGET_DIR/release/eeg-proof"
mkdir -p build/demo
"$q" setup build/demo/keys
nonce=$("$q" challenge)
python3 tools/replay_slots.py --drop-slot 610 > build/demo/slots.txt
"$q" capture build/demo/keys/device.sk "$nonce" 2 build/demo/slots.txt build/demo/private
"$q" prove build/demo/keys/pk.bin build/demo/private/manifest.bin build/demo/private/witness.bin build/demo/public.bundle
# Receiver: only these two approved public keys, its challenge, expected length and bundle.
"$q" verify build/demo/keys/vk.bin build/demo/keys/device.pub "$nonce" 2 build/demo/public.bundle
```

For the full 300-window digital study, replace the capture/prove/verify part with:

```sh
nonce=$("$q" challenge)
python3 tools/study_fixture.py > build/demo/study.txt
"$q" capture build/demo/keys/device.sk "$nonce" 300 build/demo/study.txt build/demo/study-private
"$q" prove build/demo/keys/pk.bin build/demo/study-private/manifest.bin build/demo/study-private/witness.bin build/demo/study.bundle
"$q" verify build/demo/keys/vk.bin build/demo/keys/device.pub "$nonce" 300 build/demo/study.bundle
```

To verify **without setting up keys or generating samples**, build the binary as above, then use the included public verifier-only examples. These recorded challenges check reproducibility, not freshness:

```sh
v=examples/verified
"$q" verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/oz-challenge.txt")" 2 "$v/oz.bundle"
"$q" verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/study-challenge.txt")" 300 "$v/study.bundle"
python3 proof/tests/reject.py "$q" "$v/vk.bin" "$v/device.pub" "$(cat "$v/oz-challenge.txt")" 2 "$v/oz.bundle"
```

To check the recorded-signal bridge, after the two-window capture start the EDA container as above and run `eda python3 tools/check_record.py build/demo/private`. This public-fixture test feeds the actual slots, nonce and blinds to the parallel RTL input and compares **every root bit** to the signed manifest, independently of the software hash. It is not how a private production recorder should handle openings.

The recorded excerpt is Schalk, *EEG Motor Movement/Imagery Dataset*, PhysioNet, [DOI 10.13026/C28G6P](https://doi.org/10.13026/C28G6P), S001 R02 Oz, 10–14 s. [Attribution and upstream conversion](examples/oz/attribution.json), [ODC-By 1.0](https://opendatacommons.org/licenses/by/1-0/). The converter checks the source SHA-256; each 160 Hz source value is held on a 250 Hz replay schedule. One simulated ADC code is 1 nV, rounded to nearest ties-to-even. This does **not** create new physiological information or establish ADC resolution. Injecting the single missing slot makes exactly one of the two windows pass. Without injection both pass. Nothing in this public demo is personal or confidential.

`fixture` can replace `capture` for generated stimulus. `roots` produces the two deterministic known-answer roots (indices 0 and 1); compare with the first two lines of `python3 tools/reference_roots.py`. The actual proof/capture demo uses fresh private blinding, not these KAT openings.

## Regenerate field parameters and proposal

```sh
mkdir -p build/params
cargo run --locked --manifest-path tools/paramgen/Cargo.toml -- build/params
cmp params/ark.hex build/params/ark.hex && cmp params/mds.hex build/params/mds.hex
sh tools/build_proposal.sh  # Pandoc 3+, WeasyPrint, DejaVu Sans
```

`params/` is generated by the version-pinned arkworks Grain-LFSR routine for BLS12-381 Fr, t=3, 8 full and 57 partial rounds, first MDS candidate. Source and ROM entries are public and versioned. These routines and the specified custom protocol have not been independently audited or certified. Never use the development host setup, readable files, or exposed digital fixture bus as a production trust boundary.
