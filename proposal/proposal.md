# Private EEG verification

<p class="subtitle">A recorder-side commitment core for Sky130</p>

A participant wants to tell a lab how much of an EEG recording arrived without gaps or excessive clipping. Sending the waveform would let the lab count for itself, but would also give it samples the participant did not agree to share. Sending just a count would leave the lab taking the participant’s word for it.

Our circuit sits on the recorder’s sample bus, just after the analog-to-digital converter (ADC). For each two-second window it produces a 32-byte *commitment*, also called a root. The owner keeps the readings and the fresh secret value used to make each root. Without the secret, the lab cannot use the root to check guesses about the waveform. Once the root is signed, the owner cannot feasibly supply a different sequence of readings that matches it.

![The proposed silicon is shaded. The waveform stays on the owner’s side; the lab needs neither the samples nor the secrets used to commit to them.](boundary.svg)

## What the laptop checks

The prototype proves one claim: **how many two-second windows had all 500 readings and no more than four clipped readings?** Here “clipped” means exactly the positive or negative limit of a signed 24-bit code. This rule, called QC01, measures digital capture quality, not electrode contact or a medical condition.

The recorder signs the roots in order. For each window, the owner makes a zero-knowledge proof that the private samples match the signed root and the running count was updated correctly. The lab’s laptop checks the signature and linked proofs against its own session challenge, expected window count and previously obtained public keys. It learns the total, not a list of failed windows (though zero or a perfect score tells it every outcome). Signing and proving both run in software. A different question would need a different proof circuit.

The chip commits to the **digital input**, not to its origin. It cannot tell whether a person wore the electrodes. A live recorder would need a trusted ADC and timer, a source of secret randomness, and a protected signing key. None is part of this block.

<div class="newpage"></div>

## Interfaces and operating targets

At each timer tick, the core takes a reading or records that the conversion was missing. A missing conversion has its own code; it is not a zero-valued reading. The core packs ten slots at a time, in order, and hashes all 50 groups with Poseidon. The session challenge, window index and secret opening are inputs to the same commitment.

| Interface | Inputs | Outputs |
|-----------|---------------------------|----------------------|
| Capture core | Clock, synchronous active-high reset, start; challenge[127:0], index[15:0], blind[254:0]; slot tick, sample present, raw[23:0]. | Busy, ready, root-valid, root[254:0] (32 bytes padded). No sample, pass flag or opening readback. |
| Test wrapper | Two dedicated digital inputs requested: `clk`, synchronous `strobe`. Twelve held controls: `rst`, `op[2:0]`, `din[7:0]`. | Eleven sense bits: `dout[7:0]`, `busy`, `ready`, `root_valid`. |
| Pads and supplies | 1.8 V core and ground; protected digital pads for the 3.3 V periphery. No analog line, reference current or low-resistance pad required. | Slot and package pins not yet assigned. |

The root is ready when `root_valid` goes high. A tick that arrives before the core is ready during an active window aborts that window. After the last tick the core must finish hashing before it can start again. A recorder that cannot drop samples between windows needs a private buffer. A stopped external timer produces no tick for the core to count.

| Operating characteristic | Minimum | Nominal | Maximum or limit |
|--------------------|----------:|----------:|-----------------:|
| Core supply target (V) | 1.62 | 1.80 | 1.98 |
| Operating temperature target (°C) | −40 | 25 | +110 |
| Sample rate within a window | — | 250 slots/s | Fixed |
| Window length at 250 slots/s | — | 500 slots (2 s) | Fixed |
| Core clock | 5.325 MHz service floor¹ | 12 MHz target | Silicon limit unknown |
| Present input (signed ADC code) | −8,388,608 | Signal dependent | +8,388,607 |
| QC01 count for N windows | 0 | Input dependent | N (demo: N ≤ 65,535) |
| Root size | — | 32 bytes | Fixed |
| Standalone footprint | — | 0.4938 mm² trial outline | 0.55 mm² budget |
| Average active core power at 12 MHz | — | Not measured | 20 mW target |

¹ At 250 slots/s a ten-slot group arrives every 40 ms. The hash engine needs 212,992 clocks per group. The floor applies within a window, not across finalization and restart.

### Absolute test limits

Never drive a core signal below ground or above its powered supply. Do not apply 3.3 V to a core net, exceed 1.98 V on the core rail, or test outside −40 to +110 °C. These are bench limits, not foundry stress ratings. Confirm package pin ratings, current limits and power sequencing before applying power.
