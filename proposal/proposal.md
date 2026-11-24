# A commitment core for EEG recorders

**Chipalooza Challenge #4 · Sky130 · Digital IP for the ADC output bus**

An EEG study sometimes needs a count, not a recording: *how many two-second windows had every sample present and fewer than five clipped readings?* A researcher could compute that number by collecting the whole waveform. Here the recorder commits to the samples as they arrive. Later, the researcher can check the count without receiving them.

**The proposed silicon has one job.** On each of 500 scheduled ticks it accepts a 24-bit digitized sample or a missing-conversion flag. It mixes the ordered sequence with a fresh private random value and emits a 32-byte commitment called the *root*. A valid zero reading is different from a missing conversion. The private randomness prevents a verifier from checking waveform guesses against the root alone.

![Only the commitment engine and its public-data test wrapper are proposed for the shuttle. Acquisition, signing and proof generation are separate jobs.](boundary.svg)

**Why put it next to the ADC?** Firmware could compute the same function. A reusable hardware block gives a recorder a fixed point on the sample bus where a missing conversion is accounted for before an application can discard the window. It still needs a trustworthy clock, ADC and signer. This proposal is not an amplifier, digitizer, secure element or on-chip prover.

**The silicon experiment:** drive the block with a known sequence at 250 slots/s, change one conversion from present to missing, then read back the predicted root in each case. Measure the clock margin and the delay before another window can start. The laptop proof is a consumer of those roots, not the outcome of that electrical test. All testing uses bench signals.

<div class="newpage"></div>

## From sample tick to root

The input tick means *a conversion was due*, not *a packet arrived*. A trusted timer supplies 500 ticks per window. On a tick without a conversion, the core commits an explicit missing slot. It cannot detect a stopped external clock or tell whether a sensor supplied the data.

1. Start with a 128-bit verifier challenge, a 16-bit zero-based index and a fresh secret field element. Never reuse openings between windows. For fixed public tests only, openings may be known. Start and data commands are separate clock events.
2. For a present reading encode `2^24 + unsigned(raw24)`; encode zero for missing, ignoring bus data. Pack ten successive 25-bit codes into one field word, earliest in the least significant bits. All 250-bit packed words fit the field without reduction. Exactly 50 words per window.
3. The field is the BLS12-381 scalar field. Initialize a three-element state with `0x45454701 + index × 2^32`, challenge interpreted as a little-endian unsigned integer, and the blind. Permute once. For each packed word add it to state element zero in the field and permute again. Emit only final element zero. Use Poseidon with eight full rounds, 57 partial rounds, exponent five and versioned constants. The input length and domain are fixed; this is not a general-purpose variable-length hash API.
4. Read the root only when `root_valid` is high. Reset, a conflicting start or an unserviceable tick while busy aborts the window without publishing a root. A new window cannot start until the previous one finishes. A recorder that needs gapless acquisition must buffer incoming slots privately during this handoff.

### What the laptop learns

The example rule, **QC01**, counts a window only if all 500 slots are present and at most four raw codes equal either signed rail (−8,388,608 or +8,388,607). A fifth rail sample fails the window. This tests digital clipping and completeness; it says nothing about electrode contact, signal quality in general or a participant’s intent.

Outside the proposed IP, a recorder signs the ordered roots. A zero-knowledge proof checks each window against its root and adds either zero or one to a hidden running count. The verifier checks every link, a starting count of zero and the final total. It supplies its own expected challenge, session length, recorder identity and proof-verification key. Omitting a window or changing the total breaks verification.

The observer receives the total, not a separate pass flag for each window. A count of zero or a perfect score nevertheless reveals every outcome. A signature authenticates the recorder’s assertion; it does not establish that the source was a person or that capture was continuous.

<div class="newpage"></div>

## I/O and test limits

| Boundary | Inputs | Outputs |
|-----------|---------------------------|----------------------|
| Reusable IP | Clock, synchronous active-high reset, start; nonce[127:0], index[15:0], blind[254:0]; slot tick, sample present, raw[23:0]. | Busy, ready, root-valid, root[254:0] (32 bytes padded). No raw, pass flag or blind readback. |
| Test wrapper | 2 dedicated digital input pads requested: `clk`, synchronous `strobe`. 12 held controls: `rst`, `op[2:0]`, `din[7:0]`. | 11 sense bits: `dout[7:0]`, `busy`, `ready`, `root_valid`. |
| Supplies and pads | 1.8 V digital core and ground. Standard protected digital pads for the 3.3 V periphery; no shared analog lines, reference currents or low-resistance path requested. | No package pins are assigned. The organizer must confirm two pads, the slot outline and control-bus latency. |

**One command per strobed edge.** A pattern generator supplies clock and strobe; the harness holds the command and data stable. Holding strobe high repeats a command. The test loader makes the stimulus and opening visible; it is for public vectors, not a patient interface or a production debugging port.

| Target / condition | Minimum | Nominal | Maximum / limit |
|--------------------|----------:|----------:|-----------------:|
| Core supply target (V) | 1.62 | 1.80 | 1.98 |
| Operating temperature target (°C) | −40 | 25 | +110 |
| Application sample slots/s in window | 250 | 250 | 250 (fixed profile) |
| Scheduled slots/window; duration | 500; 2 s | 500; 2 s | 500; 2 s |
| Core clock within a window | 5.325 MHz arithmetic service floor | 12 MHz target | Silicon maximum unmeasured |
| Encoded input, present | −8,388,608 | signal dependent | +8,388,607 |
| Session count reported, for N authenticated windows | 0 | input dependent | N; demo tool N ≤ 65,535 |
| Normal root output / complete window | 32 B | 32 B | 32 B |
| Standalone trial footprint (mm²) | — | 0.4938 outer rectangle | 0.55 budget; slot not assigned |
| Core power, 12 MHz QA workload | — | — | 20 mW average active target; unmeasured |

**Absolute test limits:** only drive a powered core, between VSS and actual VDD. No direct 3.3 V signals. Do not exceed 1.98 V or the stated temperature range. These are test limits, not foundry stress or ESD ratings; confirm package pin, current and sequencing ratings with the harness owner before power-up. No silicon ratings, slot assignment or power measurement are claimed.
