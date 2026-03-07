cmake_minimum_required(VERSION 3.16)
project(sophia8 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(sophia8
        sophia8.cpp
        graphics_c64.cpp
)
target_include_directories(sophia8 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(s8asm s8asm.cpp)
target_include_directories(s8asm PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(test_graphics_c64
        test_graphics_c64.cpp
        graphics_c64.cpp
)
target_include_directories(test_graphics_c64 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

enable_testing()
add_test(NAME test_graphics_c64 COMMAND test_graphics_c64)

# Integration tests (assembler + VM)
add_test(
    NAME test_libs_s8
    COMMAND bash -lc
        "set -euo pipefail; \
         ./s8asm ${CMAKE_CURRENT_SOURCE_DIR}/test_libs.s8 -o test_libs.bin >/dev/null; \
         ./sophia8 test_libs.bin | tr -d '\\000' | grep -q 'ALL PASS'"
)

add_test(
    NAME test_basic_auto
    COMMAND bash -lc
        "set -euo pipefail; \
         ./s8asm ${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_v1.s8 -o sophia_basic_v1.bin >/dev/null; \
         rm -f basic.out got.txt exp.txt; \
         (cat ${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_auto.bas; echo RUN) | timeout 8s ./sophia8 sophia_basic_v1.bin > basic.out || true; \
         grep -qx 'SOPHIA BASIC AUTO TEST' basic.out; \
         awk 'f && $0 != \"\> \"{print} $0==\"SOPHIA BASIC AUTO TEST\"{f=1;next}' basic.out | head -n 53 > got.txt; \
         printf '13
7
30
26
3
65
25
5
HE
LLO
EL
HELL
65
72
B
C
3
0
1
123
-42
0
0
0
-42
123
AB
HELLO
ABCD
1
1
1
1
1
1
0
0
1
1
1
GOSUB
IN SUB
AFTER
REMOK
APOSOK
1
2
3
HI
THERE
1
HI
' > exp.txt; \
         diff -u exp.txt got.txt"
)

add_test(
    NAME test_basic_loops
    COMMAND bash ${CMAKE_CURRENT_SOURCE_DIR}/test_basic_loops.sh
)
