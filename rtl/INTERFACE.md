# Reuse and control protocol

`eeg_capture` is the reusable block. Instantiate it on a private synchronous digital bus, drive `rst` high on at least one rising `clk` edge, and send one `start` edge with `window_index`, `nonce`, and a canonical field `blind < p`. Start and tick cannot coincide. Window index is 16 bits; signatures bind consecutive indices to the verifier's independently expected session. Capture new slots on `slot_tick`, not on `sample_valid`. `ready` indicates the coming rising edge can accept one slot. `sample_valid=0` is a real scheduled missing slot; its data bus bits are ignored. The source owns cadence and classifications, not the laptop. One pending packed word allows hashing and ingestion to overlap. If a tick is unserviceable while busy, the hardware aborts rather than silently ignoring it. A conflicting start also aborts. On completion `root_valid` and `root` are held until next start/reset. Capture scratch clears at publication; this is functional clearing, not physical leakage mitigation.

**Service budget.** One permutation dispatch interval is 212,992 core clocks. Ten slots arrive every 40 ms; at least 5.3248 MHz is needed to sustain that average within an armed window, exclusive of margin. The digital simulation schedule is 22,000 clocks/slot (250 Hz at 5.5 MHz); the proposed nominal operating target is 12 MHz. A root has a drain latency after slot 499. A new window cannot start while the old root is being finalized. A recorder needing gapless consecutive windows must buffer incoming slots privately across this handoff, preserve original slot order/timestamps and prove no dropped deadlines. That FIFO and scheduler are **not** included. Do not silently interpret a root count as proof of elapsed time.

`eeg_challenge` is the separate byte-wide *public-fixture test* wrapper. All commands apply on a rising edge with `strobe=1`. Commands may be back-to-back. `dout` is registered. All byte sequences are little endian.

| `op` | `din` / command | Behavior |
|---:|---|---|
| 0 | One header byte | Exactly 50: 2 bytes index, 16 challenge, 32 private field opening. High unused bit zero; integer less than field modulus. |
| 1 | Start | Requires complete header and idle. Load and clear the staging register. |
| 2 | One sample byte | Load exactly three bytes of raw signed-24 two's complement before a present tick. |
| 3 | Present tick | Accept the assembled sample and clear staging. |
| 4 | Missing tick | Accept a canonical missing slot. Either no staged bytes or three ignored bytes; partial staging is invalid. |
| 5 | Byte address 0…31 | Valid completed root only; least significant byte first, unused top bit zero. |
| 6, 7 | Reserved | Malformed command. |

Malformed transactions synchronously clear the wrapper and core. There is no error telemetry carrying secret-dependent data. In addition to source HDL, include `params/{ark,mds}.hex` in the tool's run directory hierarchy relative to the project root for `$readmemh`. `eeg_challenge` consumes 14 input bits and 11 output bits; no physical pad assignments are implied. Production designs use `eeg_capture` directly and **do not expose** the fixture loader on a host-visible debug bus.
