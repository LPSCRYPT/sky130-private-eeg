# Written-proposal requirements and filing status

[Official rules, especially rules 5–7, 10, 12–20 and 23–25](https://opencircuitdesign.com/chipalooza/rules-4.html) · [Official filing instructions](https://opencircuitdesign.com/chipalooza/get-involved.html).

| Organizer requirement | Artifact / status |
|---|---|
| IP type and function | First two sections of the [anonymous proposal](chipalooza-4-private-eeg.pdf). This is a digital SoC IP, not an EEG board or a full prover on silicon. Organizers decide eligibility and slot fit. |
| All I/O including test ports, special pad requirements | Proposal I/O table; [full byte protocol](../rtl/INTERFACE.md). 14 logical inputs / 11 outputs; no analog lines, external reference currents or dedicated pads requested. |
| Min/typ/max targets and absolute limits | Proposal spec table and electrical/test limits; observed RTL, placement estimates, and host proof results distinguished from unmeasured silicon. Final pad reliability limits depend on harness assignment. |
| Silicon measurement outline | [Bench and measurement protocol](measurement.md), included in the PDF. |
| Equipment list | Separate private attachment prepared. No confirmed physical instrumentation is claimed. Not in public Git. |
| Designer CV(s) | Separate private attachment required for filing; deferred at the owner's request. Do not publish identities in the main document. |
| Reuse, reproduction, open source | [Source instructions](../REPRODUCE.md), [license](../LICENSE), locked dependencies, HDL, proof and verifier examples, test vectors, bench protocol. |

**Not submitted.** Published due date: **November 23, 2026**. No extension, organizer approval, survey or email receipt is represented. Confirm whether a late proposal and the proposed clock path/footprint can be accepted before filing. If permitted, the owner sends the anonymous PDF, separate equipment list and owner-approved CVs to `chipalooza@opencircuitdesign.com`.

**Not due at proposal stage:** final standalone and slot-wrapper layouts, DRC/LVS, extracted/PVT and measured results. The official gates are pre-layout review the week of December 28, 2026; post-layout the week of February 1, 2027; integration/final review the week of February 22, 2027. All remain conditional; a public release is not tapeout approval.
