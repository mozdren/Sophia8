# Sophia 8 – Libraries and Debugging Notes

This document describes the extracted helper libraries and how to use them from Sophia 8 assembly programs.

## Quick include set

Typical programs include only what they use:

```asm
.include "kernel.s8"          ; console/syscalls
.include "mem.s8"             ; memset/memcpy helpers
.include "str.s8"             ; basic string helpers
.include "fmt.s8"             ; formatting helpers (printing)

; extracted helpers
.include "line.s8"            ; line input (echo + backspace)
.include "parse.s8"           ; parsing helpers (skip spaces, parse u8)
.include "ctype.s8"           ; ASCII classification/conversion
.include "u16.s8"             ; 16-bit unsigned helpers
.include "int16.s8"           ; 16-bit signed helpers
.include "conv.s8"            ; string ↔ integer conversions
.include "stdio_console.s8"   ; stdio-like wrappers for console
```

## Extracted libraries

### line.s8

- **READLINE_ECHO** – reads a line with echo and backspace handling.
  - Inputs: `R1:R2` destination buffer, `R3` max bytes (including `\0`)
  - Returns: `R4` length (excluding `\0`)
  - Terminates on CR/LF, always null-terminates if `max > 0`.

### parse.s8

- **SKIPSPACES** – advances `R1:R2` past spaces (0x20) and tabs (0x09).
- **PARSE_U8_DEC** – parses an unsigned 8-bit decimal value with overflow detection.

These were extracted from the former CLI helpers.

### ctype.s8

Small ASCII helpers:

- **ISDIGIT**: `R4=1` if `R0` is `'0'..'9'`
- **ISSPACE**: `R4=1` if `R0` is space/tab/CR/LF
- **TOLOWER** / **TOUPPER**: converts ASCII case when applicable

### u16.s8 / int16.s8

16-bit helpers use a **hi:lo** convention.

- `U16_ADD`, `U16_SUB`, `U16_CMP`
- `U16_SHL1`, `U16_SHR1`
- `U16_MUL_U8` (16-bit × 8-bit)
- `U16_DIV_U8` (16-bit ÷ 8-bit)
- `I16_NEG` (two’s complement negate)

### conv.s8

Conversions:

- **PARSE_U16_DEC** – parses `0..65535`
  - Input: `R1:R2` pointer
  - Output: `R6:R7` value, `R4` success, `R1:R2` advanced pointer

- **PARSE_I16_DEC** – parses `-32768..32767`
  - Input: `R1:R2` pointer
  - Output: `R6:R7` value, `R4` success

- **U16_TO_DEC_BUF** – converts a 16-bit unsigned value to a decimal string in a buffer
  - Input: `R0:R1` value, `R2:R3` output buffer, `R4` max bytes including `\0`
  - Output: `R6=1` success else `0`, `R5` length (excluding `\0`)

### stdio_console.s8

Simple wrappers around the kernel console:

- `PUTCHAR` (calls `PUTC`)
- `GETCHAR` (calls `GETC`)
- `FPUTS` (calls `PUTS`)
- `FGETS` (calls `READLINE_ECHO`)

## Notes and pitfalls

- `.byte` accepts **numeric literals only** (no labels, no `#`).
- `.word` accepts **numeric literals or labels** (no `#`).
- Operand **label arithmetic** (like `LABEL+1`) is not supported. Prefer:
  - passing pointers via registers,
  - fixed absolute addresses (when appropriate),
  - or data layouts that avoid needing “+1”.

## Debugging and verbose logging

The Sophia 8 toolchain supports `.deb` debug files for address↔source mapping.

The VM supports:

- `--help` for usage
- breakpoint validation (cannot set a breakpoint on a line without executable code)
- optional **verbose logging** with `-v` (writes executed commands/parameters, memory updates, and register dumps to the specified debug file)

(See `sophia8.context.json` for the machine-readable overview.)
