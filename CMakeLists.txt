cmake_minimum_required(VERSION 3.14)

project( "Sophia8" )

# dependencies

# executables and linked libraries

add_executable( sophia8 sophia8.cpp definitions.h)
add_executable( sophia8asm sophia8asm.cpp definitions.h)

# Required Resources

file( COPY "test.asm" DESTINATION "Release/" )
file( COPY "test.asm" DESTINATION "Debug/" )

set_property( TARGET sophia8 PROPERTY VS_DEBUGGER_WORKING_DIRECTORY "$(Configuration)" )