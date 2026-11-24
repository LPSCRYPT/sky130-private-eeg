# What a QC01 proof verifies

QC01 counts windows in an ordered recording. A window passes if all 500 scheduled slots contain a sample and at most four samples equal either endpoint of the signed 24-bit range (`0x800000` or `0x7fffff`). A missing slot fails the window even if its other samples are in range. Near-endpoint values do not count as endpoints. This is the only claim the circuit implements.

## From capture to verification

1. The observer specifies the expected number of windows `N` and issues a fresh, unpredictable 128-bit session challenge (`nonce`). In the recorder design, the digital module takes the challenge, window index, samples, presence bits and a fresh secret random value (`blind`). It produces a commitment, called the window *root*: a value the recorder can publish now that binds it to those slots without publishing their contents. The secret blind keeps the root from serving as a way to test guesses about the waveform. The public challenge cannot replace it.
2. A signer outside the module signs the recorder’s ordered list of roots. The owner’s software uses the samples and blinds to produce a zero-knowledge proof for each window: the slots open the signed root, and a hidden running count increases by one if the window passes QC01, or stays the same if it fails. Adjacent proofs must agree on the count between them. Only the starting zero and the final total are opened. The RTL does not sign, generate randomness or run the prover. In the demo, host software plays the recorder and writes the raw witness to a file.
3. The observer’s laptop checks the proof bundle against the independently obtained recorder public key, approved Groth16 verification key, expected challenge and `N`. It checks the signature, indices 0 through `N−1`, every window proof and the two end counts. The result is the total out of `N`; the verifier needs neither the waveform, the window blinds nor a list of which windows passed. For replay protection, the observer must expire challenges and mark an accepted challenge as consumed. The standalone verifier is stateless: given the same expectations, it will accept a valid bundle again.

The verifier learns the session length, policy, total and which recorder key signed the manifest. It sees the ordered roots and count commitments; the protocol does not conceal timing metadata available to the observer. An extreme total, a short session, repeated observations or outside knowledge can reveal individual outcomes. The proof establishes a result about the committed digital sequence, not who or what produced it, when it was sampled, or whether the signer reported a genuine acquisition.

## Wire format

Integers and scalar-field elements (`Fr`) are little endian. The public challenge is written as 32 lowercase hex digits in wire-byte order. Field elements occupy 32 bytes, Ed25519 signatures 64 bytes and arkworks compressed Groth16/BLS12-381 proofs 192 bytes. The verifier uses checked arkworks deserialization and rejects trailing bytes. See the [wire codec](src/wire.rs), [prover and verifier](src/session.rs), and [circuit](src/circuit.rs).

| Record | Fields in order |
|---|---|
| Signed manifest | ASCII `EEG-MANIFEST`, version byte `0x01`, ASCII `QC01`, challenge[16], `N:u16` (1…65,535), `N` pairs of `(index:u16, window_root:Fr)`, Ed25519 signature over all preceding manifest bytes. |
| Public proof bundle | ASCII `EEG-PROOF`, `0x01`, complete signed manifest, initial salt and count commitment (both `Fr`), `N` pairs of `(next_count_commitment:Fr, proof)`, final salt (`Fr`), `total:u16`. Size: `207 + 258*N` bytes, excluding the independently supplied keys. |
| Owner’s reference witness | ASCII `EEG-WIT`, `0x01`, then `N` records of `(blind:Fr, 500 slots:u32)`. This file is an input to the prover, not to the observer. The optional HDL replay bridge also reads it to drive the [public test wrapper](../rtl/INTERFACE.md). It is not a private deployment transport. |

## Commitment arithmetic

A slot is zero if absent, or `(1 << 24) | raw` if present, where `raw` is the 24-bit two’s-complement sample. The circuit constrains presence to one bit, payload to 24 bits, and an absent payload to zero. Ten slots fit in one 250-bit field word without wrapping, earliest slot least significant. The initial state is `Permute([0x45454701 + (index << 32), nonce, blind])`. For each of the 50 words, add it to lane zero and permute the three lanes. The final lane zero is the window root.

For the running count `prefix` after `i` windows, the commitment is lane zero of `Permute([0x43515401 + (i << 32) + (prefix << 48), nonce, salt_i])`. This uses a distinct domain tag and an independent unpredictable field salt for each position. Each proof has five public inputs, in order: challenge, index, signed window root, previous count commitment, next count commitment. The circuit constrains both the previous count and `index − previous_count` to 16 bits. Since `index ≤ N−1`, adding the Boolean QC01 result cannot overflow the counter.

## Assumptions and public examples

Binding the count to the signed sequence relies on signature unforgeability, Groth16 soundness for the approved circuit and collision resistance of both commitments. Hiding the samples and intermediate counts relies on Groth16 zero knowledge, computational hiding of the commitments and secret randomness. A deployment also needs trusted acquisition and timing, protected witness handling and signing keys, and an independently approved setup. The development keys are generated on a host; the project claims neither a trusted setup ceremony nor a certified recorder.

Anyone can recompute the individual decisions in the two published examples: the [Oz replay](../examples/oz/attribution.json) drops slot 610, giving 1/2 passing windows; the [synthetic study](../tools/study_fixture.py) has 14 missing-slot and 15 five-endpoint windows, giving 271/300. The [published bundles](../examples/verified/) verify those totals, but neither the CSV digest nor the generator is a public circuit input. Repeating capture and proving should reproduce the counts, not the roots, signatures or proof bytes.
