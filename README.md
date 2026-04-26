# Sophia8

Sophia8 is an 8-bit virtual machine with 16-bit addressing, a matching assembler (`s8asm`), and a growing set of standard libraries and example programs, including a modular **Sophia BASIC v1**.

The VM has:
- 8 general-purpose 8-bit registers (`R0..R7`)
- 16-bit `IP`, `SP`, `BP`
- 64 KiB address space (`0x0000..0xFFFF`, image size `0x10000` bytes)
- memory-mapped console I/O at `0xFF00..0xFF03`
- optional debug-map driven breakpoints and verbose execution logging

## Toolchain overview

### Assembler: `s8asm`
`S8asm` compiles `.s8.asm` assembly into:
- `<output>.bin` — full `0x10000`-byte memory image
- `<output>.pre.s8.asm` — fully preprocessed source with include-origin markers
- `<output>.deb` — debug map used by the VM for file:line breakpoints and verbose traces

Useful commands:
```bash
./s8asm main.s8.asm -o program.bin
./s8asm --help
```

### VM: `sophia8`
The VM can:
- run a `.bin` image directly
- run from a `.deb` file and automatically load the referenced `.bin`
- stop on a source breakpoint (`file:line`)
- save `debug.img` snapshots and resume from them
- emit verbose instruction logs with `-v`

Useful commands:
```bash
./sophia8 program.bin
./sophia8 program.deb source.s8.asm 123
./sophia8 --deb program.deb -v program.bin
./sophia8 debug.img program.deb source.s8.asm 123
./sophia8 --help
```

## Sophia BASIC v1

`Sophia BASIC v1` is now split into focused modules. The top-level file `sophia_basic_v1.s8.asm` should remain mostly composition-only:
- core libraries at `0x0400`
- fixed BASIC strings/state blocks
- `basic_all.s8.asm` aggregate include
- final entry point

Implementation lives in `basic_*.s8.asm` files.

Program lines are stored as packed variable-length records with 16-bit line numbers. Practical BASIC program capacity depends on free RAM and average line length.

### Implemented BASIC areas

#### Program structure and flow
- line-numbered program storage and `RUN`
- packed variable-length program storage with 16-bit line numbers
- `GOTO`
- `IF ... THEN ... [ELSE ...]`
- `GOSUB` / `RETURN`
- `FOR` / `NEXT`
- `DO ... WHILE`
- `WHILE ... ENDWHILE`
- `END`, `STOP`
- `REM` and apostrophe (`'`) comments

#### Variables and arrays
- numeric variables
- string variables
- `DIM` for arrays
- string assignment and concatenation with `+`

#### Input / output and memory access
- `PRINT`
- `PRINT` item lists with `;` and `,`, including trailing `;` newline suppression
- `INPUT` for one or more variables, with optional quoted prompt strings
- `PEEK(address)`
- `POKE address, value`
- `RANDOMIZE`
- `RND()`

#### DATA support
- `DATA`
- `READ`
- `RESTORE`

#### String functions
- `LEN()`
- `LEFT$()`
- `RIGHT$()`
- `MID$()`
- `ASC()`
- `CHR$()`
- `INSTR()`
- `VAL()`
- `STR$()`
- string relational operators (`=`, `<>`, `<`, `>`, `<=`, `>=`)

## Important lessons and guardrails

### 1. `CMP`/`CMPR` are destructive
On Sophia8, compare instructions subtract into the compared register. Do not assume the input register survives a compare.

This already caused real bugs in BASIC flow-control stacks (`GOSUB`, `RETURN`, `FOR`, `NEXT`). Always compare on a scratch copy if the value is still needed later.
Also keep BASIC runtime stacks out of assembled code regions: `0x6A00/0x6A20` are no longer safe once the modular BASIC grows. Preserve `0x9600/0x9601` for user `POKE`, and keep `GOSUB`/`FOR` stacks in a dedicated free RAM block instead.

### 2. `POKE 38400` / `POKE 38401` must stay safe
Decimal `38400` and `38401` are addresses `0x9600` and `0x9601`.

A real regression happened when BASIC code growth moved interpreter code into that range. Then a user program doing:
```basic
30 POKE 38400, 65
31 POKE 38401, 25
```
started overwriting interpreter instructions and broke later execution.

Current mitigation in the codebase:
- `basic_stmt.s8.asm` intentionally leaves a gap so `0x9600/0x9601` stay free
- `basic_data_cmd.s8.asm` was moved to a high segment (`0xC000`) to keep growth away from that scratch region

Treat `0x9600..0x9601` as a **reserved BASIC scratch / test-safe region** unless you intentionally redesign the memory map. Future code growth must not silently consume it.

### 3. Keep BASIC modular
Do not move feature logic back into `sophia_basic_v1.s8.asm`. New features should go into focused modules and be wired through `basic_all.s8.asm`.

### 4. Always use fresh build + tests
The project is expected to be validated by a clean rebuild and test run. Existing CMake/CTest wiring already covers:
- graphics test
- standard library test
- BASIC automatic integration test
- BASIC loop integration test

The test harness is platform-neutral: CTest uses `cmake -P` driver scripts instead of shell pipelines, so the suite is expected to run on Windows as well as POSIX environments.

Typical workflow:
```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build --output-on-failure
```

## Main project files
- `s8asm.cpp` — assembler
- `sophia8.cpp` — VM
- `sophia8.context.json` — machine-readable context / rules / lessons learned
- `sophia8.md` — human-oriented technical notes
- `sophia_basic_v1.s8.asm` — BASIC composition unit
- `basic_*.s8.asm` — BASIC modules
- `sophia_basic_test_auto.bas` — BASIC integration coverage

## Graphics
The VM supports a C64-style graphics mode sourced from memory base `0x8000` (9000 bytes). `--gfx` opens a fullscreen SDL window that renders directly from mapped memory, and `--gfx-out <file.ppm>` optionally writes the final frame to PPM.

## More detail
For assembler, ISA, memory map, libraries, debugging, and implementation pitfalls, see:
- `sophia8.context.json`
- `sophia8.md`
- `s8asm.md`
