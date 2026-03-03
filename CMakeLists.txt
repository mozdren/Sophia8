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