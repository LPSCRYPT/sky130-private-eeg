# Proposal release audit · November 24, 2026

**Disposition: the written technical proposal is ready for review.** This is a source and reproducibility audit by the project, not third-party cryptographic certification, foundry sign-off or organizer acceptance. The experiment is a digital commitment core after an ADC. A separate program proves **one** specified quality count; the proposed silicon neither acquires analog EEG nor runs the prover.

The recheck started with a fresh public `proposal-v2` clone, applied the release changes, and used an empty local build directory. No prior netlist, OpenDB placement, prover key or witness was used to regenerate results. [Commands, pinned EDA image and dependencies](../REPRODUCE.md).

| Question | Reproduced result |
|---|---|
| Does the verifier work without a waveform? | `sh tools/check_observer.sh`: all three circuit/decoder tests passed. The generated Poseidon tables matched the RTL ROMs; the native implementation matched two Python known-answer roots. With only public artifacts the recorded EEG example verified **1/2**, the synthetic study **271/300**. The original short receipt was accepted and all 15 modified or mismatched cases were rejected. |
| Can we reproduce the counts, not just play back receipts? | Generated a new development keypair and fresh session challenges. Captured, proved and verified both fixtures: **1/2** (723 bytes) and **271/300** (77,607 bytes). The new 300-window prove took 199.61 s on arm64 with four Rayon workers; this is a repeat, not a throughput guarantee. The Oz input was byte-identical to the SHA-256-pinned upstream excerpt in its [attribution record](../examples/oz/attribution.json). |
| Does the RTL implement the same commitment? | Verilator 5.052 matched **all 32 bytes** of all three [frozen roots](../tests/reference-roots.txt) over the byte-wide fixture, including the missing slot with nonzero ignored data. Finalization took 212,993 clocks from the last tick. In a separate replay, both RTL roots matched the new signed Oz manifest. Values equal to the field modulus or with bit 255 set were rejected for both the replay root and opening before narrowing. Signature verification ran separately. |
| Did timing come from this design? | Rebuilt synthesis, placement, legalization, slow-corner repair and all ten library/clock reports using Yosys 0.70 and OpenROAD 26Q4-407-geb14e40b7. The [CSV](timing.csv), [slack plot](timing.svg) and [placement map](placement.svg) were byte-identical to the previous release. Cell area: 265,427 µm². At 10 MHz the worst setup slack was **+13.916 ns**; at 12 MHz it was **−2.751 ns**. Hold slack was positive in all tested libraries. All are ideal-clock, pre-route estimates. |
| Is the filing document self-contained and anonymous? | Rendered and inspected all six A4 pages. The PDF has no author metadata, embedded attachments or local-file links. The three external link targets are the dataset DOI and two organizer pages. The release PDF uses embedded open fonts; the build now refuses missing figures or substituted body fonts. |

## What changed because of the audit

- The public replay bridge previously passed a 256-bit wire field to a 255-bit RTL input without checking canonical encoding. It now rejects out-of-range openings and roots **before** simulation. The proof verifier already had its own checked field decoder. No RTL, circuit, key or published receipt changed.
- The byte-wrapper bench previously ran only one of the three complete windows. It now runs all three and checks registered readback, ignored sample data and invalid openings. The bench plan also separates average **active power** from the active-minus-idle difference; a shared rail does not establish a macro power rating.
- The CSV reader now parses the exact bytes whose digest it checked. The [verifier contract](../proof/PROTOCOL.md) separates proof of the digital sequence from provenance of a public fixture. The publicly distributed examples are not secret recordings.

## Rule 6: where to look

[Main PDF](chipalooza-4-private-eeg.pdf): block type and purpose on page 1; function and disclosure on page 2; I/O, special pads, target min/nominal/max and absolute **test** limits on page 3; existing evidence on pages 4–5; silicon measurement and acceptance criteria on page 6. The equipment inventory and designer CVs are **separate filing attachments**, not public repository contents.

**Still external:** the posted deadline was November 23. Late consideration, eligibility of a wholly digital block in an analog-IP challenge, slot geometry and pad assignment are not confirmed. No approved designer CV or filing receipt is represented. **Still engineering:** secure acquisition and signing, continuous inter-window buffering, routing and extracted PVT, DRC/LVS, wrapper integration, silicon power and bench measurements. None of those results is claimed here. [Official rules and filing checklist](FILING.md).
