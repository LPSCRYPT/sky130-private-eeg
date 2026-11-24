<div class="newpage"></div>

## Replaying an EEG recording

We took four seconds from channel Oz in the [PhysioNet EEG Motor Movement/Imagery Dataset](https://doi.org/10.13026/C28G6P) (S001 R02, 10–14 s). The original recording runs at 160 Hz. To drive the 250 Hz test interface, we held each reading until the next arrived. We then withheld one conversion, slot 610, in the second window.

![Input used for the replay. The marked gap was added for this test; it is not in the original recording.](replay.svg)

The laptop reported **1 of 2 windows passed**. It used the proof bundle, not the waveform shown here. We checked the hardware separately: the simulated chip produced the same two roots, byte for byte, as the software that signed the recording.

### Three checks on the sample bus

We also sent three known sequences through the chip’s byte-wide test port. An independent integer implementation supplied the expected roots. A window can fail QC01 and still produce the right root: the chip must commit to what arrived, including bad readings.

| Window supplied to the core | Quality decision in software | Hardware result |
|---|---|---|
| Index 0, four readings at the negative rail | Pass | All 32 bytes matched |
| Index 1, five readings at the positive rail | Fail: too many rail readings | All 32 bytes matched |
| Index 0 as above, but slot 7 is missing | Fail: incomplete window | All 32 bytes matched; different root from the first window |

For the missing slot we left nonzero data on the bus. The root still matched: the missing flag, not the unused data, determined what the chip recorded. Reset or overrun during capture, a malformed command, or an out-of-range opening left no valid root.

### Ten minutes of synthetic input

We generated 300 windows. Fifteen contained five clipped readings each; another 14 were missing one conversion each. The verifier returned **271 of 300**. The bundle occupied 77,607 bytes, including 300 proofs of 192 bytes each. On an arm64 workstation with four worker threads, producing it took 189.11 s and 368 MiB of peak memory. Checking it took 0.50 s.

Changing the expected challenge or device key caused verification to fail, as did altering a root or total, or removing or swapping proofs. An unchanged bundle still verifies against its original challenge. A live observer must issue a fresh challenge and retire it after use.

<div class="newpage"></div>

## Placement and timing

The placed block measures about **703 × 703 µm**. Its outer rectangle is 0.4938 mm², below the proposed 0.55 mm² budget; there is no assigned slot yet. The standard cells occupy 0.2654 mm² within 0.4574 mm² of placement rows. The shuttle slot must fit the outer rectangle, not just the cells.

![Setup margin after placement. The square to the left of zero marks the missed 12 MHz target at −40 °C.](timing.svg)

The placed design **met 10 MHz in all five libraries**. The smallest setup margin was 13.916 ns. At the **12 MHz target**, the slow, −40 °C library missed setup by 2.751 ns; the other four passed. Hold margins ranged from 0.284 to 0.925 ns. The 1.60 V cases test slightly below the 1.62 V supply target. We have no result at +110 °C.

These are estimates after placement, not measurements from a chip. They include buffers on signals driving many cells, gate resizing, estimated wire resistance and capacitance, 3 ns of external I/O delay and 0.02 pF output loads. They assume an ideal clock. Clock-tree design, routing, extracted timing, physical rule checks (DRC), layout-to-schematic comparison (LVS) and silicon power measurements remain open.
