# Sophia8 Assembler (`s8asm`)
Programmer’s Reference Manual (Assembler + ISA + Standard Libraries)
====================================================================

This document describes the **Sophia8 assembler language**, the `s8asm` assembler tool,
the Sophia8 VM instruction set as implemented by `sophia8`, and the provided
standard libraries (`kernel.s8`, `mem.s8`, `fmt.s8`, `str.s8`, `cli.s8`).

This is written as a *working engineer’s reference*, not marketing material.
Everything here is explicit. Anything not described should be considered undefined.

---

## 1. Overview

Sophia8 is a deliberately small virtual 8‑bit computer.

- **Data width:** 8 bit
- **Address width:** 16 bit (0x0000–0xFFFF)
- **Memory model:** unified (code and data share memory)
- **Execution model:** single-threaded, deterministic
- **Endianness:** big-endian for 16‑bit values

The assembler produces a **full memory image**, not relocatable object files.

---

## 2. The `s8asm` assembler

### Invocation

```bash
s8asm input.s8 -o output.bin
```

- `input.s8` — main assembly file
- `output.bin` — raw binary memory image

If `-o` is omitted, the assembler writes `sophia8_image.bin` in the current directory.

### What the assembler does

1. Preprocesses `.include` (recursively) as *textual include*
2. Builds a single global label namespace
3. Applies `.org` directives (absolute placement)
4. Reserves addresses `0x0000..0x0002` for an implicit entry stub
5. Emits an implicit `JMP <entry>` at `0x0000`
6. Outputs a full binary image of size `0xFFFF` bytes

### Errors are strict

The assembler **fails hard** on:

- Undefined labels
- Duplicate labels
- Invalid instructions
- Invalid operands
- Multiple entry `.org`
- Overlapping memory regions
- Non-ASCII strings
- Include cycles
- Multiple inclusion of the same include file (include-once is enforced)

There are no warnings. Either the program is correct, or it does not assemble.

---

## 3. Program entry and `.org`

### Entry point

### The implicit entry stub

The assembler always emits an implicit 3-byte entry stub at `0x0000`:

```text
0x0000: JMP <entry>
```

Because of this, `s8asm` forbids placing any user code/data below `0x0003`.

### Entry point selection

You may (optionally) mark an explicit entry point using `.org` with **no operand**:

```asm
.org
START:
    HALT
```

- If present, the entry address is the location counter at that `.org` line
- Only one entry marker `.org` (no operand) is allowed

If no entry marker exists, the entry address becomes the address of the *first*
`.org <addr>` in the program.

### Absolute origin

```asm
.org 0x0200
Data:
```

Defines absolute placement.

### Rules

- `.org <addr>` requires a **numeric literal** (labels are not allowed)
- `.org <addr>` must be `>= 0x0003` and `<= 0xFFFF`
- Overlapping writes → error
- Multiple entry markers `.org` (no operand) → error
- At least one `.org` (either form) must appear somewhere → error if missing

---

## 4. Includes

```asm
.include "kernel.s8"
.include "utils/math.s8"
```


- Paths are resolved relative to the including file
- Unlimited nesting depth
- Include cycles are detected and rejected
- **Multiple inclusion is forbidden**: the same include file may appear only once

Includes are textual and resolved before assembly.

---

## 5. Labels

- Case-sensitive
- Global namespace (across includes)
- May appear alone or on the same line

```asm
Loop:
    INC R0

Msg: .string "Hello"
```

Errors:
- Duplicate label → error
- Undefined label → error

---

## 6. Literals and syntax

### Numbers

- Decimal: `10`
- Hex: `0x0A`
- Binary: `0b00001010`

### Immediate values

Use `#`:

```asm
SET #0x41, R0
```

### Registers

General purpose registers:

- `R0`–`R7` (8-bit)

Special registers (16-bit; usable only with `PUSH`/`POP`):

- `IP` (instruction pointer)
- `SP` (stack pointer)
- `BP` (base/frame pointer)

### Whitespace

- Multiple spaces allowed
- One instruction per line

---

## 7. Data directives

### `.byte`

```asm
.byte 0x01, 2, 0b10101010

Notes:
- `.byte` accepts **numeric literals only** (labels are not allowed)
- Values must be `0..255`
```

### `.word`

16‑bit big-endian values:

```asm
.word 0x0200, START

Notes:
- `.word` accepts numeric literals or labels
- Values must be `0..65535`
```

### `.string`

```asm
Msg: .string "Hello\n"
```

- ASCII only
- Automatic `0x00` terminator
- Escapes supported: `\n`, `\r`, `\t`, `\0`, `\"`, `\\`, `\xNN` (two hex digits)

Non-ASCII → error.

---

## 8. Instruction set

### Data movement

| Instruction | Encoding | Description |
|------------|----------|-------------|
| SET #imm8, Rn | `04 imm reg` | `Rn = imm8` |
| LOAD addr16, Rn | `01 hi lo reg` | `Rn = mem[addr16]` |
| STORE Rn, addr16 | `02 reg hi lo` | `mem[addr16] = Rn` |
| LOADR Rdst, Rhi, Rlo | `1C dst hi lo` | `Rdst = mem[(Rhi<<8)|Rlo]` |
| STORER Rsrc, Rhi, Rlo | `03 src hi lo` | `mem[(Rhi<<8)|Rlo] = Rsrc` |

---

### Stack and calls

| Instruction | Encoding | Description |
|------------|----------|-------------|
| PUSH Rn | `10 reg` | Push an 8-bit register value |
| POP Rn | `11 reg` | Pop into an 8-bit register |
| PUSH IP/SP/BP | `10 reg` | Push 16-bit value as two bytes (big-endian) |
| POP IP/SP/BP | `11 reg` | Pop 16-bit value from two bytes (big-endian) |
| CALL addr16 | `12 hi lo` | Push return address (16-bit), jump to `addr16` |
| RET | `13` | Return to address popped from stack |

Stack notes:
- Stack grows downward in memory
- No overflow/underflow protection
- `CALL/RET` always use 16-bit return addresses

---

### Arithmetic and logic

| Instruction | Encoding | Description |
|------------|----------|-------------|
| ADD #imm8, Rn | `0E imm reg` | `Rn += imm8` (8-bit wrap), sets carry on overflow |
| ADDR Rsrc, Rdst | `0F src dst` | `Rdst += Rsrc` (8-bit wrap), sets carry on overflow |
| SUB #imm8, Rn | `14 imm reg` | `Rn -= imm8` (8-bit wrap), sets carry on borrow |
| SUBR Rsrc, Rdst | `15 src dst` | `Rdst -= Rsrc` (8-bit wrap), sets carry on borrow |
| INC Rn | `05 reg` | `Rn++`, sets carry if it wrapped from `0xFF` to `0x00` |
| DEC Rn | `06 reg` | `Rn--`, sets carry if it wrapped from `0x00` to `0xFF` |
| SHL #n, Rn | `1A n reg` | `Rn <<= n`, carry = last bit shifted out (per VM implementation) |
| SHR #n, Rn | `1B n reg` | `Rn >>= n`, carry = last bit shifted out (per VM implementation) |
| MUL #imm8, Rlo, Rhi | `16 imm rlo rhi` | 16-bit product; `Rlo=low`, `Rhi=high`, carry=1 if high!=0 |
| MULR Rsrc, Rlo, Rhi | `17 src rlo rhi` | 16-bit product; `Rlo=low`, `Rhi=high`, carry=1 if high!=0 |
| DIV #imm8, Rq, Rr | `18 imm rq rr` | `Rq=Rq/imm`, `Rr=Rq%imm` (beware overwrite), carry unchanged |
| DIVR Rsrc, Rq, Rr | `19 src rq rr` | `Rq=Rq/Rsrc`, `Rr=Rq%Rsrc` (beware overwrite), carry unchanged |

Notes:
- Division by 0 is undefined (host crash or VM stop).
- For `DIV/DIVR`, the VM computes quotient/remainder from the *original* value in `Rq`.
  If `Rq` and `Rr` are the same register, the remainder overwrites the quotient.

---

### Control flow

| Instruction | Encoding | Description |
|------------|----------|-------------|
| CMP Rn, #imm8 | `08 reg imm` | **Destructive compare**: `Rn -= imm8`; carry=1 if borrow (Rn < imm8) |
| CMPR Rn, Rm | `09 rn rm` | **Destructive compare**: `Rn -= Rm`; carry=1 if borrow (Rn < Rm) |
| JMP addr16 | `07 hi lo` | `IP = addr16` |
| JZ Rn, addr16 | `0A reg hi lo` | jump if `Rn == 0` |
| JNZ Rn, addr16 | `0B reg hi lo` | jump if `Rn != 0` |
| JC addr16 | `0C hi lo` | jump if carry flag `C == 1` |
| JNC addr16 | `0D hi lo` | jump if carry flag `C == 0` |
| NOP | `FF` | no operation |
| HALT | `00` | stop the VM |

Important:
- `CMP/CMPR` modify the compared register (they subtract). If you need a non-destructive compare,
  copy the value to a scratch register first.

---

## 9. Memory-mapped I/O (MMIO)

| Address | Name | Direction |
|--------:|------|-----------|
| 0xFF00 | KBD_STATUS | Read |
| 0xFF01 | KBD_DATA | Read |
| 0xFF02 | TTY_STATUS | Read |
| 0xFF03 | TTY_DATA | Write |

- Write a byte to `0xFF03` to output a character
- Keyboard behavior depends on host environment

---

## 10. `kernel.s8` (console kernel)

`kernel.s8` is an optional support library included via `.include`.

### Exported routines

| Routine | Args | Returns | Clobbers | Description |
|--------|------|---------|----------|-------------|
| PUTC | `R0` = char | — | `R3` | Waits for TTY ready, writes `R0` to `0xFF03` |
| GETC | — | `R0` = char | `R3` | Blocking key read |
| GETC_NB | — | `R0` = char or `0x00`, `R1` = 1/0 | `R3` | Non-blocking key read |
| PUTS | `R1:R2` = pointer | — | `R0`, `R3` | Print NUL-terminated string |

### Calling convention

- Arguments in registers
- No registers preserved (save what you need)
- Strings are ASCII and NUL-terminated

---

## 11. Standard libraries

These libraries are optional and are meant to be included explicitly.

### `mem.s8`

| Routine | Args | Returns | Clobbers | Description |
|--------|------|---------|----------|-------------|
| MEMSET | `R1:R2` dst, `R0` value, `R3` len | — | `R3`, `R4` | Fill memory with a byte |
| MEMCPY | `R1:R2` dst, `R3:R4` src, `R5` len | — | `R0`, `R5` | Copy memory forward |

### `fmt.s8` (depends on `kernel.s8`)

| Routine | Args | Returns | Clobbers | Description |
|--------|------|---------|----------|-------------|
| PUTHEX8 | `R0` value | — | `R0`,`R1`,`R2`,`R4`,`R5` (+kernel `R3`) | Print 2-digit uppercase hex |
| PUTHEX16 | `R1:R2` value | — | `R0` + PUTHEX8 clobbers | Print 4-digit uppercase hex |
| PUTDEC8 | `R0` value | — | `R0`,`R1`,`R2`,`R4` (+kernel `R3`) | Print unsigned 0..255 decimal |

### `str.s8`

| Routine | Args | Returns | Clobbers | Description |
|--------|------|---------|----------|-------------|
| STRLEN | `R1:R2` s | `R0` len | `R0`,`R3` | Compute length (advances pointer) |
| STREQ | `R1:R2` s1, `R3:R4` s2 | `R0` = 1/0 | `R0`,`R5`,`R6`,`R7` | String equality (advances pointers) |

### `cli.s8` (depends on `kernel.s8`)

| Routine | Args | Returns | Clobbers | Description |
|--------|------|---------|----------|-------------|
| READLINE_ECHO | `R1:R2` buf, `R3` max (incl NUL) | `R4` len | `R0`,`R3`,`R5`,`R6`,`R7` | Read line, echo, backspace, NUL-terminate |

## 12. Example: Hello, Sophia!

```asm
.org 0x0800
.include "kernel.s8"

.org 0x0200
Msg: .string "Hello, Sophia!\n"

.org
START:
    SET #0x02, R1
    SET #0x00, R2
    CALL PUTS
    HALT
```

Assemble:
```bash
s8asm hello.s8 -o hello.bin
```

Run:
```bash
sophia8 hello.bin
```

---

## 13. Known limitations / sharp edges

- No memory protection
- No interrupts
- No stack safety
- No multitasking
- `CMP/CMPR` are destructive (they subtract)
- `.byte` cannot use labels
- `.org` operands must be numeric literals (no labels)
- Include-once is enforced (multiple inclusion errors)
- IDE consoles may buffer input
- Behavior outside defined instructions is undefined but deterministic

These limitations are **intentional**.

---

## 13. Design intent

Sophia8 exists to be *fully understandable*.

- No hidden behavior
- No magic
- No implicit state

If something feels manual, that is the point.
