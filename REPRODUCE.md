# Reproduce the endpoint

Use the project root as working directory. No hardware purchase, confidential file, AI service or live electrode signal is required. All public known-answer values, seeds and replay data are **test-only**.

**Observer-only release check:** `sh tools/check_observer.sh` (stable Rust/Cargo, Python 3 and a POSIX shell). It exercises the circuit tests, rebuilds the Poseidon constants, cross-checks two independent roots, verifies both published counts and rejects altered transcripts. It needs no signing key or witness. The [release audit](proposal/AUDIT.md) records which checks also ran with fresh captures and a fresh SKY130 placement.

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

`check_capture.sh` checks the Python oracle against three frozen roots, then exercises the parallel and byte-wide interfaces. `rebuild_placement.sh` maps at typical/25 °C/1.80 V and regenerates `proposal/{placement.svg,timing.svg,timing.csv}` from the cell placement and ten timing reports. Run it in a disposable checkout if comparing against a release. The unbuffered map fails timing. The placed results use estimated RC and an ideal clock: no CTS, detailed routing or extracted sign-off. The floorplan is a trial rectangle, not an assigned slot.

## Proof/verifier reference on a host

Install stable Rust and Cargo. Run from the checkout; keep the generated `build/demo` private. Development setup generates a new recorder identity and Groth16 keypair. A live verifier must pin the expected recorder public key and verification key independently, not take them from a proof sender. The repository contains public **development** verification keys, but no private signing key, production ceremony key material or private witness.

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

To verify **without setting up keys or generating samples**, build the binary as above, then use the included public verifier-only examples. These recorded challenges check reproducibility, not freshness:

```sh
v=examples/verified
"$q" verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/oz-challenge.txt")" 2 "$v/oz.bundle"
"$q" verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/study-challenge.txt")" 300 "$v/study.bundle"
python3 proof/tests/reject.py "$q" "$v/vk.bin" "$v/device.pub" "$(cat "$v/oz-challenge.txt")" 2 "$v/oz.bundle"
```

After the two-window capture, start the EDA container as above and run `eda python3 tests/check_replay_fields.py build/demo/private`, then `docker stop eeg-quality`. It runs `tools/check_record.py` on the real fixture and on copies with an invalid high bit in the root or opening. The decoder rejects noncanonical field encodings before RTL input. On the original, the bench compares both complete RTL roots to the manifest. It does **not** authenticate that manifest; the separate `verify` command checks its signature and expected challenge. Supplying openings to the simulator is appropriate only for public fixtures.

The recorded excerpt is Schalk, *EEG Motor Movement/Imagery Dataset*, PhysioNet, [DOI 10.13026/C28G6P](https://doi.org/10.13026/C28G6P), S001 R02 Oz, 10–14 s. [Attribution and upstream conversion](examples/oz/attribution.json), [ODC-By 1.0](https://opendatacommons.org/licenses/by/1-0/). The converter checks the source SHA-256; each 160 Hz source value is held on a 250 Hz replay schedule. One simulated ADC code is 1 nV, rounded to nearest ties-to-even. This does **not** create new physiological information or establish ADC resolution. Injecting the single missing slot makes exactly one of the two windows pass. Without injection both pass. Nothing in this public demo is personal or confidential.

`fixture` can replace `capture` for generated stimulus. `roots` produces the two deterministic known-answer roots (indices 0 and 1); compare with the first two lines of `python3 tools/reference_roots.py`. The actual proof/capture demo uses fresh private blinding, not these KAT openings.

## Regenerate field parameters and proposal

```sh
mkdir -p build/params
cargo run --locked --manifest-path tools/paramgen/Cargo.toml -- build/params
cmp params/ark.hex build/params/ark.hex && cmp params/mds.hex build/params/mds.hex
python3 tools/plot_replay.py  # regenerate the public EEG input figure, including the injected gap
sh tools/build_proposal.sh  # Pandoc, WeasyPrint, Fontconfig, DejaVu Sans and Sans Mono
```

The release PDF uses Pandoc 3.8.2, WeasyPrint 68.1 and DejaVu fonts. On Debian/Ubuntu the font package is `fonts-dejavu-core`. The builder rejects font substitution or missing figures instead of silently publishing a different document. Renderer and font versions can affect PDF bytes; use the GitHub release asset digest to verify the distributed copy.

`params/` is generated by the version-pinned arkworks Grain-LFSR routine for BLS12-381 Fr, t=3, 8 full and 57 partial rounds, first MDS candidate. Source and ROM entries are public and versioned. These routines and the specified custom protocol have not been independently audited or certified. Never use the development host setup, readable files, or exposed digital fixture bus as a production trust boundary.
