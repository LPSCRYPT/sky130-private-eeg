<div class="newpage"></div>

## Measuring the silicon

Use public fixtures and a pattern generator, not electrodes. Request `clk` and synchronous `strobe` as dedicated inputs from the same generator. The slot also needs 12 held controls and 11 sense bits (page 3). Before driving it, confirm pin assignment, mux, current limits, sequencing and protected 3.3 V pad to 1.8 V core translation. Never drive a core net at 3.3 V. The [prior IHP harness](https://opencircuitdesign.com/chipalooza/challenge-2.html) used SPI; the [Sky130 resource count](https://opencircuitdesign.com/chipalooza/rules-4.html) does not specify write speed or edge timing.

### Known answers at low speed

At 1 MHz, sample reset on a rising edge. Load 50 header bytes, least significant first within each field: two bytes of index, 16 of challenge, 32 of opening. Issue START. Send 500 slots, 22,000 clocks apart. For each slot, load three sample bytes then issue PRESENT, with commands spaced 5,500 clocks apart. For slot 7 of the missing-slot vector, stage `0xdeadbe` then issue MISSING instead. Keep strobe low while the core finishes.

Wait for `(busy, ready, root_valid) = (0,0,1)`. Address bytes 0–31, observing each registered response before the next read. Reassemble the bytes in little-endian order. Compare all 32 bytes for each of the three vectors on page 4, in order. The public integer oracle is `tools/reference_roots.py`; its frozen answers are in `tests/reference-roots.txt`.

### Sampling rate, finalization and recovery

With a continuous clock, use 22,000 clocks/tick at 5.5 MHz, 40,000 at 10 MHz and 48,000 at the nominal 12 MHz. At each passing bin require 500 ticks, all 499 intervals exactly 4 ms within clock calibration, and the expected root. Log supply, temperature and repetitions; repeat at extremes only if authorized.

An all-present window takes 2,083 strobes: 51 for header/start, 2,000 for acquisition and 32 for read addresses. Pulse strobe across one rising edge per command. Synchronize the harness writer to the generator: each 4 ms slot requires four settled presentations, one per ms. Record write completions relative to the pulses, including mux settling and pad-to-core skew. Do not stretch an interval for software. A missed write deadline or unresolved setup/hold makes that rate test inconclusive. With verified stimulus, a wrong root, missing valid or rejected tick is a failure. Slow success does not establish 250 Hz operation.

At 22,000 clocks/tick, stop the clock low 212,992 rising edges after tick 499: valid must still be low. One more rising edge must publish the root. Use counted edges, not software polling. Record the gap through readout and rearming; finalization alone takes 38.73 ms at 5.5 MHz. Mid-window reset, PRESENT after a partial sample, or a tick while busy but not ready must leave no valid root. Require a fresh known answer after reset.

### Active power

At 12 MHz, measure average active rail power from START to root publication with a 250 Hz public fixture. Report rail voltage, current, integration interval and uncertainty. Measure idle at the same clock, rails, temperature and other-slot state. Active minus idle is not total active power. Compare with the ≤20 mW average active target only on an isolated macro supply, including uncertainty. A shared rail leaves the target unresolved.
