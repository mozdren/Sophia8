#!/usr/bin/env bash
set -euo pipefail
./s8asm "${PWD%/build}/sophia_basic_v1.s8" -o sophia_basic_v1.bin >/dev/null
rm -f loops.out got.txt exp.txt
(cat "${PWD%/build}/sophia_basic_test_loops.bas"; echo RUN) | timeout 8s ./sophia8 sophia_basic_v1.bin > loops.out || true
grep -qx 'SOPHIA BASIC LOOP TEST' loops.out
awk 'f && $0 != "> "{print} $0=="SOPHIA BASIC LOOP TEST"{f=1;next}' loops.out | head -n 11 > got.txt
printf '0
1
2
10
11
12
20
21
1
2
77
' > exp.txt
diff -u exp.txt got.txt
