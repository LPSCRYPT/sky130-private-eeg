# Reuse and control protocol

`eeg_capture` is the reusable block. Instantiate it on a private synchronous digital bus, drive `rst` high on at least one rising `clk` edge, and send one `start` edge with `window_index`, `nonce`, and a canonical field `blind < p`. Start and tick cannot coincide. Window index is 16 bits; signatures bind consecutive indices to the verifier's independently expected session. Capture new slots on `slot_tick`, not on `sample_valid`. `ready` indicates the coming rising edge can accept one slot. `sample_valid=0` is a real scheduled missing slot; its data bus bits are ignored. The source owns cadence and classifications, not the laptop. One pending packed word allows hashing and ingestion to overlap. If a tick is unserviceable while busy, the hardware aborts rather than silently ignoring it. A conflicting start also aborts. On completion `root_valid` and `root` are held until next start/reset. Capture scratch clears at publication; this is functional clearing, not physical leakage mitigation.

**Service budget.** One permutation dispatch interval is 212,992 core clocks. Ten slots arrive every 40 ms; at least 5.3248 MHz is needed to sustain that average within an armed window, exclusive of margin. The digital simulation schedule is 22,000 clocks/slot (250 Hz at 5.5 MHz); the proposed nominal operating target is 12 MHz. A root has a drain latency after slot 499. A new window cannot start while the old root is being finalized. A recorder needing gapless consecutive windows must buffer incoming slots privately across this handoff, preserve original slot order/timestamps and prove no dropped deadlines. That FIFO and scheduler are **not** included. Do not silently interpret a root count as proof of elapsed time.

## Public-fixture wrapper

`eeg_challenge` samples a command on **every rising `clk` edge with `strobe=1`**. This is an enable, not an edge detector: holding it high repeats the command. Back-to-back commands are legal if intentional. `rst` is synchronous and takes priority regardless of `strobe`. All byte sequences are little endian.

| `op` | `din` / command | Behavior |
|---:|---|---|
| 0 | One header byte | Exactly 50: 2 bytes index, 16 challenge, 32 private field opening. High unused bit zero; integer less than field modulus. |
| 1 | Start | Requires complete header and idle. Load and clear the staging register. |
| 2 | One sample byte | Load exactly three bytes of raw signed-24 two's complement before a present tick. |
| 3 | Present tick | Accept the assembled sample and clear staging. |
| 4 | Missing tick | Accept a canonical missing slot. Either no staged bytes or three ignored bytes; partial staging is invalid. |
| 5 | Byte address 0…31 | Valid completed root only; least significant byte first, unused top bit zero. |
| 6, 7 | Reserved | Malformed command. |

Malformed wrapper commands synchronously clear the wrapper and core. A start with a complete header but a field opening ≥ `p` is also rejected by the core. No root is valid after either error; reset and reload the full fixture. Registered `dout` holds a read byte between commands, so read it **after** the selected READ_ROOT edge, before issuing the next read. Include `params/{ark,mds}.hex` relative to the tool run directory for `$readmemh`. A private recorder uses `eeg_capture` directly; this loader exposes the stimulus and opening.

## Requested shuttle connections (not assigned)

| Path | Direction at the slot | Signals |
|---|---|---|
| Two dedicated digital pads | Inputs | `clk`, synchronous `strobe`, both driven by one external pattern generator |
| 12 held control bits | Inputs | `rst`, `op[2:0]`, `din[7:0]` |
| 11 sense bits | Outputs | `dout[7:0]`, `busy`, `ready`, `root_valid` |

[Challenge #4 rules 7, 10, 20–21](https://opencircuitdesign.com/chipalooza/rules-4.html) list up to 24 controls, 12 test outputs and three dedicated pads, not a clock rate or a pin assignment. The [Challenge #2 harness](https://opencircuitdesign.com/chipalooza/challenge-2.html) used SPI control/readback; its framing, speed and pinout are not a Sky130 specification. No analog bus, reference or third pad is requested. Confirm the slot mux, protected 3.3 V-periphery/1.8 V-core digital pad path, clock/strobe skew, sequencing and legal levels before drive. Never drive a core net with 3.3 V.

With `strobe=0`, set the selected slot's held controls, allow all writes to complete and signals to settle, then pulse `strobe` across exactly one rising edge. For example, assert and release on the surrounding falling edges, subject to integrated pad-to-core setup/hold. Do not change `op` or `din` until after hold. Change `rst` with the clock stopped low and allow it to settle before resuming. For slow sense readback, finish a counted clock burst low and read stable status; never infer the publication edge from the first software poll.

**Transaction budget.** An all-present window needs 50 CONFIG_BYTE + 1 START + 500 × (3 SAMPLE_BYTE + 1 PRESENT) + 32 READ_ROOT = **2,083 strobed commands**, plus 32 `dout` observations. A MISSING with no staged bytes saves three commands (2,080 total for one missing slot); MISSING with three ignored bytes costs the same as PRESENT. Header and reads are outside acquisition. The logical counts exclude bus framing, multiple register writes, read latency and settling.

**Bench schedule.** A slow known-answer run can use 1 MHz, 22,000 clocks per slot (22 ms), with three byte commands and a tick spaced 5,500 clocks apart. For 250 Hz, use the same four phases 1 ms apart: clock/slot = 22,000 at 5.5 MHz, 40,000 at 10 MHz or 48,000 at 12 MHz. Across 500 present slots the generator sends 2,000 one-edge strobes; the control path must deliver the right settled command **by each 1 ms deadline** (1,000 command presentations/s), not run at the core MHz rate. Qualify worst-case bus latency including any host scheduling jitter and status traffic. Do not stretch ticks to wait for software or `ready`.

At 22,000 clocks/slot `tests/tb_capture.sv` checks 212,993 rising edges from accepted tick 499 to publication. With the engine free for the final packed word, this is 38.73 ms at 5.5 MHz, 21.30 ms at 10 MHz or 17.75 ms at 12 MHz. At 250 Hz, respectively 9, 5 or 4 additional scheduled ticks would fall before publication alone. Readout and rearming take extra time; report the observed inter-window gap. A passing single-window test is not a gapless recorder.
