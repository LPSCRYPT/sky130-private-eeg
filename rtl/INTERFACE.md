# Capture and test interfaces

[`eeg_capture`](eeg_capture.sv) sits on the recorder side, after digitization. For each 500-slot window it takes the samples, their presence bits and a fresh secret random field element (`blind`) supplied by the recorder. Its only sample-dependent output is the root: a commitment that binds the recorder to those slots without revealing them. The owner needs the slots and blind for the [software prover](../proof/PROTOCOL.md); the core does not export a witness. The observer verifies the resulting proof on a laptop, not through these pins.

## Driving the recorder core

All inputs are sampled on a rising `clk` edge. Assert synchronous `rst` for at least one edge. With reset low and `busy=0`, drive `start` for one edge with the 16-bit `window_index`, public 128-bit session challenge (`nonce`) and a canonical BLS12-381 scalar `blind < p`, where `p` is the scalar field modulus. `start` is an enable: holding it high into the next busy edge aborts the window. `start` and `slot_tick` together are rejected even when idle. The signed-manifest verifier, not the core, checks that window indices are consecutive.

With `rst=start=0`, `ready=1` means the core can accept a slot on the next edge. Drive `slot_tick` for every scheduled slot, including missing ones. For a present slot, drive `sample_valid=1` and the signed 24-bit code on `sample_raw`; for a missing slot, drive `sample_valid=0` and the core ignores `sample_raw`. A one-word pending buffer lets input and hashing overlap. A tick alone is ignored when idle but aborts a busy window if `ready=0`, including during finalization.

At publication the core clears capture scratch and holds `root` with `root_valid=1` until the next start or reset. Reset or rejection takes priority even on the publication edge: `busy`, `ready`, `root_valid` and `root` all clear. Clearing registers defines their logical state; it is not a physical leakage countermeasure. Make the two Poseidon ROM files `params/{ark,mds}.hex` available relative to the tool run directory for `$readmemh`.

One permutation dispatch interval is 212,992 core clocks. At 250 slots/s, a ten-slot word arrives every 40 ms, requiring at least 5.3248 MHz on average within an armed window, before margin. The simulation uses 22,000 clocks/slot (5.5 MHz at 250 Hz); the nominal silicon target is 12 MHz. The core cannot start a new window while it drains the last word. Gapless recording requires a private buffer and scheduler outside the core to preserve incoming slots, their order and timing through this handoff. A count of roots does not establish elapsed time.

## Public-fixture wrapper

[`eeg_challenge`](eeg_challenge.sv) lets a bench operator load known samples and read back the root one byte at a time. Anyone monitoring `op`, `din` and the strobes can recover the raw samples, missing-slot positions and secret blind. Use public fixtures on this port. A private recorder would instead connect its protected sample bus directly to `eeg_capture`.

The wrapper samples a command on every rising `clk` edge with `strobe=1`. Holding `strobe` high repeats the command; intentional back-to-back commands are legal. Synchronous `rst` takes priority regardless of `strobe`. All byte sequences are little endian.

| `op` | `din` / command | Behavior |
|---:|---|---|
| 0 | One header byte | While idle, load exactly 50 bytes: 2 for the window index, 16 for the challenge, 32 for the blind. The unused high bit must be zero and the blind less than `p`. |
| 1 | Start | Requires a complete header and idle core. Start the window and clear the header staging register. |
| 2 | One sample byte | Requires `ready=1` on each byte edge. Load exactly three bytes of raw signed-24 two's complement before a present tick. |
| 3 | Present tick | Accept the assembled sample and clear staging. |
| 4 | Missing tick | Accept a canonical missing slot. Either no staged bytes or three ignored bytes; partial staging is invalid. |
| 5 | Byte address 0…31 | Valid completed root only; least significant byte first, unused top bit zero. |
| 6, 7 | Reserved | Malformed command. |

Malformed wrapper commands synchronously clear the wrapper and core. The core also rejects a start with a complete header but a blind ≥ `p`. After either error no root is valid; reset and reload the full fixture. Read the registered `dout` after the selected READ_ROOT edge and before issuing the next read; it holds the selected byte between reads.

## Requested shuttle connections (not assigned)

| Path | Direction at the slot | Signals |
|---|---|---|
| Two dedicated digital pads | Inputs | `clk`, synchronous `strobe`, both driven by one external pattern generator |
| 12 held control bits | Inputs | `rst`, `op[2:0]`, `din[7:0]` |
| 11 sense bits | Outputs | `dout[7:0]`, `busy`, `ready`, `root_valid` |

[Challenge #4 rules 7, 10, 20–21](https://opencircuitdesign.com/chipalooza/rules-4.html) allow up to 24 controls, 12 test outputs and three dedicated pads. They do not specify a clock rate or assign pins. The [Challenge #2 harness](https://opencircuitdesign.com/chipalooza/challenge-2.html) used SPI control/readback; its framing, speed and pinout are not a Sky130 specification. This request uses no analog bus, reference or third pad. Before applying signals, confirm the slot mux, protected 3.3 V-periphery/1.8 V-core digital pad path, clock/strobe skew, sequencing and legal levels. Never drive a core net with 3.3 V.

With `strobe=0`, set the selected slot’s held controls and let all writes finish and signals settle. Pulse `strobe` across exactly one rising edge, for example by asserting and releasing it on the surrounding falling edges, subject to integrated pad-to-core setup and hold. Hold `op` and `din` stable through hold time. Change `rst` with the clock stopped low; let it settle before resuming. For slow readback, end a counted clock burst low and read stable status. A software poll cannot locate the publication edge.

## Bench timing

An all-present window takes 2,083 strobed commands: 50 CONFIG_BYTE, 1 START, 500 × (3 SAMPLE_BYTE + 1 PRESENT), and 32 READ_ROOT. Readback requires 32 additional `dout` observations. A MISSING with no staged bytes saves three commands (2,080 for one missing slot); a MISSING with three ignored bytes costs the same as PRESENT. Header and reads are outside acquisition. These counts exclude bus framing, register writes, read latency and settling.

A slow known-answer run can use 1 MHz and 22,000 clocks/slot (22 ms), with three byte commands and a tick spaced 5,500 clocks apart. At 250 Hz the same four phases are 1 ms apart: 22,000 clocks/slot at 5.5 MHz, 40,000 at 10 MHz or 48,000 at 12 MHz. For 500 present slots, acquisition takes 2,000 one-edge strobes. The control path need not run at the core clock rate, but it must settle each command by its 1 ms deadline (1,000 presentations/s), including host scheduling jitter and status traffic. Stretching ticks to wait for software or `ready` would change the experiment.

At 22,000 clocks/slot the [capture bench](../tests/tb_capture.sv) checks 212,993 rising edges from accepted tick 499 to publication. With the engine free for the final packed word, this is 38.73 ms at 5.5 MHz, 21.30 ms at 10 MHz or 17.75 ms at 12 MHz. At 250 Hz, respectively 9, 5 or 4 additional ticks would come due before publication alone. Readout and rearming take additional time; report the observed inter-window gap separately.
