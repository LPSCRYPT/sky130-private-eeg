# Private EEG verification

<p class="subtitle">A recorder-side cryptographic module for digitized EEG</p>

The owner of an EEG recording can use this module to prove a claim about the recording without handing a researcher the waveform. Hardware in the recorder commits to the digitized samples as they arrive. Later, the owner’s software uses those samples to produce a proof, and the researcher checks it on a laptop.

The proposed Sky130 digital block sits on the output of an analog-to-digital converter (ADC). For each window of 500 scheduled conversions it combines the readings, including any missing flags, with a fresh secret random value. The 32-byte result is a *commitment*, or root. It fixes the sequence without publishing it: the owner can later show that the sequence fits the root, but cannot feasibly substitute a different one. Someone with just the root cannot test a guess about the waveform without also guessing the secret.

![The shaded core is the proposed hardware; its bench wrapper is not shown. The observer receives signed roots and a proof bundle, not the inputs to the owner’s proving software.](boundary.svg)

For example, a researcher may need only the number of two-second windows with every sample present and no more than four readings at the converter’s limits. The recorder signs the ordered roots. Using the samples and secret openings, the owner produces a *zero-knowledge proof* that the stated count follows from those same roots. The researcher, acting as the observer, checks the signature and proof without receiving the waveform. This counting rule, QC01, is the only claim implemented.

## The silicon experiment

Run one known sequence at 250 slots/s, replace one conversion with a missing flag, and compare the two roots with predictions. Measure the clock margin and the time needed to finish a window. Placing this function on the sample bus gives a recorder a fixed place to account for missing conversions before application software sees the stream. The chip is neither a certified recorder nor a trusted execution environment. It contains no ADC, entropy source, signer or prover. Its test wrapper exposes its inputs and is for public bench signals only.

<div class="newpage"></div>

## From the sample bus to the proof

### Capturing a window

One channel supplies signed 24-bit readings. A timer issues 500 ticks per window: a tick means a conversion was due, not that a packet arrived. At each tick the core records either a reading or a missing conversion. It distinguishes a valid reading of zero from a missing slot, but it cannot detect a stopped external timer.

1. On a separate start edge, load a 128-bit verifier challenge, a 16-bit zero-based window index and a fresh secret field element (the opening). The challenge is public; it cannot substitute for the opening. Only fixed public tests may use known openings.
2. Encode a present reading as `2^24 + unsigned(raw24)`; encode a missing slot as zero regardless of bus data. Pack ten successive 25-bit codes into one field word, earliest in the least significant bits. The resulting 50 words are each 250 bits and fit without reduction.
3. In the BLS12-381 scalar field, initialize the three-element state with `0x45454701 + index × 2^32`, the little-endian challenge integer and the opening. Apply the Poseidon permutation once. Add each packed word to element zero in the field and permute again. One shared multiplier implements the permutation: eight full rounds, 57 partial rounds, exponent five and versioned constants. The length and domain are fixed. The root is final element zero.
4. Read only when `root_valid` is high. A reset, conflicting start or unserviceable tick while busy aborts the window without a valid root. A new window must wait for finalization. Gapless capture would require a private buffer across finalization and rearming, outside this block.

### Checking the count

QC01 counts a window if all 500 slots are present and at most four readings equal a signed rail (−8,388,608 or +8,388,607). A fifth rail reading fails the window; a near-rail reading is not a rail hit. This measures completeness and digital clipping, not electrode contact or clinical signal quality.

For each signed root the owner proves two things together: the private slots and opening reproduce that root, and applying QC01 adds the correct zero or one to the running count. Commitments hide the intermediate counts and link consecutive proofs. The observer checks the links, the initial zero and the final total against an independently expected session length, challenge, recorder public key and QC01 circuit key. A different claim would require another approved circuit and key.

The observer learns the total, session length and recorder identity, but receives no per-window flags. A total of zero or a perfect score still reveals every outcome. The signature authenticates the recorder’s assertion about a digital sequence. It does not establish a human source, honest sampling or uninterrupted capture.

<div class="newpage"></div>

## Interfaces and operating targets

| Boundary | Inputs | Outputs |
|-----------|---------------------------|----------------------|
| Capture core | Clock, synchronous active-high reset, start; challenge[127:0], index[15:0], blind[254:0]; slot tick, sample present, raw[23:0]. | Busy, ready, root-valid, root[254:0] (32 bytes padded). No sample, pass flag or opening readback. |
| Test wrapper | Two dedicated digital inputs requested: `clk`, synchronous `strobe`. Twelve held controls: `rst`, `op[2:0]`, `din[7:0]`. | Eleven sense bits: `dout[7:0]`, `busy`, `ready`, `root_valid`. |
| Supplies and pads | 1.8 V core and ground; standard protected digital pads for the 3.3 V periphery. No shared analog line, reference current or low-resistance path requested. | Package pins are unassigned. The organizer must confirm the two pads, slot outline and control-bus latency. |

The pattern generator supplies clock and strobe while the harness holds the command and data stable. A high strobe executes a command on *every* rising edge. This byte-wide interface makes both the sample and its opening visible; a private recorder would use the capture core directly.

| Target / condition | Minimum | Nominal | Maximum / limit |
|--------------------|----------:|----------:|-----------------:|
| Core supply target (V) | 1.62 | 1.80 | 1.98 |
| Operating temperature target (°C) | −40 | 25 | +110 |
| Application sample slots/s in window | 250 | 250 | 250 (fixed profile) |
| Scheduled slots/window; duration | 500; 2 s | 500; 2 s | 500; 2 s |
| Core clock within a window | 5.325 MHz arithmetic service floor | 12 MHz target | Silicon maximum unmeasured |
| Present input, signed 24-bit code | −8,388,608 | signal dependent | +8,388,607 |
| Session count reported, for N authenticated windows | 0 | input dependent | N; demo tool N ≤ 65,535 |
| Normal root output / complete window | 32 B | 32 B | 32 B |
| Standalone trial footprint (mm²) | — | 0.4938 outer rectangle | 0.55 budget; slot not assigned |
| Core power, 12 MHz QA workload | — | — | 20 mW average active target; unmeasured |

### Absolute test limits

Drive a powered core only, between VSS and its actual VDD; never apply 3.3 V to a core net. Do not exceed 1.98 V or the stated temperature range. These are test limits, not foundry stress or ESD ratings. Confirm package pin ratings, current limits and power sequencing with the harness owner before power-up.
