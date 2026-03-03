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

# ---------------------------------------------------------------------------
# VM/assembler integration tests
# ---------------------------------------------------------------------------
# These tests assemble small .s8 programs and run them in the VM.
# They are intentionally shell-based (single process) to keep the project
# dependency-free.

add_test(
    NAME test_libs_s8
    COMMAND bash -lc
        "set -euo pipefail; \
         ./s8asm ${CMAKE_CURRENT_SOURCE_DIR}/test_libs.s8 -o test_libs.bin >/dev/null; \
         out=$(./sophia8 test_libs.bin); \
         echo \"$out\" | grep -q \"ALL PASS\""
)


add_test(
    NAME test_basic_auto
    COMMAND bash -lc
        "set -euo pipefail; \
         ./s8asm ${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_v1.s8 -o sophia_basic_v1.bin >/dev/null; \
         # The BASIC image enters REPL after RUN and keeps waiting for input.
         # We use a short timeout and still validate the produced output.\
         out=$((cat ${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_auto.bas; echo RUN) | timeout 2s ./sophia8 sophia_basic_v1.bin || true); \
         echo \"$out\" | grep -q \"SOPHIA BASIC AUTO TEST\"; \
         # FOR/NEXT loop 1..5\
         echo \"$out\" | grep -q $\'\\n1\\n2\\n3\\n4\\n5\\n\'; \
         # FOR with STEP -1: 3,2,1\
         echo \"$out\" | grep -q $\'\\n3\\n2\\n1\\n\'; \
         # IF..THEN..ELSE clause\
         echo \"$out\" | grep -q $\'\\n222\\n\'; \
         # GOSUB/RETURN prints 7 then later 8\
         echo \"$out\" | grep -q $\'\\n7\\n\'; \
         echo \"$out\" | grep -q $\'\\n8\\n\'; \
         # POKE/PEEK outputs (exact lines)\
         printf \"%s\\n\" \"$out\" | grep -qx \"65\"; \
         printf \"%s\\n\" \"$out\" | grep -qx \"25\""
)
