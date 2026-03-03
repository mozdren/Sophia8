# Sophia8
This is a simple virtual machine which simulates 8 bit computer with 16 bit addressing, and random access memory (not a plain stack machine). The machine has 8 general purpose registers and a stack which starts pointing at the end of memory and goes down as being pushed upon.

## Sophia BASIC layout
The BASIC implementation is intentionally split into focused include files to keep `sophia_basic_v1.s8` easier to edit:

- `basic_state.s8` – fixed-address runtime state (variables, stacks, scratch buffers)
- `basic_rng.s8` – BASIC RNG glue (seed storage + wrapper over `rng.s8`)
- `basic_init.s8` – initialization (variable table reset, string heap pointer, default RNG seed, stack reset)
- `basic_strings.s8` – fixed-address banner/errors and keyword strings (stable addresses)
- `basic_errors.s8` – error printing helpers (PRINT_SYNTAX_ERROR, PRINT_NO_PROGRAM, PRINT_UNDEF_LINE)
- `basic_progstore.s8` – program line storage helpers (store/delete/find/list)
- `basic_vars.s8` – variable table helpers (lookup/create, load/store 16-bit values)
- `basic_expr.s8` – expression engine (ident/number parsing, boolean ops, precedence parser, PEEK/RND)
- `basic_io.s8` – PRINT/INPUT commands and output helper (DO_PRINT)
- `basic_assign.s8` – LET and implicit assignment parsing (numeric + string assignment)
- `basic_flow.s8` – flow-control statements (GOSUB/RETURN, FOR/NEXT) and loop stack logic
- `basic_stmt.s8` – statement dispatcher + built-in command handlers
- `basic_repl.s8` – REPL loop and program execution loop (RUN)
- `basic_helpers.s8` – shared helpers used by BASIC (token/parse helpers, address helpers)

The goal is that future refactors extract *from* `sophia_basic_v1.s8` into small libraries, instead of growing the monolithic BASIC file.
