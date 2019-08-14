cmake_minimum_required(VERSION 3.14)

project( "Sophia8" )

# dependencies

set(SDL2_DIR ../SDL2/SDL2-devel-2.0.10-VC/SDL2-2.0.10)

find_package(SDL2 REQUIRED)
include_directories(${SDL2_INCLUDE_DIRS})

# executables and linked libraries

set(SOPHIA8_CPP_FILES
    sophia8.cpp
)

set(SOPHIA8_H_FILES
    definitions.h
)

set(SOPHIA8ASM_CPP_FILES
    sophia8asm.cpp
    my_string.cpp
    assembly_parser.cpp
)

set(SOPHIA8ASM_H_FILES
    definitions.h
    assembly_parser.h
    my_string.h
)

set(SOPHIA8CHARSET_CPP_FILES
    sophia8charset.cpp
)

set(SOPHIA8CHARSET_H_FILES
    definitions.h
)

add_executable( sophia8 ${SOPHIA8_CPP_FILES} ${SOPHIA8_H_FILES})
add_executable( sophia8asm ${SOPHIA8ASM_CPP_FILES} ${SOPHIA8ASM_H_FILES})
add_executable( sophia8charset ${SOPHIA8CHARSET_CPP_FILES} ${SOPHIA8CHARSET_H_FILES})

# libraries

target_link_libraries(sophia8 ${SDL2_LIBRARIES})
target_link_libraries(sophia8charset ${SDL2_LIBRARIES})

# Required Resources

file( COPY "test.asm" DESTINATION "Release/" )
file( COPY "test.asm" DESTINATION "Debug/" )
file( COPY "kernel.asm" DESTINATION "Release/" )
file( COPY "kernel.asm" DESTINATION "Debug/" )
file( COPY "chars.asm" DESTINATION "Release/" )
file( COPY "chars.asm" DESTINATION "Debug/" )
file( COPY "${SDL2_DIR}/lib/x86/SDL2.dll" DESTINATION "Debug/" )
file( COPY "${SDL2_DIR}/lib/x86/SDL2.dll" DESTINATION "Release/" )
