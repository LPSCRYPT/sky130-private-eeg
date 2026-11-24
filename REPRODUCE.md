# Reproduce the private EEG demo

To check the example as an observer, run `sh tools/check_observer.sh` from the project root. You'll need stable Rust, Cargo, Python 3 and a POSIX shell. You don't need a recording, a signing key or an EEG device. The script verifies the two public proof bundles, tests the circuit and its rejection cases, and compares the generated Poseidon constants and two roots against independent implementations.

To check the hardware or make a proof from scratch, use the steps below. The examples use public EEG or synthetic samples, never a live electrode signal.

## RTL and independent known answers

Use the published `hpretl/iic-osic-tools:2026.10` image (the digest below was used on arm64). Docker must be allowed to mount this checkout. These commands use Docker's active context.

```sh
img=hpretl/iic-osic-tools@sha256:4091b82d77a63e61ff29f4f6de9fd5f00935ae5163c3144d373f6443f7af01c1
docker run --rm -d --name eeg-quality -v "$PWD:/foss/designs" "$img" --wait
eda() { docker exec -w /foss/designs eeg-quality bash -lc 'exec "$@"' eda "$@"; }
eda sh tools/check_capture.sh
eda sh tools/rebuild_placement.sh
docker stop eeg-quality
```

`check_capture.sh` checks the parallel and byte-wide inputs against three fixed reference outputs. `rebuild_placement.sh` regenerates the placement-density map and timing plot from the placed database and ten pre-route timing reports. These estimates use an ideal clock; they are not routing or silicon measurements.

## Make a proof from a recording

The following example creates a development recorder identity and Groth16 keypair. Use a fresh `build/demo` directory and keep it private: the recorder writes both a signing key and the samples used to make the proof. In a real session the observer must obtain the two expected public keys independently of whoever sends the bundle.

```sh
umask 077
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

To check the published recordings without generating keys or samples, use the verifier binary from the build step above. These commands use the original challenges so the results are repeatable:

```sh
v=examples/verified
"$q" verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/oz-challenge.txt")" 2 "$v/oz.bundle"
"$q" verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/study-challenge.txt")" 300 "$v/study.bundle"
python3 proof/tests/reject.py "$q" "$v/vk.bin" "$v/device.pub" "$(cat "$v/oz-challenge.txt")" 2 "$v/oz.bundle"
```

To compare the actual RTL output with the software commitment, keep the short capture and restart the EDA container. Run `eda python3 tests/check_replay_fields.py build/demo/private`, then `docker stop eeg-quality`. The bench compares both roots with the manifest. It also rejects copies with an invalid high bit in the root or opening. The simulator sees private openings in this test; use only public fixtures. The separate `verify` command, not the RTL bench, authenticates the manifest.

The replay uses four seconds of Schalk's *EEG Motor Movement/Imagery Dataset*: [PhysioNet, S001 R02, Oz, 10–14 s](https://doi.org/10.13026/C28G6P). The converter checks the source SHA-256 and holds each 160 Hz reading until the next one on a 250 Hz clock. One simulated ADC count represents 1 nV (nearest, ties to even); that's an encoding choice, not a claim of sensor precision. With slot 610 marked missing, one window passes; with the original data, both pass. [Attribution and conversion](examples/oz/attribution.json) · [Dataset license](https://opendatacommons.org/licenses/by/1-0/).

`fixture` can replace `capture` for generated stimulus. `roots` produces the two deterministic known-answer roots (indices 0 and 1); compare with the first two lines of `python3 tools/reference_roots.py`. The actual proof/capture demo uses fresh private blinding, not these KAT openings.

## Regenerate field parameters and proposal

```sh
mkdir -p build/params
cargo run --locked --manifest-path tools/paramgen/Cargo.toml -- build/params
cmp params/ark.hex build/params/ark.hex && cmp params/mds.hex build/params/mds.hex
python3 tools/plot_replay.py  # regenerate the public EEG input figure, including the injected gap
sh tools/build_proposal.sh  # Pandoc, WeasyPrint, Fontconfig, DejaVu Sans and Sans Mono
```

The release PDF was built with Pandoc 3.8.2, WeasyPrint 68.1 and DejaVu fonts (`fonts-dejavu-core` on Debian/Ubuntu).

`params/` comes from the version-pinned arkworks Grain-LFSR routine for BLS12-381 Fr: width 3, eight full rounds, 57 partial rounds, first MDS candidate. The protocol and its implementation have not had an independent cryptographic audit. The hardware test bus and the host's development key files are not secure recorder interfaces.
