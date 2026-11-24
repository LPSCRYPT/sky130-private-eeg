# November 24, 2026 release checks

This check started from a fresh public `proposal-v2` clone with the release changes applied and an empty build directory. It regenerated the proofs and placement without reusing earlier keys, witnesses or netlists. [Commands and tool versions](../REPRODUCE.md).

## Proof and capture

- `sh tools/check_observer.sh`: all three circuit/decoder tests passed. Generated Poseidon tables matched the RTL ROMs, and the native implementation matched two Python known-answer roots. The observer verified 1/2 passing windows for the recorded Oz example and 271/300 for the synthetic study. The original short receipt passed; all 15 modified or mismatched cases failed.
- With a new development keypair and fresh session challenges, capture, proving and verification reproduced both counts. The bundles were 723 and 77,607 bytes respectively. Proving the 300-window session took 199.61 s on arm64 with four Rayon workers. The Oz input matched the SHA-256-pinned excerpt in its [attribution record](../examples/oz/attribution.json) byte for byte.
- Verilator 5.052 reproduced all 32 bytes of each of the three [reference roots](../tests/reference-roots.txt) through the byte-wide test wrapper, including the window with nonzero data on a missing slot. Publication took 212,993 clocks after the last tick. In a separate Oz replay, both RTL roots matched the newly signed manifest; signature verification ran separately. The replay bridge rejected both a value equal to the field modulus and a value with bit 255 set for each of the opening and root.

## Placement

The run repeated synthesis, placement, legalization, slow-corner timing repair and all ten library/clock reports with Yosys 0.70 and OpenROAD 26Q4-407-geb14e40b7. The [timing CSV](timing.csv), [slack plot](timing.svg) and [placement map](placement.svg) were byte-identical to the preceding release. Cell area was 265,427 µm². Worst setup slack was +13.916 ns at 10 MHz and −2.751 ns at 12 MHz; hold slack was positive in all tested libraries. These were ideal-clock, pre-route estimates, not silicon measurements.
