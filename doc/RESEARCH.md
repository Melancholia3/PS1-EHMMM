# PS1 Exception Handler — Research & Internals

This document covers what actually went into making EHMMM work — what failed,
why it failed, and what the correct approach turned out to be. If you just want
to use the handler, the README has everything you need. This is for people who
want to understand what's happening under the hood, or who are trying to build
something similar.

Tested against Sony retail BIOS (SCPH1001.BIN) and SCPH7502. Same binary,
no recompile — both work identically.

---

## What didn't work

### Attempt 1 — `OpenEvent(HwCPU, EvSpERROR, EvMdINTR, handler)`

```c
int ev = OpenEvent(HwCPU, EvSpERROR, EvMdINTR, custom_exception_handler);
EnableEvent(ev);
```

The handler never fired. Looking at PSn00bSDK's `interrupts.c` explains why:
PSn00bSDK installs its own interrupt system via `HookEntryInt(&_isr_jmp_buf)`.
`HwCPU`/`OpenEvent` are Sony BIOS syscall stubs — they exist as symbols but
aren't wired up to handle CPU exceptions under PSn00bSDK. There's no evidence
it ever worked in this environment.

### Attempt 2 — Hooking `a0table[0x40]` (Spencer Alves' approach, `error.c`)

```c
static void (** const a0table)() = (void (**)())0x200;
void InstallExceptionHandler() {
    oldHandler = a0table[0x40];
    a0table[0x40] = UnresolvedException;
}
```

Still nothing — the log cut off at the exception message without ever reaching
our code. Reading OpenBIOS's `vectors.s` explains it: when an exception isn't
handled by any priority chain, OpenBIOS does a `longjmp` to
`g_exceptionJmpBufPtr`, it does *not* call `a0table[0x40]`. Worth noting that
on a real PS1 with the original Sony BIOS, this method probably works fine —
`error.c` was written for that environment specifically.

At this point the code looked correct, the registers looked correct, and nothing
was obviously wrong. That's when the CPU trace in PCSX-Redux became the only
real tool — enabling it, setting a breakpoint just before the handler, running,
stopping, and reading what the CPU was actually doing line by line. At first it
nearly killed the PC (copying three million lines of unpadded output hurts), but
once the breakpoint workflow was in place it became clear the handler was reading
a wrong address — not the wrong logic, a wrong address.

---

## How the PS1 exception system actually works

The CPU jumps to `0x80000080` on any exception. The BIOS dispatcher there walks
**priority chains** — linked lists of `INT_RP` structs, each with a verifier
and a handler. `SysEnqIntRP` is how you add your own entry without breaking
everything else, and it's the same mechanism PSn00bSDK uses internally.

```c
void SysEnqIntRP(int pri, INT_RP *rp);
void SysDeqIntRP(int pri, INT_RP *rp);
```

The `INT_RP` struct has a naming trap worth calling out explicitly:

```c
typedef struct _INT_RP {
    uint32_t *next;   // +0: next element in chain
    uint32_t *func2;  // +4: VERIFIER — runs FIRST, decides whether to handle
    uint32_t *func1;  // +8: HANDLER  — runs AFTER, only if verifier returns != 0
    int _reserved;
} INT_RP;
```

`func1` and `func2` run in the opposite order from what the names suggest.
Confirmed independently by `no$psx` (Martin Korth), `libpsn00b/psxapi.h`, and
`vectors.s` from OpenBIOS/Nugget.

One thing to note during the lecture of `vectors.s`: the kernel does
`move $a0, $v0` just before calling the handler, so whatever the verifier
returned in `$v0` arrives in `$a0`. You can pass the ExcCode this way without
reading COP0 twice.

Default priority chains (from `no$psx`):
```
Prio 0: CdromDmaIrq, CdromIoIrq, SyscallException
Prio 1: CardSpecificIrq, VblankIrq, Timer2Irq, Timer1Irq, Timer0Irq
Prio 2: PadCardIrq
Prio 3: DefInt
```

---

## Reading the TCB — and the pipeline hazard that ruins everything

When an exception fires, the BIOS saves CPU state into the active **Task
Control Block** (TCB), reachable from `0x108`:

```
0x108 → TCBH pointer → TCBH->entry → active TCB
```

```c
struct TCB {
    long status;
    long mode;
    unsigned long reg[40];
    long system[6];
};
```

Confirmed offsets (retail BIOS and OpenBIOS):

| Register | Offset | Formula    |
|----------|--------|------------|
| `$sp`    | `0x7c` | `8 + 29*4` |
| `$ra`    | `0x84` | `8 + 31*4` |
| EPC      | `0x88` | `8 + 32*4` |
| CAUSE    | `0x98` | `8 + 36*4` |

Getting these reads right was painful. The code was syntactically correct, the
logic looked fine, and the handler kept printing garbage or zeros. Back to the
CPU trace — breakpoint, enable trace, run, stop, read. That's when `lw` showed
up as the culprit.

The R3000A is a 5-stage pipeline. A value loaded with `lw` isn't available in
the immediately following instruction — the pipeline hasn't finished the load
yet. Without a `nop` after each load in the pointer chain, the next instruction
reads the register before the new value is there. An exception inside an
exception handler, which is as fun as it sounds.

```asm
lw      $s0, 0x108($zero)   # load TCBH pointer
nop                          # wait for the pipeline
lw      $s0, 0($s0)         # load TCB — without the nop above $s0 is still 0
nop
lw      $a1, 0x7c($s0)      # safe to read $sp now
```

---

## The printf problem

Once the TCB reads worked, there was a working but rough version of the handler.
`printf` was printing the first value correctly then cutting off or producing
garbage when looped.

The problem in reality wasn't that complex: `printf` clobbers `$t0`–`$t9`,
which is legal under the MIPS calling convention. If the TCB pointer was sitting
in a `$t` register across a `jal printf`, it was gone when `printf` returned.
Saving `$ra` wasn't enough — `$sp` needed to grow too, and even that didn't
guarantee `printf` wouldn't touch addresses it shouldn't.

The stress of it working in one version but breaking as a proper function
was real. CPU trace again — and this time it accidentally recorded 500MB of log
before stopping, which was its own kind of fun. But going through it made one
thing clear: `printf` is not reliable inside an exception handler. It's too
heavy, routes through the BIOS TTY driver, uses internal scratch space and
IRQ-driven ring buffers. An exception can fire mid-formatting and calling
`printf` again from the handler risks reusing corrupted internal state.

Going under `printf` entirely and talking directly to the SIO hardware was the
only clean way out. One thing to note during experimentation: the SIO just needs
a busy-wait on `TXRDY` before every byte write — no IRQ, no buffer, no state to
corrupt. See `sio_low_explained.md` for the full details.

---

## CAUSE decoding

ExcCode lives in bits 6:2 of the CAUSE register:

```asm
srl     $t0, $t0, 2
andi    $t0, $t0, 0x1f
```

| Code   | Name                | Meaning                                |
|--------|---------------------|----------------------------------------|
| `0x00` | Interrupt           | Normal hardware IRQ — not a crash      |
| `0x04` | AddressErrorLoad    | Read from invalid/unaligned address    |
| `0x05` | AddressErrorStore   | Write to invalid address               |
| `0x06` | BusErrorInstr       | Instruction fetch from invalid address |
| `0x07` | BusErrorData        | Invalid bus access on data             |
| `0x08` | Syscall             | Intentional syscall — not a crash      |
| `0x09` | Breakpoint          | `break` instruction                    |
| `0x0A` | ReservedInstruction | CPU tried to execute data as code      |
| `0x0B` | CoprocessorUnusable | Access to unavailable coprocessor      |
| `0x0C` | Overflow            | Signed arithmetic overflow             |

The verifier filters out `0x00` and `0x08` and passes everything else through.

---

## Known limitations

The handler only triggers on actual CPU exceptions. If a crash happens through
memory corruption that never generates a CPU exception — an out-of-bounds write
that corrupts DMA/GPU state and causes `DrawSync` to time out, for example —
the verifier never sees it. The R3000A has no MMU, so writing to arbitrary RAM
is silent as far as the CPU is concerned.

---

## References

- **Martin Korth — [`no$psx`](https://problemkaputt.de/psxspx-index.htm)** —
  `INT_RP` layout, TCB structure, CAUSE/ExcCode table, priority chain documentation.
- **Spencer Alves (impiaaa) — [`error.c`](https://gist.github.com/impiaaa/2c97419435cad2f40fe8a495d696ec52)** —
  standalone crash handler drawing directly to VRAM; source of the confirmed TCB offsets.
- **PCSX-Redux team — [Nugget/OpenBIOS](https://github.com/pcsx-redux/nugget/tree/main/openbios)** —
  `vectors.s` confirmed `INT_RP` execution order and the `$a0`/`$v0` trick.
- **"Dr.Hell" — [XEBRA](https://drhell.web.fc2.com/ps1/index.html)** —
  hardware research on PS1 memory map and I/O registers on real SCPH-7000 hardware.
- **dbousamra — [PS1 emulator source](https://gist.github.com/dbousamra/f662f381d33fcf5c4a5475c4a656fa19)** —
  confirmed `0x1F802041` (Expansion 2) is silently discarded on retail hardware.
