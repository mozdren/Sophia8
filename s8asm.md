# Sophia8 Assembler (`s8asm`)
Programmer’s Reference Manual
==============================

This document describes the **Sophia8 assembler language**, the `s8asm` assembler tool,
the runtime expectations, and the provided `kernel.s8` support code.

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

If `-o` is omitted, assembly fails.

### What the assembler does

1. Parses all `.include` files (recursively)
2. Resolves labels globally
3. Applies `.org` directives
4. Emits a **JMP instruction at address `0x0000`** to the entry point
5. Outputs a full binary image

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

There are no warnings. Either the program is correct, or it does not assemble.

---

## 3. Program entry and `.org`

### Entry point

A Sophia8 program **must** define an entry `.org` without an address.

```asm
.org
START:
    HALT
```

- The assembler emits `JMP START` at address `0x0000`
- Only one entry `.org` is allowed

### Absolute origin

```asm
.org 0x0200
Data:
```

Defines absolute placement.

### Rules

- Overlapping `.org` regions → error
- Entry `.org` missing → error
- Multiple entry `.org` → error

---

## 4. Includes

```asm
.include "kernel.s8"
.include "utils/math.s8"
```

- Paths are relative to the including file
- Unlimited nesting
- Include cycles are detected and rejected

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

- `R0`–`R9`
- Case-sensitive

### Whitespace

- Multiple spaces allowed
- One instruction per line

---

## 7. Data directives

### `.byte`

```asm
.byte 0x01, 2, 0b10101010
```

### `.word`

16‑bit big-endian values:

```asm
.word 0x0200, START
```

### `.string`

```asm
Msg: .string "Hello\n"
```

- ASCII only
- Automatic `0x00` terminator
- Escapes supported: `\n`, `\t`, `\"`, `\\`

Non‑ASCII → error.

---

## 8. Instruction set

### Data movement

| Instruction | Description |
|------------|-------------|
| SET #imm, Rn | Set register |
| LOAD addr, Rn | Load from memory |
| STORE Rn, addr | Store to memory |
| STORER Rn, Rh, Rl | Store via register address |
| LOADR Rn, Rh, Rl | Load via register address |

---

### Stack and calls

| Instruction | Description |
|------------|-------------|
| PUSH Rn | Push register |
| POP Rn | Pop register |
| CALL addr | Call subroutine |
| RET | Return |

Stack notes:
- Grows downward
- No overflow or underflow protection

---

### Arithmetic and logic

| Instruction | Description |
|------------|-------------|
| ADD #imm, Rn |
| ADDR Rn, Rm |
| SUB #imm, Rn |
| SUBR Rn, Rm |
| MUL #imm, Rn, Rm |
| MULR Rn, Rm, Rx |
| DIV #imm, Rn, Rm |
| DIVR Rn, Rm, Rx |
| INC Rn |
| DEC Rn |
| SHL #n, Rn |
| SHR #n, Rn |

---

### Control flow

| Instruction | Description |
|------------|-------------|
| CMP Rn, #imm |
| CMPR Rn, Rm |
| JMP addr |
| JZ Rn, addr |
| JNZ Rn, addr |
| JC addr |
| JNC addr |
| NOP |
| HALT |

---

## 9. Memory‑mapped I/O

| Address | Name | Direction |
|--------:|------|-----------|
| 0xFF00 | KBD_STATUS | Read |
| 0xFF01 | KBD_DATA | Read |
| 0xFF02 | TTY_STATUS | Read |
| 0xFF03 | TTY_DATA | Write |

- Write a byte to `0xFF03` to output a character
- Keyboard behavior depends on host environment

---

## 10. `kernel.s8`

`kernel.s8` is an optional support library included via `.include`.

### Exported routines

| Routine | Description |
|-------|-------------|
| PUTC | Output char in `R0` |
| GETC | Blocking input |
| GETC_NB | Non‑blocking input |
| PUTS | Print NUL‑terminated string |

### Calling convention

- Arguments in registers
- No registers preserved
- Caller is responsible for saving state

---

## 11. Example: Hello, Sophia!

```asm
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

## 12. Known limitations

- No memory protection
- No interrupts
- No stack safety
- No multitasking
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
