cmake_minimum_required(VERSION 3.14)

project( "Sophia8" )

# dependencies

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

add_executable( sophia8 ${SOPHIA8_CPP_FILES} ${SOPHIA8_H_FILES})
add_executable( sophia8asm ${SOPHIA8ASM_CPP_FILES} ${SOPHIA8ASM_H_FILES})

# Required Resources

file( COPY "test.asm" DESTINATION "Release/" )
file( COPY "test.asm" DESTINATION "Debug/" )
file( COPY "kernel.asm" DESTINATION "Release/" )
file( COPY "kernel.asm" DESTINATION "Debug/" )

set_property( TARGET sophia8 PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "$(Configuration)" )