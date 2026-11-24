# Contest fit and filing checklist

**First ask about eligibility, not the PDF.** The [organizer describes Chipalooza](https://opencircuitdesign.com/chipalooza/) as a library of *analog* IP. [Rule 7](https://opencircuitdesign.com/chipalooza/rules-4.html) asks for a useful SoC block, but does not assure acceptance of a digital-only design. This IP works on the output bus of an ADC; it neither conditions nor converts an analog signal. The public challenge page [still lists November 23, 2026](https://opencircuitdesign.com/chipalooza/challenge-4.html) and gives no final Sky130 slot geometry. **Not filed; no extension or slot has been confirmed.**

Ask the organizer three concrete questions: Will they consider a late, entirely digital acquisition-side block? Can a **703 × 703 µm** standalone trial outline fit or must it be reshaped? Can two digital input pads carry clock and synchronous strobe while 12 held controls settle before each 1 ms command deadline? A positive answer to one does not settle the others.

## Written-proposal checklist

| Organizer requirement | Artifact / status |
|---|---|
| IP type and function | First two sections of the [anonymous proposal](chipalooza-4-private-eeg.pdf). This is a digital SoC IP, not an EEG board or a full prover on silicon. Organizers decide eligibility and slot fit. |
| I/O and special pad requirements | [Signal contract](../rtl/INTERFACE.md): **two dedicated digital inputs**, 12 held controls, 11 sense outputs. No analog lines or reference currents. Within the numerical limits of rule 7; mux, speed and slot pinout are not awarded. |
| Min/typ/max targets and absolute limits | Proposal spec table and electrical/test limits; observed RTL, placement estimates, and host proof results distinguished from unmeasured silicon. Final pad reliability limits depend on harness assignment. |
| Silicon measurement outline | [Bench and measurement protocol](measurement.md), included in the PDF. |
| Equipment list | Separate private attachment prepared. No confirmed physical instrumentation is claimed. Not in public Git. |
| Designer CVs | Required separately when filing; not included or approved. No designer or institution is named in the proposal PDF. |
| Reuse, reproduction, open source | [Source instructions](../REPRODUCE.md), [license](../LICENSE), locked dependencies, HDL, proof and verifier examples, test vectors, bench protocol. |

If late filing is permitted, send the anonymous PDF, separate equipment list and approved CVs to `chipalooza@opencircuitdesign.com` under the [filing instructions](https://opencircuitdesign.com/chipalooza/get-involved.html). Publication is not submission.

Rules 16, 18–20 and 23–25 matter after proposal review: adopt the Sky130 wrapper/template when available, provide separate reusable and slot layouts, DRC/LVS and extracted PVT results, then publish measurements. None is replaced by the current pre-route placement or a software proof. The pre-layout, post-layout and integration reviews are scheduled for the weeks of December 28, February 1 and February 22 respectively.

## What the earlier repositories show

These are **tapeout precedents**, not verified prize-payment records. The organizer identifies which projects went onto [the two Sky130 test chips](https://opencircuitdesign.com/chipalooza/challenge-1.html) and [the Challenge #2 IHP chip](https://opencircuitdesign.com/chipalooza/projects-2.html). Its [archived leaderboard](https://opencircuitdesign.com/chipalooza/leaderboard-2.html) explicitly distinguishes preliminary rankings from selection. Rule 26 ties the #4 award to tapeout and published measurements, not a proposal ranking.

| Public project | Useful precedent for this entry |
|---|---|
| [Sky130 low-power op-amp, Challenge #1](https://github.com/fossi-foundation/sky130_rodovalho_ip__lpopamp/blob/cf519f603c588b80861d4e39579c440b00462fe5/README.md) | The original proposal names test conditions next to its limits and explains why current is difficult to isolate. Here the 20 mW budget is **not** a measured macro result on a shared rail. Its named team is not a format to copy: #4 requires an anonymous main document. |
| [Bidirectional level shifter, Challenge #2 slot 1](https://github.com/rcyaon/bidir-level-shifter) | Its README explains in plain language how to measure speed despite the slow harness bus. Here the held control bus sets values; separate clock and strobe pins define the sampling edge. |
| [Biosignal instrumentation amplifier, Challenge #2 slot 9](https://github.com/orpheus016/sg13cmos5l_spma_ip__instramp) | Links the waveform, attributed input and benches, and separates core from slot evidence. Our public replay likewise connects input, RTL roots and verifier result; its status is simulation, not that project's tapeout status. |

The [Sky130 audio DAC](https://github.com/fossi-foundation/sky130_iic_ip__audiodac_lite) is also instructive: it separates reusable IP from harness dependencies, but includes a physical analog driver. It is **not** precedent that a commitment engine alone qualifies. Keep this repository standalone rather than adding unrelated analog circuitry to suggest otherwise.
