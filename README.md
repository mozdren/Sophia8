# Sophia8
This is a simple virtual machine which simulates 8 bit computer with 16 bit addressing, and random access memory (not a plain stack machine). The machine has 8 general purpose registers and a stack which starts pointing at the end of memory and goes down as being pushed upon.

## BASIC String Functions
BASIC now supports string functions: LEN(), LEFT$(), RIGHT$(), MID$(), ASC(), CHR$(), INSTR(), VAL(), STR$().
It also supports string concatenation with '+' in PRINT and string assignments (e.g., A$=A$+"X").
See basic_strfn.s8 and sophia_basic_test_auto.bas for examples.


## BASIC Flow Control
BASIC supports subroutines using `GOSUB <line>` and `RETURN` during program execution (`RUN`).
This enables reusable code blocks and is implemented in `basic_flow.s8`.
