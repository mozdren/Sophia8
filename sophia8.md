# Sophia 8 – Technical Notes, Libraries, BASIC, and Debugging

This document is the human-oriented companion to `sophia8.context.json`. It summarizes the current state of the Sophia8 toolchain, standard libraries, Sophia BASIC layout, and the implementation pitfalls that have already caused real bugs.

## 1. Toolchain summary

### Assembler (`s8asm`)
The assembler is strict and intentionally simple.

It produces three artifacts:
- `<output>.bin` — full `0x10000`-byte memory image
- `<output>.pre.s8.asm` — preprocessed source with all `.include` content expanded
- `<output>.deb` — debug map used by the VM for file:line breakpoints and verbose logs

Important rules:
- `.org <addr>` takes a numeric literal only
- `.org` without an operand marks the entry point and may appear only once
- `.byte` accepts numeric literals only
- `.word` accepts numeric literals or labels
- `.include` is textual and include-once is enforced
- overlapping output bytes are an error

### VM (`sophia8`)
The VM can run:
- a raw `.bin` image
- a `.deb` file directly (it resolves the paired `.bin`)
- a saved `debug.img` snapshot

The VM models a true 64 KiB machine. The empty-stack sentinel is `SP=BP=0x0000`, so the first push wraps into `0xFFFF` and the stack then grows downward through RAM.

Debugging support includes:
- `--help`
- source breakpoint support from `.deb`
- validation that a breakpoint line really maps to executable code
- `debug.img` snapshot generation when a breakpoint is hit
- resume from `debug.img`
- `-v` verbose per-instruction logging

## 2. Standard library overview

Typical assembly programs include only what they need.

```asm
.include "kernel.s8.asm"
.include "mem.s8.asm"
.include "str.s8.asm"
.include "fmt.s8.asm"
.include "line.s8.asm"
.include "parse.s8.asm"
.include "ctype.s8.asm"
.include "u16.s8.asm"
.include "int16.s8.asm"
.include "conv.s8.asm"
.include "stdio_console.s8.asm"
```

### line.s8.asm
- `READLINE_ECHO` — line input with echo and backspace handling

### parse.s8.asm
- `SKIPSPACES`
- `PARSE_U8_DEC`

### ctype.s8.asm
- `ISDIGIT`
- `ISSPACE`
- `TOLOWER`
- `TOUPPER`

### u16.s8.asm / int16.s8.asm
16-bit helpers using hi:lo convention.

Examples:
- `U16_ADD`, `U16_SUB`, `U16_CMP`
- `U16_SHL1`, `U16_SHR1`
- `U16_MUL_U8`, `U16_DIV_U8`
- `I16_NEG`

### conv.s8.asm
Conversions between decimal strings and 16-bit numbers.

### stdio_console.s8.asm
Simple stdio-like wrappers around console primitives.

## 3. Sophia BASIC v1 architecture

The intended structure is:
- `sophia_basic_v1.s8.asm` = composition/wiring only
- `basic_all.s8.asm` = aggregate include list for feature modules
- implementation in focused `basic_*.s8.asm` files

Current aggregate includes:
- errors/helpers/vars
- string functions and expression parser
- RNG support
- assignment, I/O, flow control
- DATA scanner/runtime
- statement dispatcher
- program storage / REPL
- DATA command handlers
- arrays
- initialization

This modular split is important for maintainability. New features should be added as focused modules rather than growing the top-level BASIC file.

## 4. Current BASIC feature set

### Flow and control
- `RUN`
- packed variable-length program storage with 16-bit line numbers
- `GOTO`
- `IF ... THEN ... [ELSE ...]`
- `GOSUB` / `RETURN`
- `FOR` / `NEXT`
- `DO ... WHILE`
- `WHILE ... ENDWHILE`
- `END`, `STOP`
- `REM` and apostrophe (`'`) comments

### Variables and arrays
- numeric variables
- string variables
- `DIM`
- string concatenation and assignment

### I/O and runtime helpers
- `PRINT`
- `PRINT` item lists with `;` and `,`, including trailing `;` newline suppression
- `INPUT` for a single variable, with optional quoted prompt strings
- `RANDOMIZE`
- `RND()`
- `PEEK()` / `POKE`

### DATA support
- `DATA`
- `READ`
- `RESTORE`

### String functions
- `LEN`
- `LEFT$`
- `RIGHT$`
- `MID$`
- `ASC`
- `CHR$`
- `INSTR`
- `VAL`
- `STR$`
- string relational operators

## 5. Memory layout and placement notes

### Fixed areas already in use
- entry stub reserved by assembler: `0x0000..0x0002`
- core libraries and BASIC composition start around `0x0400`
- BASIC fixed strings: `0x0200+`
- BASIC state blocks: `0x6800+`
- BASIC program storage uses packed variable-length line records in RAM
- `basic_strfn.s8.asm`: `0x7000`
- `basic_data_cmd.s8.asm`: `0xC000`
- VM MMIO: `0xFF00..0xFF03`

### Critical reserved BASIC scratch region
`0x9600` / `0x9601` (decimal `38400` / `38401`) must remain safe for BASIC user `POKE` tests and scratch usage.

This is not a VM-enforced MMIO area. It is a **project memory-layout convention** that exists because real BASIC tests write there.

A regression already happened when interpreter code expanded into `0x9600..0x9601`. User `POKE` then overwrote interpreter instructions, which caused later failures in `IF` and string/DATA paths. The current layout avoids that by:
- leaving a gap in `basic_stmt.s8.asm`
- relocating `basic_data_cmd.s8.asm` to `0xC000`

When adding new BASIC code, always verify that code growth has not reclaimed `0x9600..0x9601`.

## 6. Important implementation lessons

### `CMP` / `CMPR` are destructive
They subtract into the compared register. If you still need the original value after the comparison, copy it first.

This caused a real stack corruption bug in BASIC `GOSUB`/`RETURN` and loop bookkeeping.

### Avoid silent self-corruption with `POKE`
Because BASIC can write arbitrary addresses, interpreter layout matters. Tests and examples already use decimal `38400`/`38401`, so code placement must respect that.

### Keep using the debug artifacts
When behavior becomes unclear, use:
- `<program>.pre.s8.asm` to verify include expansion and final source order
- `<program>.deb` for exact address↔source mapping
- VM `-v` logs to find loops, register damage, or unexpected memory writes

### One feature, one focused test
BASIC regressions are often integration issues, not isolated parser bugs. Every new feature should add or extend an executable test scenario.

## 7. Debugging workflow that has proven useful

1. Build from a clean directory.
2. Run the existing tests with `ctest --test-dir build --output-on-failure`.
3. Assemble the BASIC image and inspect `<output>.pre.s8.asm` when include order or `.org` placement is suspicious.
4. Use `<output>.deb` to find the exact machine address for a source line.
5. Run the VM with `-v` when execution appears stuck or corrupted.
6. Use source breakpoints to emit `debug.img` and inspect machine state at a precise location.

The current CTest integration is platform-neutral and avoids shell-only features such as `bash`, `awk`, `grep`, `diff`, and `timeout`.

## 8. Notes and pitfalls carried forward

- `.byte` accepts numeric literals only
- `.word` accepts numeric literals or labels
- label arithmetic like `LABEL+1` is not supported by the assembler
- include-once is enforced
- labels are global after preprocessing
- diagnostics are strongest when file:line and include-stack information are preserved

## 9. What to keep stable

Try to preserve these project conventions unless there is a conscious redesign:
- modular BASIC organization
- `.deb` and `.pre.s8.asm` generation on every assembly
- breakpoint validation in the VM
- verbose logging only when explicitly enabled
- reserved BASIC scratch safety at `0x9600..0x9601`
