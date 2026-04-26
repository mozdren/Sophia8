if(NOT DEFINED TEST_NAME OR NOT DEFINED ASM OR NOT DEFINED VM OR NOT DEFINED SOURCE_DIR OR NOT DEFINED BINARY_DIR OR NOT DEFINED BASIC_SOURCE OR NOT DEFINED EXPECTED_FILE OR NOT DEFINED MARKER)
    message(FATAL_ERROR "RunBasicTest.cmake requires TEST_NAME, ASM, VM, SOURCE_DIR, BINARY_DIR, BASIC_SOURCE, EXPECTED_FILE, and MARKER")
endif()

if(NOT DEFINED BASIC_TEST_TIMEOUT_SECONDS)
    set(BASIC_TEST_TIMEOUT_SECONDS 5)
endif()

string(REPLACE "_" " " marker_text "${MARKER}")

set(bin_path "${BINARY_DIR}/sophia_basic_v1.bin")
set(input_path "${BINARY_DIR}/${TEST_NAME}.in")
set(output_path "${BINARY_DIR}/${TEST_NAME}.out")
set(actual_path "${BINARY_DIR}/${TEST_NAME}.actual.txt")

execute_process(
    COMMAND "${ASM}" "${SOURCE_DIR}/sophia_basic_v1.s8.asm" -o "${bin_path}"
    RESULT_VARIABLE asm_rc
    OUTPUT_VARIABLE asm_out
    ERROR_VARIABLE asm_err
)

if(NOT asm_rc STREQUAL "0")
    message(FATAL_ERROR "Assembler failed for sophia_basic_v1.s8.asm\n${asm_out}${asm_err}")
endif()

file(READ "${BASIC_SOURCE}" basic_source_text)
file(WRITE "${input_path}" "${basic_source_text}\nRUN\n")
if(DEFINED TEST_INPUT_FILE)
    file(READ "${TEST_INPUT_FILE}" test_input_text)
    file(APPEND "${input_path}" "${test_input_text}")
endif()
file(APPEND "${input_path}" "HALT\n")

execute_process(
    COMMAND "${VM}" "${bin_path}"
    INPUT_FILE "${input_path}"
    OUTPUT_FILE "${output_path}"
    ERROR_VARIABLE vm_err
    RESULT_VARIABLE vm_rc
    TIMEOUT "${BASIC_TEST_TIMEOUT_SECONDS}"
)

file(STRINGS "${output_path}" output_lines)
set(found_marker FALSE)
set(actual_text "")

foreach(line IN LISTS output_lines)
    if(found_marker)
        if(line STREQUAL "> ")
            continue()
        endif()
        if(line STREQUAL "> HALT")
            continue()
        endif()
        string(APPEND actual_text "${line}\n")
    elseif(line STREQUAL "${marker_text}")
        set(found_marker TRUE)
    endif()
endforeach()

if(NOT found_marker)
    file(READ "${output_path}" vm_out)
    message(FATAL_ERROR "Marker '${marker_text}' not found in output for ${TEST_NAME} (result=${vm_rc})\n${vm_out}${vm_err}")
endif()

file(WRITE "${actual_path}" "${actual_text}")

file(READ "${EXPECTED_FILE}" expected_text)
file(READ "${actual_path}" actual_text)
string(REPLACE "\r\n" "\n" expected_text "${expected_text}")
string(REPLACE "\r\n" "\n" actual_text "${actual_text}")

if(NOT expected_text STREQUAL actual_text)
    message(FATAL_ERROR "Output mismatch for ${TEST_NAME} (result=${vm_rc})\nExpected:\n${expected_text}\nActual:\n${actual_text}\nVM stderr:\n${vm_err}")
endif()
