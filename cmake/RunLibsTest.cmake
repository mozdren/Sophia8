if(NOT DEFINED ASM OR NOT DEFINED VM OR NOT DEFINED SOURCE_DIR OR NOT DEFINED BINARY_DIR)
    message(FATAL_ERROR "RunLibsTest.cmake requires ASM, VM, SOURCE_DIR, and BINARY_DIR")
endif()

set(bin_path "${BINARY_DIR}/test_libs.bin")

execute_process(
    COMMAND "${ASM}" "${SOURCE_DIR}/test_libs.s8.asm" -o "${bin_path}"
    RESULT_VARIABLE asm_rc
    OUTPUT_VARIABLE asm_out
    ERROR_VARIABLE asm_err
)

if(NOT asm_rc STREQUAL "0")
    message(FATAL_ERROR "Assembler failed for test_libs.s8.asm\n${asm_out}${asm_err}")
endif()

execute_process(
    COMMAND "${VM}" "${bin_path}"
    RESULT_VARIABLE vm_rc
    OUTPUT_VARIABLE vm_out
    ERROR_VARIABLE vm_err
    TIMEOUT 8
)

if(NOT vm_rc STREQUAL "0")
    message(FATAL_ERROR "VM failed for test_libs.bin\n${vm_out}${vm_err}")
endif()

string(FIND "${vm_out}" "ALL PASS" all_pass_pos)
if(all_pass_pos EQUAL -1)
    message(FATAL_ERROR "Expected 'ALL PASS' in VM output, got:\n${vm_out}${vm_err}")
endif()
