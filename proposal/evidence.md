# Demonstration evidence

## Did the laptop verify anything useful?

| Executed case | Observer result | What was actually exercised |
|----------------|----------|-------------------------------|
| Ten-minute **synthetic** study: 300 × 500 slots | **271 of 300 passed** | All 300 proofs were generated and verified. Four rail codes were allowed; 15 windows had five rails, another 14 had an explicit missing conversion. The expected session length and all ordered roots were bound by the recorder signature. |
| Four-second **recorded EEG replay**, with one injected missing conversion | **1 of 2 passed** | Public PhysioNet S001 R02 Oz excerpt, 160 Hz held on the 250 Hz test schedule. No fabricated ADC or participant measurement. Independently simulated HDL reproduced both signed-manifest roots bit for bit using the same inputs and fresh openings. |

For the 300-window run the public bundle was **77,607 bytes**, including a 192-byte Groth16 proof for each window. Proving took **189.11 s** wall time and verification **0.50 s** on an arm64 workstation, four Rayon workers. Prover peak process RSS was 385,990,656 bytes. The two-window bundle was 723 bytes. These are single host runs; throughput, memory, energy and privacy on a chip are not inferred. Keys were generated for development, not by a production ceremony. No private recording or signing key accompanies the public verifier examples.

**Negative checks.** Changed challenge, expected length, device identity, signature, policy, root, manifest order, truncation, initial opening, hidden link, proof order, omission, final opening, aggregate and trailing bytes were rejected. Signed roots alone do not prove acquisition provenance. Successful replay against the *same* expectations is intentional for archival checks; a live application must retire challenges after use.

## Did the hardware commit to the same data?

The Verilator bench matched an independent integer oracle on three 500-slot known answers: both digital input branches (direct and byte loader), either rail, and a missing slot with a nonzero ignored payload. Reset, overrun, malformed framing and noncanonical opening cases aborted without releasing a root. The separate Oz replay bridge fed the two actual manifest test windows into RTL; the software signer and prover are not instantiated in that RTL.

At 22,000 clocks per slot, the bench counted **212,993 clocks from the final tick to root-valid**. That is 38.73 ms at 5.5 MHz or 17.75 ms at 12 MHz; the latter is calculated from the cycle count. Do not assume gapless consecutive windows: the recorder needs trusted buffering across finalization and rearming. The 300-window host run tests complete-session verification, not continuous acquisition by a fabricated chip.

Data: [PhysioNet EEG Motor Movement/Imagery Dataset, version 1.0.0](https://doi.org/10.13026/C28G6P), used under ODC-By 1.0. The source excerpt, hash, attribution and transformation are in the public source package.

<div class="newpage"></div>

## Physical feasibility: what passed and what did not

The entire test wrapper and core mapped to **0.2303 mm²** of Sky130 HD typical-library cell area before physical buffering. That first netlist **failed** 12 MHz setup by 377.294 ns; high-fanout control nets were not viable as single drivers. Physical buffering and placement, followed by slow-cold resizing, produced **0.2654 mm²** of cells in a **0.4574 mm² trial core rectangle** (58% utilization). This is a legalized experimental placement, not a routed or allocated slot layout.

| Placed cell library | Setup slack at 12 MHz | Setup slack at 10 MHz | Hold slack, ideal clock |
|---|---:|---:|---:|
| Typical, 25 °C, 1.80 V | +46.669 ns | +63.336 ns | +0.465 ns |
| Slow, −40 °C, 1.60 V | **−2.751 ns** | +13.916 ns | +0.925 ns |
| Slow, 100 °C, 1.60 V | +7.613 ns | +24.280 ns | +0.921 ns |
| Fast, −40 °C, 1.95 V | +61.227 ns | +77.894 ns | +0.284 ns |
| Fast, 100 °C, 1.95 V | +61.449 ns | +78.116 ns | +0.296 ns |

**Decision:** 10 MHz has positive estimated setup and hold slack in all five checked libraries and is above the 5.325 MHz in-window service requirement for 250 slots/s. The **12 MHz nominal target is not closed across corners**. The 1.60 V slow libraries are guardband checks, not exact 1.62 V models. No 110 °C model was tested. Timing uses an ideal clock, 3 ns external I/O delays, 0.02 pF output load and placement-based nominal layer RC. It excludes clock-tree skew and extracted interconnect. Clock tree, routing, DRC/LVS, extracted STA, power, physical security and silicon measurements remain open.

**Integration gate:** confirm that the organizer can allocate the footprint and deliver the requested clock and control bandwidth. An uninterrupted real-time session also needs a protected inter-window buffer and an independently trusted acquisition/signing path. Neither signed desktop files nor an exposed fixture loader provides these guarantees.
