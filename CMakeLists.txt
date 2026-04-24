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
