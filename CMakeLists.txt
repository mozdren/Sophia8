cmake_minimum_required(VERSION 3.16)
project(sophia8 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(SDL2 CONFIG QUIET)
if(TARGET SDL2::SDL2)
    set(SOPHIA8_SDL_TARGET SDL2::SDL2)
else()
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(SDL2 REQUIRED IMPORTED_TARGET sdl2)
    set(SOPHIA8_SDL_TARGET PkgConfig::SDL2)
endif()

add_executable(sophia8
        sophia8.cpp
        graphics_c64.cpp
)
target_include_directories(sophia8 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})
target_link_libraries(sophia8 PRIVATE ${SOPHIA8_SDL_TARGET})

add_executable(s8asm s8asm.cpp)
target_include_directories(s8asm PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

add_executable(test_graphics_c64
        test_graphics_c64.cpp
        graphics_c64.cpp
)
target_include_directories(test_graphics_c64 PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

enable_testing()
add_test(NAME test_graphics_c64 COMMAND test_graphics_c64)

add_test(
    NAME test_equ
    COMMAND ${CMAKE_COMMAND}
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunEquTest.cmake
)

# Integration tests (assembler + VM)
add_test(
    NAME test_libs_s8
    COMMAND ${CMAKE_COMMAND}
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunLibsTest.cmake
)

add_test(
    NAME test_basic_auto
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_auto
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_auto.bas
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_auto.txt
        -DMARKER=SOPHIA_BASIC_AUTO_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_loops
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_loops
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_loops.bas
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_loops.txt
        -DMARKER=SOPHIA_BASIC_LOOP_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_for
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_for
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_for.bas
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_for.txt
        -DMARKER=SOPHIA_BASIC_FOR_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_dim
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_dim
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_dim.bas
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_dim.txt
        -DMARKER=SOPHIA_BASIC_DIM_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_high_lines
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_high_lines
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_high_lines.bas
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_high_lines.txt
        -DMARKER=SOPHIA_BASIC_HIGH_LINE_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_data
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_data
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_data.bas
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_data.txt
        -DMARKER=SOPHIA_BASIC_DATA_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_rng
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_rng
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_rng.bas
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_rng.txt
        -DMARKER=SOPHIA_BASIC_RNG_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_stop
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_stop
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_stop.bas
        -DTEST_INPUT_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/basic_stop.in
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_stop.txt
        -DMARKER=SOPHIA_BASIC_STOP_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_io
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_io
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_io.bas
        -DTEST_INPUT_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/basic_io.in
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_io.txt
        -DMARKER=SOPHIA_BASIC_IO_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)

add_test(
    NAME test_basic_input
    COMMAND ${CMAKE_COMMAND}
        -DTEST_NAME=test_basic_input
        -DASM=$<TARGET_FILE:s8asm>
        -DVM=$<TARGET_FILE:sophia8>
        -DSOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR}
        -DBINARY_DIR=${CMAKE_CURRENT_BINARY_DIR}
        -DBASIC_SOURCE=${CMAKE_CURRENT_SOURCE_DIR}/sophia_basic_test_input.bas
        -DTEST_INPUT_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/inputs/basic_input.in
        -DEXPECTED_FILE=${CMAKE_CURRENT_SOURCE_DIR}/tests/expected/basic_input.txt
        -DMARKER=SOPHIA_BASIC_INPUT_TEST
        -P ${CMAKE_CURRENT_SOURCE_DIR}/cmake/RunBasicTest.cmake
)
