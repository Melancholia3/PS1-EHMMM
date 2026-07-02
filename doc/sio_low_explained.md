# How `send_string` and `send_hex32` Actually Work

This document explains the mechanics behind the low-level serial output
routines used in `sio_low.s`, and why they are safe to call from inside an
exception handler where BIOS and PSn00bSDK functions are not.

## 1. The hardware involved

The PS1's serial port (SIO0/SIO1 depending on revision, but the one used for
debug output is mapped the same way) exposes two memory-mapped registers that
matter here:

| Register   | Address      | Purpose                                   |
|------------|--------------|--------------------------------------------|
| `SIO_DATA` | `0x1F801040` | Write a byte here to transmit it           |
| `SIO_STAT` | `0x1F801044` | Status flags; bit 0 is `TXRDY`             |

`TXRDY` (Transmit Ready) is set by the hardware whenever the transmit shift
register is free to accept a new byte. Writing to `SIO_DATA` while `TXRDY` is
0 either gets ignored or corrupts the byte being sent, depending on timing —
so every routine here checks it before writing.

No interrupt is involved. No FIFO, no IRQ handler, no buffer in RAM. The CPU
talks directly to the UART-like hardware block and waits for it.

## 2. Why this is different from `SIO_WriteByte` / `printf`

PSn00bSDK's `libsio` and the BIOS TTY driver both build a layer on top of this
same hardware: ring buffers in RAM, an IRQ callback that drains them, and
(for `printf`) a formatting step that itself uses BIOS-internal scratch space
and possibly its own stack frame.

All of that is fine in normal program flow. It becomes a liability inside an
exception handler because:

- The exception can fire in the middle of any of those operations. If it
  interrupts the BIOS while it's mid-formatting a string, calling `printf`
  again from the handler reuses the same internal state.
- IRQs may be masked or in an inconsistent state at the moment of the
  exception, so anything that depends on the RX/TX IRQ to drain its buffer
  may stall or behave unpredictably.
- These functions assume a "normal" stack with enough headroom below `$sp`.
  An exception handler's stack frame is deliberately small and may already be
  close to the bottom of whatever stack it's using, so a nested call growing
  the stack further can write over memory the handler itself is using —
  exactly what happened with the saved `$ra` in the earlier version of this
  handler.

`send_string` and `send_hex32` sidestep all three problems by not depending
on anything outside the four registers they touch.

## 3. `send_string` — character by character

```
Input:  $a0 = pointer to a null-terminated string
Output: none
Clobbers: $t0, $t1, $a0
```

The logic, step by step:

1. Load the byte at `$a0` into `$t1`.
2. If that byte is `0x00`, the string is finished — return.
3. Otherwise, we just wait for poll `SIO_STAT` and masking bit 0 (`TXRDY`).
   A standard busy-wait: the CPU stalls, spinning on the address until the
   hardware flips the bit.
4. Once ready, write the byte to `SIO_DATA`. The hardware takes it from
   there and shifts it out over the wire at the configured baud rate.
5. Increment `$a0` to point at the next character.
6. Jump back to step 1.

There is no `jal` anywhere in this function except the final return. The loop
is built entirely from `j` (unconditional jump) and conditional branches, so
the function never pushes a return address onto any internal call chain. That
means it never needs to allocate a stack frame and never risks colliding with
whatever the caller put on the stack.

## 4. `send_hex32` — converting a 32-bit value to readable hex

```
Input:  $a1 = 32-bit value to print
Output: none
Clobbers: $t0, $t1, $t2, $t3, $a1
```

A 32-bit value has eight hexadecimal digits (called nibbles), with the first
being the most significant. `send_hex32` processes exactly those eight in a
fixed loop:

1. Extract the top 4 bits of the current value: `(value >> 28) & 0xF`.
   This is done with `srl` followed by `andi`.
2. Decide whether that nibble (0–15) maps to a digit or a letter:
   - If it's less than 10, it's `'0'`–`'9'`, so add `0x30` (ASCII `'0'`).
   - Otherwise it's `'A'`–`'F'`, so add `0x37` (so that 10 → `0x41` = `'A'`).
3. Send that single ASCII character using the same poll-and-write sequence
   as `send_string` — but inlined directly in this function instead of
   calling out to it.
4. Shift the original value left by 4 bits, so the next-most-significant
   nibble becomes the new top nibble.
5. Decrement the iteration counter; repeat until all 8 nibbles are sent.

### Why the send step is inlined instead of calling `send_string`

It would be possible to build a one-character string on the fly and call
`send_string` with it via `jal`. That was deliberately avoided. Every `jal`
pushes the return address into `$ra`, and if `send_hex32` itself called
something with `jal`, the caller's `$ra` (already sitting in `$ra` when
`send_hex32` was entered) would be overwritten before `send_hex32` gets a
chance to return. Since `send_hex32` doesn't save `$ra` anywhere — it doesn't
need to, because it makes no further calls — keeping the write inline avoids
introducing that one case where it would.

## 5. Why neither function touches `$s0`–`$s7` or the stack

Both routines restrict themselves to the temporary register set
(`$t0`–`$t3`) plus their argument registers (`$a0`, `$a1`). This matters for
two reasons:

- The calling code (`retrive` in `handler.s`) keeps its own state — the TCB
  pointer, the offset table pointer, the loop counter — in `$s0`–`$s3` across
  the call. Saved registers are expected to survive a function call under the
  standard MIPS calling convention; by never touching them, these routines
  are trivially correct on that front regardless of how strictly the BIOS
  honors that convention itself.
- Since there is no stack frame, there is nothing to allocate or free, and
  therefore nothing that can be sized incorrectly or clash with a caller's
  frame sitting just above or below it.

## 6. The full call sequence from `retrive`

When `retrive` wants to print, for example, `"Return Addres = "` followed by
a hex value:

1. `retrive` already has the saved value in `$a1` (it was loaded from the
   TCB earlier in the function).
2. It loads the string pointer into `$a0` and does `jal send_string`. Control
   transfers, the string streams out byte by byte, control returns.
3. `$a1` still holds the numeric value untouched (since `send_string` never
   touched it). `retrive` does `jal send_hex32`.
4. Eight hex digits stream out, control returns.
5. `retrive` restores its own `$ra` from `12($sp)` (which neither call could
   have disturbed) and returns to the loop in `handler`.

Because every step in that chain only ever touches registers it explicitly
owns, the loop counter in `$s3` and the saved `$ra` in `retrive`'s frame stay
exactly as they were left, no matter what state the rest of the system was in
when the exception fired.

## 7. The `0x1F802041` TTY register — emulator-only debug output

PSn00bSDK's `printf` and the PS1 BIOS both write text output to `0x1F802041`
rather than to the SIO1 serial port. This address falls inside the
**Expansion 2** memory region (`0x1F802000`–`0x1F802041`, 66 bytes), which
was reserved on PS1 hardware for external development boards attached to the
expansion bus.

On retail hardware this region has no physical device behind it. Writes to
`0x1F802041` are silently discarded — there is no pin, no signal, no way to
read the data from outside the console. Emulators intercept those writes and
display them in a debug console purely as a developer convenience.

This is why `printf` output appears in PCSX-Redux's log window but is
completely invisible on a real PS1. The BIOS itself contains the same writes
(the `PS-X Realtime Kernel`, `KERNEL SETUP!` and similar boot messages all
go through this path), which confirms that Sony's internal development
toolchain used Expansion 2 as a TTY channel but stripped the corresponding
hardware from the retail board.

`send_string` and `send_hex` in this file deliberately target SIO1
(`0x1F801050` / `0x1F801054`) instead, because that maps to the physical
serial port that exists on every PS1 revision. If dual output is needed
during emulator development, a `sb` to `0x1F802041` can be added immediately
after the SIO1 write — the TTY register requires no wait loop or status check.

```mips
    sb      $t1, 0x1f801050($zero)  # SIO1 -> physical serial / PuTTY
    sb      $t1, 0x1f802041($zero)  # TTY  -> emulator log (no-op on hardware)
```

## 8. References

- **`common/hardware/sio.h` (Nugget, MIT licensed, PCSX-Redux authors)** —
  this is where the `0x1F801040`/`0x1F801044` addresses used in
  `send_string`/`send_hex` actually come from. Nugget defines a
  `struct SIOPort` mapped at `0x1F801040` via `#define SIOS
  ((volatile struct SIOPort *)0x1f801040)`, where the first byte (`fifo`) is
  the data register and `stat` lands at offset `+4` inside that struct -
  which is exactly why `0x1F801044` is the status register. The ready bit is
  named there as `SIO_STAT_TXRDY = (1 << 0)` inside the `SIO_STAT_*` enum,
  matching the bit this file polls before every write. The high-level
  functions in PSn00bSDK's `psxsio.h` (`SIO_WriteByte`, `SIO_WriteSync`,
  etc.) wrap that same hardware with IRQ-driven ring buffers;
  `send_string`/`send_hex` intentionally skip that layer and talk to the
  struct fields directly, the same bare-metal approach Nugget itself uses in
  `sio.h`'s own `exchangeByte()` helper.
- **MIPS calling convention (saved vs. temporary registers, delay slots)** —
  the reasoning about `$s0`-`$s7` being expected to survive a call, and
  about why every load/branch needs a `nop` in its delay slot, follows the
  standard MIPS I/MIPS32 calling convention and pipeline behavior that the
  original `Exception_handler.s` already assumes (`.set noreorder` is used
  for the same reason in both files).
- **Exception handler structure** — the overall pattern of resolving the
  active TCB pointer and walking a table of register offsets comes from the
  existing `handler`/`retrive` routines in `Exception_handler.s`; this
  document only covers the serial-output half (`sio_low.s`), not the
  exception dispatch logic itself.
- **PSn00bSDK `psxsio.h`** — used as the reference point for what the
  higher-level API normally provides (`SIO_Init`, `AddSIO`, blocking vs.
  non-blocking reads/writes) and, by contrast, why none of that machinery is
  appropriate to call from inside the handler.
- **Expansion 2 / `0x1F802041` — emulator source reference**
  https://gist.github.com/dbousamra/f662f381d33fcf5c4a5475c4a656fa19 —
  emulator implementation showing that `0x1F802041` falls inside the
  Expansion 2 region (`0x1F802000`, 66 bytes) and that writes to it are
  silently discarded on retail hardware. The comment in that source
  ("doesn't do anything useful on real hardware") confirms what the BIOS
  behavior already implied: the register was wired to development boards
  only and has no physical pin on retail PS1 PCBs.
- **NYOットやろうぜ (dokutajigokusai / XEBRA author)**
  https://drhell.web.fc2.com/ps1/index.html —
  hardware research notes from the author of XEBRA, one of the most
  cycle-accurate PS1 emulators. Analysis was performed on real SCPH-7000
  hardware using a PS X-TERMINATOR connected via parallel port. Confirms
  the PS1 memory map (I/O ports at `0x1F801000`–`0x1F80207F`), the COP0
  register layout matching the LSI Logic LR33000, and warns that both the
  PADUA resource and Sony's own official development manuals contain
  transcription errors — hardware verification is the only reliable source.
  The `$13` (Cause) and `$14` (EPC) registers read by `verifier` and
  `retrive_cause` in `exception_handler.s` are documented there.
