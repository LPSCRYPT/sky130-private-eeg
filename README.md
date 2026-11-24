# Private EEG window commitment IP · Sky130

**[Anonymous Chipalooza #4 proposal (PDF)](proposal/chipalooza-4-private-eeg.pdf)** · [Target and I/O contract](proposal/proposal.md) · [Measurement plan](proposal/measurement.md) · [Evidence](proposal/evidence.md) · [Reproduction instructions](REPRODUCE.md)

A study wants one number: **how many scheduled two-second windows contained every sample and fewer than five clipped samples?** A participant should not have to upload the waveform—or even disclose which windows failed—to answer. This project connects a hardware commitment to a laptop-verifiable private count.

**Try it as the observer.** This verifies the published ten-minute synthetic session without a witness, recording, signing key or EDA installation:

```sh
v=examples/verified
cargo run --locked --release --manifest-path proof/Cargo.toml -- \
  verify "$v/vk.bin" "$v/device.pub" "$(cat "$v/study-challenge.txt")" 300 "$v/study.bundle"
# verified: 271 of 300 windows passed QC01
```

These are fixed **demo** keys and an archived challenge, not a live attestation. [Verifier contract](proof/PROTOCOL.md) · [hardware signal and command reference](rtl/INTERFACE.md) · [proposal filing checklist](proposal/FILING.md).

| Component | What it does | Boundary |
|---|---|---|
| `rtl/` | Clocked acquisition-side logic commits to 500 ordered signed-24 sample slots, missing indicators, session challenge, window index and fresh blind. | Proposed one-channel digital shuttle IP. Bench wrapper exposes only synthetic test inputs and public outputs; not a secure product port. |
| `proof/` | Recorder reference authenticates the complete ordered root manifest. Groth16 proofs establish each window's rule and link private running totals; the verifier needs no samples or private openings. | Host reference, not ZK acceleration, secure firmware, device provisioning, or a prover running on the proposed silicon. |
| `tests/`, `tools/`, `params/` | HDL regressions, independent integer oracle, versioned Poseidon constants, synthesis and proposal regeneration. | No proprietary EDA required. |
| `examples/oz/` | Attributed public Oz EEG excerpt; converter provides a reproducible data-quality demonstration. | Simulation replay only. Never connect the test hardware to a person. |

**What is trusted?** To interpret a verified count as a recording, trust the capture clock, ADC, private opening source, protected signer and its binding to the hardware roots. The proof checks the digital rule independently; it does not supply that provenance. A complete session means all indices in the *expected signed manifest*, not proof of uninterrupted wall-clock observation. Verification neither reveals the pass/fail pattern nor prevents inference from the disclosed count (in particular, 0 or N reveals every window's status). Do not offer unbounded repeated, overlapping queries on a private recording.

**Integration and status.** This is a separate proposed entry, not a revision of the [analog preamplifier](https://github.com/LPSCRYPT/sky130-eeg-preamp/releases/tag/proposal-v1). Do not connect analog voltages to this digital block. A production one-die system would require an ADC, protected private buffering for the prover, a trusted release controller, authenticated boot, entropy, protected signing, isolation from DMA/debug/scan, and a practical on-die prover. The host proof demo does not meet that hardware boundary. No fabricated chip, PCB or silicon measurements are represented. [Contest rules](https://opencircuitdesign.com/chipalooza/rules-4.html) · [filing instructions](https://opencircuitdesign.com/chipalooza/get-involved.html). A public repository is not an email submission.

Original source and documentation: [Apache-2.0](LICENSE). Public EEG data: [separate attribution and ODC-By 1.0 terms](examples/oz/attribution.json). PDKs, open-source tools and Cargo dependencies retain their upstream licenses.
