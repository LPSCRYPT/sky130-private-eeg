# November 24, 2026 release checks

These are the project’s results from the November 24 release check. It examined two parts of private EEG verification: whether the recorder-side RTL committed to the same digitized samples as the software, and whether a laptop could verify the QC01 count using only public artifacts. The run started with a fresh public `proposal-v2` clone, the release changes and an empty build directory. It used no prior netlist, placement database, proving key or witness to regenerate results. See the [commands, pinned EDA image and dependencies](../REPRODUCE.md).

## Proof and capture

- `sh tools/check_observer.sh`: all three circuit/decoder tests passed. Generated Poseidon tables matched the RTL ROMs, and the native implementation matched two Python known-answer roots. The observer verified 1/2 passing windows for the recorded Oz example and 271/300 for the synthetic study. The original short receipt passed; all 15 modified or mismatched cases failed.
- With a new development keypair and fresh session challenges, capture, proving and verification reproduced both counts. The bundles were 723 and 77,607 bytes respectively. Proving the 300-window session took 199.61 s on arm64 with four Rayon workers. The Oz input matched the SHA-256-pinned excerpt in its [attribution record](../examples/oz/attribution.json) byte for byte.
- Verilator 5.052 reproduced all 32 bytes of each of the three [reference roots](../tests/reference-roots.txt) through the byte-wide test wrapper, including the window with nonzero data on a missing slot. Publication took 212,993 clocks after the last tick. In a separate Oz replay, both RTL roots matched the newly signed manifest; signature verification ran separately. The replay bridge rejected both a value equal to the field modulus and a value with bit 255 set for each of the opening and root.

## Placement and document

The run repeated synthesis, placement, legalization, slow-corner timing repair and all ten library/clock reports with Yosys 0.70 and OpenROAD 26Q4-407-geb14e40b7. The [timing CSV](timing.csv), [slack plot](timing.svg) and [placement map](placement.svg) were byte-identical to the preceding release. Cell area was 265,427 µm². Worst setup slack was +13.916 ns at 10 MHz and −2.751 ns at 12 MHz; hold slack was positive in all tested libraries. These were ideal-clock, pre-route estimates, not silicon measurements.

The PDF inspected in that run had six A4 pages, embedded open fonts, no author metadata, attachments or local-file links, and three external link targets (the dataset DOI and two organizer pages). The release build included checks for missing figures and substituted body fonts. These observations describe that rendering, not subsequent editions of the [proposal](chipalooza-4-private-eeg.pdf).

## Changes made in that release

- The replay bridge began checking canonical encoding before narrowing 256-bit wire fields to 255-bit RTL inputs. The verifier already checked its field decoder. No RTL, circuit, key or published receipt changed.
- The byte-wrapper bench was extended from one window to all three and checked registered readback, ignored sample data and invalid openings. The silicon plan distinguished average active power from the active-minus-idle difference on a shared rail.
- The CSV reader was changed to parse the exact bytes whose digest it checked. The [verifier contract](../proof/PROTOCOL.md) distinguished proof of a digital sequence from provenance of a public fixture.

For Rule 6, the inspected edition covered block type and purpose (p. 1), function and disclosure (p. 2), I/O, special pads, min/nominal/max targets and absolute test limits (p. 3), engineering evidence (pp. 4–5), and silicon measurements and acceptance criteria (p. 6). The equipment inventory and CVs belong in separate filing attachments. The run did not establish recorder security, continuous acquisition, routing or extracted PVT, DRC/LVS, wrapper integration, or silicon performance and power. See the [filing notes](FILING.md) for the public contest requirements.
