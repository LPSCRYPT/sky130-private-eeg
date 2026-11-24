<div class="newpage"></div>

## Silicon test plan

Use a pattern generator in place of electrodes. The test port exposes both the readings and the secret opening, so use public input sequences only. Before power-up, confirm the harness pinout, mux, current limits, supply sequence and voltage translation. Drive the dedicated clock and strobe from the same generator. The harness holds the 12 control bits and reads 11 output bits.

### Compare all 32 output bytes

Start at 1 MHz. Reset on a rising edge. Load the 50-byte header least significant byte first within each field: index (2 bytes), challenge (16), opening (32). Issue START. For each present slot, send three sample bytes followed by PRESENT. Leave 5,500 clocks between commands and 22,000 clocks between slots. For slot 7 of the missing-slot test, load `0xdeadbe` but issue MISSING instead of PRESENT.

After the 500th slot, hold strobe low until `busy=0`, `ready=0` and `root_valid=1`. Read addresses 0 through 31, sampling each registered byte before the next read. Compare all 32 bytes against `tests/reference-roots.txt` for each of the three sequences. The independent calculation is in `tools/reference_roots.py`.

### Run at the EEG sample rate

Run a continuous clock. Space ticks 22,000 clocks apart at 5.5 MHz, 40,000 at 10 MHz and 48,000 at 12 MHz. An all-present window takes 2,083 strobes: 51 to configure and start, 2,000 to send samples and 32 to read the result. Each command must be stable across exactly one strobed rising edge. The four commands per sample give the harness **1 ms per write**, including settling.

Record write times relative to strobe, clock calibration, supply, temperature and number of runs. A run passes only with the expected root and 500 accepted ticks separated by 499 intervals of 4 ms within clock calibration. If the harness misses a write deadline or the inputs are not demonstrably stable at the edge, the result is inconclusive. If the stimulus is correct and the chip rejects a tick, returns a wrong root or never asserts valid, it fails. Repeat at supply and temperature extremes only if authorized.

### Count the clocks after the last sample

At 22,000 clocks per tick, stop the clock low 212,992 rising edges after the last accepted tick. `root_valid` must still be low. Advance one edge: it must go high. That is 38.73 ms at 5.5 MHz before readout or restart. Count edges rather than polling from software; report the full gap through rearming separately. Try a mid-window reset, PRESENT after a partial sample, and a tick while busy but not ready. Each must leave no valid root. After reset, rerun a known sequence and check its root.

### Measure active power

At 12 MHz, drive a 250 Hz test sequence. Measure average active rail power from START until `root_valid`; report rail voltage, current, interval and measurement uncertainty. Measure idle power at the same clock, voltage and temperature with other slots in the same state. Only an isolated core supply can test the 20 mW average active target directly. On a shared rail, report both readings: their difference is the change in board load, not the core’s total active power.
