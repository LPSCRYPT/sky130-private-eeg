# Chipalooza Challenge #4 filing notes

As of November 24, 2026, this proposal has not been filed. The [published deadline](https://opencircuitdesign.com/chipalooza/challenge-4.html) was November 23; no extension or slot is confirmed. The [challenge](https://opencircuitdesign.com/chipalooza/) focuses on analog IP. This module is a digital SoC block that commits to samples after an ADC; it does not condition or convert the analog signal. [Rule 7](https://opencircuitdesign.com/chipalooza/rules-4.html) calls for a useful SoC block but does not settle eligibility for a digital-only entry.

Before filing, ask the organizer whether a late proposal for this block can be considered. For physical fit, request the Sky130 slot outline and pin assignment: the standalone trial outline is 703 × 703 µm. Testing at 250 slots/s needs two dedicated digital input pads (clock and synchronous strobe) and a control path that can settle the next command within 1 ms.

## What to send if late filing is permitted

Under the [filing instructions](https://opencircuitdesign.com/chipalooza/get-involved.html), send three items to `chipalooza@opencircuitdesign.com`:

1. The [main proposal: *Private EEG verification*](chipalooza-4-private-eeg.pdf), without personal or institutional details. For Rule 6 it covers the IP type and function; [I/O, test ports and special pad requirements](../rtl/INTERFACE.md); target characteristics (minimum, nominal/average and maximum where appropriate) and absolute test limits; and a [silicon measurement plan](measurement.md). The test wrapper requests 12 held control inputs and 11 sense outputs in addition to the two pads; it uses no analog lines or reference currents. Final pad limits depend on the assigned harness.
2. A separate, accurate list of equipment available for testing. A private equipment attachment has been prepared; physical instrumentation is not confirmed.
3. The designers’ CVs, separately from the anonymous proposal. Approved CVs are not included here.

The [interest survey](https://forms.gle/bsKn8W44M9gQoc2R6) is separate from the proposal email. The public repository contains the [reproduction instructions](../REPRODUCE.md), [license](../LICENSE) and [November 24 engineering checks](AUDIT.md); publishing these is not submission.

### Written proposal check, November 24

The six-page PDF covers all five items the organizer requests in the **main document**. This is a document check, not an eligibility decision.

| Rule 6 item | Where to find it |
|---|---|
| IP type | Page 1: reusable Sky130 digital module on a recorder’s ADC output, distinct from its host proof software. |
| I/O and test ports | Page 3: core signals, wrapper controls, readback, pad voltage translation and two dedicated input pads. No low-resistance analog path is requested. |
| Function | Pages 1–2: how samples and missing conversions become commitments, what statement the software proves, and what a laptop learns. |
| Specifications and limits | Page 3: min/nominal/max where applicable, average active power target and absolute test limits. These are design targets and safe bench limits, not foundry stress ratings. |
| Measurement plan | Page 6: input stimulus, 32-byte reference comparisons, edge-counted timing, recovery and power measurement. The plan distinguishes a failure from a bus too slow to perform the test. |

The requested 12 controls, 11 test outputs and two dedicated inputs are inside Rule 7’s counts of 24, 12 and three respectively. That does not guarantee 1 ms bus service or physical fit. The [Challenge #4 page](https://opencircuitdesign.com/chipalooza/challenge-4.html) says harness dimensions and pin configuration will be posted when available. Rule 6 does not ask for a chip render or routed layout at proposal review.

## After proposal review

The rules schedule pre-layout review for the week of December 28, 2026, post-layout review for the week of February 1, 2027, and final integration review for the week of February 22, 2027. Rules 16, 18–20 and 23–25 call for the Sky130 template when available, a reusable standalone layout and a separate slot layout, DRC/LVS results and post-layout PVT verification. The current pre-route placement does not meet those later milestones. Under Rule 26 the award is tied to tapeout and published silicon measurements, not proposal ranking.

## Earlier tapeouts

The organizer lists projects on the [Challenge #1 Sky130 test chips](https://opencircuitdesign.com/chipalooza/challenge-1.html) and [Challenge #2 IHP chip](https://opencircuitdesign.com/chipalooza/projects-2.html). The [archived leaderboard](https://opencircuitdesign.com/chipalooza/leaderboard-2.html) distinguishes preliminary rankings from selection. These are references for design and test, not evidence of prize payments or of eligibility for this digital block.

| Project | Relevant detail |
|---|---|
| [Sky130 low-power op-amp: original 2024 proposal](https://github.com/fossi-foundation/sky130_rodovalho_ip__lpopamp/blob/cf519f603c588b80861d4e39579c440b00462fe5/README.md) | Specifies min/typ/max with test conditions, a pinout, measurement plan and limits of shared-supply current measurements. Those are useful comparisons; its named-designer format is not the current anonymity rule. |
| [Ring-oscillator PLL: July 2026 proposal](https://github.com/vyges/sg13cmos5l_vyges_ip__pll_rosc/blob/3f5915afe3123e5ab580fb4a8fe4839ae968bf3a/doc/proposal.md) | Separates dedicated timing pins from muxable signals and keeps equipment and CVs outside the main document. It proposes an analog/mixed-signal block, not a precedent for digital eligibility. |
| [Bidirectional level shifter, Challenge #2 slot 1](https://github.com/rcyaon/bidir-level-shifter) | Describes speed measurement with a slow harness control bus. |
| [Biosignal instrumentation amplifier, Challenge #2 slot 9](https://github.com/orpheus016/sg13cmos5l_spma_ip__instramp) | Links an attributed input waveform and benches, and distinguishes core from slot evidence. |
| [Sky130 audio DAC](https://github.com/fossi-foundation/sky130_iic_ip__audiodac_lite) | Separates reusable IP from the harness and includes a physical analog driver. |
| [Slot 14 LVDS transmitter](https://github.com/Intubun/chipalooza_lvds_pll/blob/5b8222a0ff7c549aa832e697d6eb46af14df723e/submission.yaml) | The published slot dimensions, physical pin map and final GDS are integration deliverables for an assigned IHP slot. They are not requirements for a new Sky130 written proposal. |
