/*****************************************************************************/
/*                                                                           */
/* Project: Sophia8 - an 8 bit virtual machine                               */
/* Author:  Karel Mozdren                                                    */
/* File:    sophia8.cpp                                                      */
/* Date:    06.04.2017                                                       */
/*                                                                           */
/* Description:                                                              */
/*                                                                           */
/* This is a simple virtual machine which simulates 8 bit computer with      */
/* 16 bit addressing, and random access memory (not a plain stack machine).  */
/* The machine has 8 general purpose registers and a stack which starts      */
/* pointing at the end of memory and goes down as being pushed upon.         */
/*                                                                           */
/*****************************************************************************/

/* INCLUDES ******************************************************************/

#include <cstdio>
#include <cstdint>

#include "definitions.h"

/* REGISTERS *****************************************************************/

/* registers */

static uint8_t  r[8];           /* general purpose registers                 */
static uint16_t ip;             /* instruction pointer                       */
static uint16_t sp;             /* stack pointer                             */
static uint16_t bp;             /* stack frame pointer                       */

/* flags registers */

static uint8_t  c;              /* carry flag                                */

/* MEMORY ********************************************************************/

static uint8_t  mem[MEM_SIZE];  /* random access memory                      */

/* SPECIAL TRIGGERS **********************************************************/

static uint8_t  STOP = 0x00;    /* should stop the machine?                  */

/* MACHINE CODE **************************************************************/

/**
 *
 * initializes memory and registers to a startup values.
 * 
 * All ram values are set to 0x00 (HALT) and sets stack pointer and block
 * pointer to top of the memory.
 *
 */
void init_machine()
{
    uint16_t i;
    STOP = 0;

    /* clean all memory */
    for (i = 0; i < MEM_SIZE; i++)
    {
        mem[i] = HALT;
    }

    /* initialize registers */
    ip = 0;
    sp = MEM_SIZE;
    bp = MEM_SIZE;
    c = 0;

    for (i = 0; i < 8; i++)
    {
        r[i] = 0;
    }
}

/**
 * Processing a load instruction. This instruction loads data from a 16bit
 * memory location and saves it to a defined register.
 * 
 * LOAD 0x1A2B, R0 -> 00 1A 2B 00
 */
void load_instruction()
{
    static uint16_t memory_source;
    static uint8_t destination;
    static uint8_t value;

    memory_source = static_cast<uint16_t>(mem[ip + 1]);
    memory_source <<= 8;
    memory_source += static_cast<uint16_t>(mem[ip + 2]);

    value = mem[memory_source];

    destination = mem[ip + 3];

    switch (destination) 
    {
        case IR0: r[0] = value; break;
        case IR1: r[1] = value; break;
        case IR2: r[2] = value; break;
        case IR3: r[3] = value; break;
        case IR4: r[4] = value; break;
        case IR5: r[5] = value; break;
        case IR6: r[6] = value; break;
        case IR7: r[7] = value; break;
        default: STOP = 1; break;
    }

    ip += 4;
}

/**
 * Processing a store instruction. This instruction stores data from a specific
 * register to a 16bit memory location.
 * 
 * STORE 0x1A2B, R0 -> 01 1A 2B 00
 */
void store_instruction()
{
    static uint16_t memory_destination;
    static uint8_t source;
    static uint8_t value;

    source = mem[ip + 1]; 

    memory_destination = static_cast<uint16_t>(mem[ip + 2]);
    memory_destination <<= 8;
    memory_destination += static_cast<uint16_t>(mem[ip + 3]);

    switch (source) 
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: STOP = 1; break;
    }
    
    mem[memory_destination] = value;

    ip += 4;
}

/**
 * Processing a store instruction. This instruction stores data from a specific
 * register to a 16bit memory location defined by two additional registers.
 * 
 * STORER R0, R1, R2 -> 02 00 01 02
 */
void storer_instruction()
{
    static uint8_t source_register;
    static uint8_t destination_register_h;
    static uint8_t destination_register_l;
    
    static uint8_t value;
    static uint16_t destinationAddress;

    source_register = mem[ip + 1];
    destination_register_h = mem[ip + 2];
    destination_register_l = mem[ip + 3];
    
    switch (source_register) 
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: STOP = 1; break;
    }

    switch (destination_register_h) 
    {
        case IR0: destinationAddress = static_cast<uint16_t>(r[0]) << 8; break;
        case IR1: destinationAddress = static_cast<uint16_t>(r[1]) << 8; break;
        case IR2: destinationAddress = static_cast<uint16_t>(r[2]) << 8; break;
        case IR3: destinationAddress = static_cast<uint16_t>(r[3]) << 8; break;
        case IR4: destinationAddress = static_cast<uint16_t>(r[4]) << 8; break;
        case IR5: destinationAddress = static_cast<uint16_t>(r[5]) << 8; break;
        case IR6: destinationAddress = static_cast<uint16_t>(r[6]) << 8; break;
        case IR7: destinationAddress = static_cast<uint16_t>(r[7]) << 8; break;
        default: STOP = 1; break;
    }
    
    switch (destination_register_l) 
    {
        case IR0: destinationAddress += static_cast<uint16_t>(r[0]); break;
        case IR1: destinationAddress += static_cast<uint16_t>(r[1]); break;
        case IR2: destinationAddress += static_cast<uint16_t>(r[2]); break;
        case IR3: destinationAddress += static_cast<uint16_t>(r[3]); break;
        case IR4: destinationAddress += static_cast<uint16_t>(r[4]); break;
        case IR5: destinationAddress += static_cast<uint16_t>(r[5]); break;
        case IR6: destinationAddress += static_cast<uint16_t>(r[6]); break;
        case IR7: destinationAddress += static_cast<uint16_t>(r[7]); break;
        default: STOP = 1; break;
    }
    
    mem[destinationAddress] = value;
    
    ip += 4;
}

/**
 * Processing a set instruction. This instruction stores imidiate value to a
 * specific register.
 * 
 * SET 0x1A, R0 -> 03 1A 00
 */
void set_instruction()
{
    static uint8_t destination;
    static uint8_t value;

    value = mem[ip + 1];
    destination = mem[ip + 2];

    switch (destination) 
    {
        case IR0: r[0] = value; break;
        case IR1: r[1] = value; break;
        case IR2: r[2] = value; break;
        case IR3: r[3] = value; break;
        case IR4: r[4] = value; break;
        case IR5: r[5] = value; break;
        case IR6: r[6] = value; break;
        case IR7: r[7] = value; break;
        default: STOP = 1; break;
    }

    ip += 3;
}

/**
 * Processing a push instruction. This instruction stores a register value to
 * a top of the stack.
 *
 * PUSH R0 -> 10 00
 */
void push_instruction()
{
    static uint8_t source;
    static uint8_t value;

    sp--;
    value = 0;

    source = mem[ip+1];

    if (source == IIP)
    {
        value = static_cast<uint8_t>(ip & 0x00FF);
        mem[sp] = value;
        value = static_cast<uint8_t>((ip & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }
    
    if (source == ISP)
    {
        value = static_cast<uint8_t>(sp & 0x00FF);
        mem[sp] = value;
        value = static_cast<uint8_t>((sp & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }

    if (source == IBP)
    {
        value = static_cast<uint8_t>(bp & 0x00FF);
        mem[sp] = value;
        value = static_cast<uint8_t>((bp & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }

    switch (source) 
    {
    case IR0: value = r[0]; break;
    case IR1: value = r[1]; break;
    case IR2: value = r[2]; break;
    case IR3: value = r[3]; break;
    case IR4: value = r[4]; break;
    case IR5: value = r[5]; break;
    case IR6: value = r[6]; break;
    case IR7: value = r[7]; break;
    default: STOP = 1; break;
    }

    mem[sp] = value;

    ip+= 2;
}

/**
 * Processing a pop instruction. This instruction stores value on top of the
 * stack to a specific register.
 *
 * POP R0 -> 11 00
 */
void pop_instruction()
{
    static uint8_t source;
    static uint16_t value;

    value = 0;

    source = mem[ip+1];

    if (source == IIP)
    {
        value = (static_cast<uint16_t>(mem[sp]) << 8) + static_cast<uint16_t>(mem[sp + 1]);
        ip = value;
        sp += 2;
        ip += 2;
        return;
    }
    if (source == ISP)
    {
        value = (static_cast<uint16_t>(mem[sp]) << 8) + static_cast<uint16_t>(mem[sp + 1]);
        sp = value;
        sp += 2;
        ip += 2;
        return;
    }
    if (source == IBP)
    {
        value = (static_cast<uint16_t>(mem[sp]) << 8) + static_cast<uint16_t>(mem[sp + 1]);
        bp = value;
        sp += 2;
        ip += 2;
        return;
    }
    
    value = static_cast<uint16_t>(mem[sp]);

    switch (source) 
    {
    case IR0: r[0] = static_cast<uint8_t>(value); break;
    case IR1: r[1] = static_cast<uint8_t>(value); break;
    case IR2: r[2] = static_cast<uint8_t>(value); break;
    case IR3: r[3] = static_cast<uint8_t>(value); break;
    case IR4: r[4] = static_cast<uint8_t>(value); break;
    case IR5: r[5] = static_cast<uint8_t>(value); break;
    case IR6: r[6] = static_cast<uint8_t>(value); break;
    case IR7: r[7] = static_cast<uint8_t>(value); break;
    default: STOP = 1; break;
    }

    sp++;
    ip+= 2;
}

/*
 *
 * Increase Instruction. Increases register value by 1.
 *
 */
void inc_instruction()
{
    static uint8_t what;
    
    what = mem[ip + 1];

    switch (what) 
    {
        case IR0: r[0]++; c = r[0] == 0x00 ? 1 : 0; break;
        case IR1: r[1]++; c = r[1] == 0x00 ? 1 : 0; break;
        case IR2: r[2]++; c = r[2] == 0x00 ? 1 : 0; break;
        case IR3: r[3]++; c = r[3] == 0x00 ? 1 : 0; break;
        case IR4: r[4]++; c = r[4] == 0x00 ? 1 : 0; break;
        case IR5: r[5]++; c = r[5] == 0x00 ? 1 : 0; break;
        case IR6: r[6]++; c = r[6] == 0x00 ? 1 : 0; break;
        case IR7: r[7]++; c = r[7] == 0x00 ? 1 : 0; break;
        default: STOP = 1; break;
    }

    ip += 2;
}

/*
 *
 * Decrease Instruction. Decreases register value by 1.
 *
 */
void dec_instruction()
{
    static uint8_t what;
    
    what = mem[ip + 1];

    switch (what) 
    {
        case IR0: r[0]--; c = r[0] == 0xFF ? 1 : 0; break;
        case IR1: r[1]--; c = r[1] == 0xFF ? 1 : 0; break;
        case IR2: r[2]--; c = r[2] == 0xFF ? 1 : 0; break;
        case IR3: r[3]--; c = r[3] == 0xFF ? 1 : 0; break;
        case IR4: r[4]--; c = r[4] == 0xFF ? 1 : 0; break;
        case IR5: r[5]--; c = r[5] == 0xFF ? 1 : 0; break;
        case IR6: r[6]--; c = r[6] == 0xFF ? 1 : 0; break;
        case IR7: r[7]--; c = r[7] == 0xFF ? 1 : 0; break;
        default: STOP = 1; break;
    }

    ip += 2;
}

/**
 *
 * JMP instruction. Jumps to a specific 16 bit address.
 *
 */
void jmp_instruction()
{
    static uint16_t jump_address;

    jump_address = static_cast<uint16_t>(mem[ip + 1]) << 8;
    jump_address += static_cast<uint16_t>(mem[ip + 2]);

    ip = jump_address;
}

/**
 *
 * compares register to a value. If register value is less than imediate value
 * it sets the carry bit to true. Does subtraction on the backend. Subtracted
 * value is set in the register that has been used for comparison.
 *
 */
void cmp_instruction()
{
    static uint8_t source_register;
    static uint8_t value;
    
    source_register = mem[ip + 1];
    value = mem[ip + 2];
    
    switch (source_register) 
    {
        case IR0: c = r[0] >= value ? 0 : 1; r[0] -= value; break;
        case IR1: c = r[1] >= value ? 0 : 1; r[1] -= value; break;
        case IR2: c = r[2] >= value ? 0 : 1; r[2] -= value; break;
        case IR3: c = r[3] >= value ? 0 : 1; r[3] -= value; break;
        case IR4: c = r[4] >= value ? 0 : 1; r[4] -= value; break;
        case IR5: c = r[5] >= value ? 0 : 1; r[5] -= value; break;
        case IR6: c = r[6] >= value ? 0 : 1; r[6] -= value; break;
        case IR7: c = r[7] >= value ? 0 : 1; r[7] -= value; break;
        default: STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * compares register to another register. If register value is less than
 * imediate value it sets the carry bit to true. Does subtraction on the
 * backend. Subtracted value is set in the register that has been used 
 * for comparison.
 *
 */
void cmpr_instruction()
{
    static uint8_t register0;
    static uint8_t register1;
    static uint8_t value;
    
    register0 = mem[ip + 1];
    register1 = mem[ip + 2];
    
    switch (register1) 
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: STOP = 1; break;
    }
    
    switch (register0) 
    {
        case IR0: c = r[0] >= value ? 0 : 1;  r[0] -= value; break;
        case IR1: c = r[1] >= value ? 0 : 1;  r[1] -= value; break;
        case IR2: c = r[2] >= value ? 0 : 1;  r[2] -= value; break;
        case IR3: c = r[3] >= value ? 0 : 1;  r[3] -= value; break;
        case IR4: c = r[4] >= value ? 0 : 1;  r[4] -= value; break;
        case IR5: c = r[5] >= value ? 0 : 1;  r[5] -= value; break;
        case IR6: c = r[6] >= value ? 0 : 1;  r[6] -= value; break;
        case IR7: c = r[7] >= value ? 0 : 1;  r[7] -= value; break;
        default: STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * "Jump if zero" instruction. Jumps to a specific 16 bit address if selected
 * register is set to zero.
 *
 */
void jz_instruction()
{
    static uint8_t sourceRegister;
    static uint16_t jumpAddress;
    
    sourceRegister = mem[ip + 1];
    
    jumpAddress = static_cast<uint16_t>(mem[ip + 2]) << 8;
    jumpAddress += static_cast<uint16_t>(mem[ip + 3]);
    
    switch (sourceRegister) 
    {
        case IR0: if (r[0] == 0) {ip = jumpAddress; return;} break;
        case IR1: if (r[1] == 0) {ip = jumpAddress; return;} break;
        case IR2: if (r[2] == 0) {ip = jumpAddress; return;} break;
        case IR3: if (r[3] == 0) {ip = jumpAddress; return;} break;
        case IR4: if (r[4] == 0) {ip = jumpAddress; return;} break;
        case IR5: if (r[5] == 0) {ip = jumpAddress; return;} break;
        case IR6: if (r[6] == 0) {ip = jumpAddress; return;} break;
        case IR7: if (r[7] == 0) {ip = jumpAddress; return;} break;
        default: STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * "Jump if not zero" instruction. Jumps to a specific 16 bit address if
 * selected register is not set to zero.
 *
 */
void jnz_instruction()
{
    static uint8_t source_register;
    static uint16_t jump_address;
    
    source_register = mem[ip + 1];
    
    jump_address = static_cast<uint16_t>(mem[ip + 2]) << 8;
    jump_address += static_cast<uint16_t>(mem[ip + 3]);
    
    switch (source_register) 
    {
        case IR0: if (r[0] != 0) {ip = jump_address; return;} break;
        case IR1: if (r[1] != 0) {ip = jump_address; return;} break;
        case IR2: if (r[2] != 0) {ip = jump_address; return;} break;
        case IR3: if (r[3] != 0) {ip = jump_address; return;} break;
        case IR4: if (r[4] != 0) {ip = jump_address; return;} break;
        case IR5: if (r[5] != 0) {ip = jump_address; return;} break;
        case IR6: if (r[6] != 0) {ip = jump_address; return;} break;
        case IR7: if (r[7] != 0) {ip = jump_address; return;} break;
        default: STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * "Jump if carry set" instruction. Jumps to a specific 16 bit address if
 * carry is set.
 *
 */
void jc_instruction()
{
    static uint16_t jumpAddress;
    
    jumpAddress = static_cast<uint16_t>(mem[ip + 1]) << 8;
    jumpAddress += static_cast<uint16_t>(mem[ip + 2]);
    
    if (c != 0)
    {
        ip = jumpAddress;
        return;
    }
    
    ip += 3;
}

/**
 *
 * "Jump if carry not set" instruction. Jumps to a specific 16 bit address if
 * carry is not set.
 *
 */
void jnc_instruction()
{
    static uint16_t jumpAddress;
    
    jumpAddress = static_cast<uint16_t>(mem[ip + 1]) << 8;
    jumpAddress += static_cast<uint16_t>(mem[ip + 2]);
    
    if (c == 0)
    {
        ip = jumpAddress;
        return;
    }
    
    ip += 3;
}

/**
 *
 * Add instruction. Adds a value to a register.
 *
 */
void add_instruction()
{
    static uint8_t dest_register;
    static uint8_t value;
    
    value = mem[ip + 1];
    dest_register = mem[ip + 2];
    
    switch (dest_register)
    {
        case IR0: c = static_cast<uint16_t>(r[0]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[0] += value; break;
        case IR1: c = static_cast<uint16_t>(r[1]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[1] += value; break;
        case IR2: c = static_cast<uint16_t>(r[2]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[2] += value; break;
        case IR3: c = static_cast<uint16_t>(r[3]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[3] += value; break;
        case IR4: c = static_cast<uint16_t>(r[4]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[4] += value; break;
        case IR5: c = static_cast<uint16_t>(r[5]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[5] += value; break;
        case IR6: c = static_cast<uint16_t>(r[6]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[6] += value; break;
        case IR7: c = static_cast<uint16_t>(r[7]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[7] += value; break;
        default: STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Addr instruction. Adds a value of a specific register to a value in destination register.
 *
 */
void addr_instruction()
{
    static uint8_t destRegister;
    static uint8_t sourceRegister;
    static uint8_t value;
    
    sourceRegister = mem[ip + 1];
    destRegister = mem[ip + 2];
    
    switch (sourceRegister)
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: STOP = 1; break;
    }
    
    switch (destRegister)
    {
        case IR0: c = static_cast<uint16_t>(r[0]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[0] += value; break;
        case IR1: c = static_cast<uint16_t>(r[1]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[1] += value; break;
        case IR2: c = static_cast<uint16_t>(r[2]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[2] += value; break;
        case IR3: c = static_cast<uint16_t>(r[3]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[3] += value; break;
        case IR4: c = static_cast<uint16_t>(r[4]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[4] += value; break;
        case IR5: c = static_cast<uint16_t>(r[5]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[5] += value; break;
        case IR6: c = static_cast<uint16_t>(r[6]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[6] += value; break;
        case IR7: c = static_cast<uint16_t>(r[7]) + static_cast<uint16_t>(value) > 0xFF ? 1 : 0; r[7] += value; break;
        default: STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Call instruction. Jumps to a specified address and pushes return instruction
 * address onto a stack.
 *
 */
void call_instruction()
{
    static uint16_t callAddress;
    static uint16_t returnAddress;
    
    callAddress = static_cast<uint16_t>(mem[ip + 1]) << 8;
    callAddress += static_cast<uint16_t>(mem[ip + 2]);
    
    returnAddress = ip + 3;
    
    mem[sp - 2] = static_cast<uint8_t>((returnAddress & 0xFF00) >> 8);
    mem[sp - 1] = static_cast<uint8_t>(returnAddress & 0x00FF);
    sp -= 2;
    
    ip = callAddress;
}

/**
 *
 * Ret instruction. Returns from a procedure using the top of the stack as a
 * return address.
 *
 */
void ret_instruction()
{
    ip = static_cast<uint16_t>(mem[sp]) << 8;
    ip += static_cast<uint16_t>(mem[sp + 1]);
    sp += 2;
}

/**
 *
 * Sub instruction. Subtracts a value from a register.
 *
 */
void sub_instruction()
{
    static uint8_t destRegister;
    static uint8_t value;
    
    value = mem[ip + 1];
    destRegister = mem[ip + 2];
    
    switch (destRegister)
    {
        case IR0: c = r[0] < value ? 1 : 0; r[0] -= value; break;
        case IR1: c = r[1] < value ? 1 : 0; r[1] -= value; break;
        case IR2: c = r[2] < value ? 1 : 0; r[2] -= value; break;
        case IR3: c = r[3] < value ? 1 : 0; r[3] -= value; break;
        case IR4: c = r[4] < value ? 1 : 0; r[4] -= value; break;
        case IR5: c = r[5] < value ? 1 : 0; r[5] -= value; break;
        case IR6: c = r[6] < value ? 1 : 0; r[6] -= value; break;
        case IR7: c = r[7] < value ? 1 : 0; r[7] -= value; break;
        default: STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Subr instruction. Subtracts a value of a specific register from a value in destination register.
 *
 */
void subr_instruction()
{
    static uint8_t dest_register;
    static uint8_t source_register;
    static uint8_t value;
    
    source_register = mem[ip + 1];
    dest_register = mem[ip + 2];
    
    switch (source_register)
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: STOP = 1; break;
    }
    
    switch (dest_register)
    {
        case IR0: c = r[0] < value ? 1 : 0; r[0] -= value; break;
        case IR1: c = r[1] < value ? 1 : 0; r[1] -= value; break;
        case IR2: c = r[2] < value ? 1 : 0; r[2] -= value; break;
        case IR3: c = r[3] < value ? 1 : 0; r[3] -= value; break;
        case IR4: c = r[4] < value ? 1 : 0; r[4] -= value; break;
        case IR5: c = r[5] < value ? 1 : 0; r[5] -= value; break;
        case IR6: c = r[6] < value ? 1 : 0; r[6] -= value; break;
        case IR7: c = r[7] < value ? 1 : 0; r[7] -= value; break;
        default: STOP = 1; break;
    }
    
    ip += 3;
}

/**
 *
 * Mul instruction. multiplies a register by value. Saves result into two
 * registers.
 *
 */
void mul_instruction()
{
    static uint8_t dest_register_l;
    static uint8_t dest_register_h;
    static uint16_t value;
    static uint16_t result;
    
    value = (uint16_t)mem[ip + 1];
    dest_register_h = mem[ip + 2];
    dest_register_l = mem[ip + 3];
    
    switch (dest_register_l)
    {
        case IR0: 
            result = static_cast<uint16_t>(r[0]) * value;
            r[0] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR1: 
            result = static_cast<uint16_t>(r[1]) * value; 
            r[1] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR2: 
            result = static_cast<uint16_t>(r[2]) * value; 
            r[2] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR3: 
            result = static_cast<uint16_t>(r[3]) * value; 
            r[3] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR4: 
            result = static_cast<uint16_t>(r[4]) * value; 
            r[4] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR5: 
            result = static_cast<uint16_t>(r[5]) * value; 
            r[5] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR6: 
            result = static_cast<uint16_t>(r[6]) * value; 
            r[6] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR7: 
            result = static_cast<uint16_t>(r[7]) * value; 
            r[7] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        default: STOP = 1; break;
    }
    
    c = result > 0xFF ? 1 : 0;
    
    switch (dest_register_h)
    {
        case IR0: r[0] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR1: r[1] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR2: r[2] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR3: r[3] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR4: r[4] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR5: r[5] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR6: r[6] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR7: r[7] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        default: STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * Mulr instruction. Multiplies register value by a register value. Saves 
 * result into two registers.
 *
 */
void mulr_instruction()
{
    static uint8_t srcRegister;
    static uint8_t destRegisterL;
    static uint8_t destRegisterH;
    static uint16_t value;
    static uint16_t result;
    
    srcRegister = mem[ip + 1];
    destRegisterH = mem[ip + 2];
    destRegisterL = mem[ip + 3];
    
    switch (srcRegister)
    {
        case IR0: value = static_cast<uint16_t>(r[0]); break;
        case IR1: value = static_cast<uint16_t>(r[1]); break;
        case IR2: value = static_cast<uint16_t>(r[2]); break;
        case IR3: value = static_cast<uint16_t>(r[3]); break;
        case IR4: value = static_cast<uint16_t>(r[4]); break;
        case IR5: value = static_cast<uint16_t>(r[5]); break;
        case IR6: value = static_cast<uint16_t>(r[6]); break;
        case IR7: value = static_cast<uint16_t>(r[7]); break;
        default: STOP = 1; break;
    }
    
    switch (destRegisterL)
    {
        case IR0: 
            result = static_cast<uint16_t>(r[0]) * value;
            r[0] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR1: 
            result = static_cast<uint16_t>(r[1]) * value; 
            r[1] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR2: 
            result = static_cast<uint16_t>(r[2]) * value; 
            r[2] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR3: 
            result = static_cast<uint16_t>(r[3]) * value; 
            r[3] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR4: 
            result = static_cast<uint16_t>(r[4]) * value; 
            r[4] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR5: 
            result = static_cast<uint16_t>(r[5]) * value; 
            r[5] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR6: 
            result = static_cast<uint16_t>(r[6]) * value; 
            r[6] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        case IR7: 
            result = static_cast<uint16_t>(r[7]) * value; 
            r[7] = static_cast<uint8_t>(result & 0x00FF); 
            break;
        default: STOP = 1; break;
    }
    
    c = result > 0xFF ? 1 : 0;
    
    switch (destRegisterH)
    {
        case IR0: r[0] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR1: r[1] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR2: r[2] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR3: r[3] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR4: r[4] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR5: r[5] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR6: r[6] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        case IR7: r[7] = static_cast<uint8_t>((result & 0xFF00) >> 8); break;
        default: STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * Div instruction. divides a register by value. Saves results into two
 * registers. First register holds rusult of the dision, and the second
 * the rest of the division.
 *
 */
void divInstruction()
{
    static uint8_t destRegisterResult;
    static uint8_t destRegisterRest;
    static uint8_t value;
    static uint8_t result;
    static uint8_t rest;
    
    value = mem[ip + 1];
    destRegisterResult = mem[ip + 2];
    destRegisterRest = mem[ip + 3];
    
    switch (destRegisterResult)
    {
        case IR0: result = r[0] / value; rest = r[0] % value; r[0] = result; break;
        case IR1: result = r[1] / value; rest = r[1] % value; r[1] = result; break;
        case IR2: result = r[2] / value; rest = r[2] % value; r[2] = result; break;
        case IR3: result = r[3] / value; rest = r[3] % value; r[3] = result; break;
        case IR4: result = r[4] / value; rest = r[4] % value; r[4] = result; break;
        case IR5: result = r[5] / value; rest = r[5] % value; r[5] = result; break;
        case IR6: result = r[6] / value; rest = r[6] % value; r[6] = result; break;
        case IR7: result = r[7] / value; rest = r[7] % value; r[7] = result; break;
        default: STOP = 1; break;
    }
    
    switch (destRegisterRest)
    {
        case IR0: r[0] = rest; break;
        case IR1: r[1] = rest; break;
        case IR2: r[2] = rest; break;
        case IR3: r[3] = rest; break;
        case IR4: r[4] = rest; break;
        case IR5: r[5] = rest; break;
        case IR6: r[6] = rest; break;
        case IR7: r[7] = rest; break;
        default: STOP = 1; break;
    }
    
    ip += 4;
}

/**
 *
 * Divr instruction. divides a register by another register. Saves results into
 * two registers. First register holds rusult of the dision, and the second
 * the rest of the division.
 *
 */
void divr_instruction()
{
    static uint8_t src_register;
    static uint8_t dest_register_result;
    static uint8_t dest_register_rest;
    static uint8_t value;
    static uint8_t result;
    static uint8_t rest;
    
    src_register = mem[ip + 1];
    
    switch (src_register)
    {
        case IR0: value = r[0]; break;
        case IR1: value = r[1]; break;
        case IR2: value = r[2]; break;
        case IR3: value = r[3]; break;
        case IR4: value = r[4]; break;
        case IR5: value = r[5]; break;
        case IR6: value = r[6]; break;
        case IR7: value = r[7]; break;
        default: STOP = 1; break;
    }
    
    dest_register_result = mem[ip + 2];
    dest_register_rest = mem[ip + 3];
    
    switch (dest_register_result)
    {
        case IR0: result = r[0] / value; rest = r[0] % value; r[0] = result; break;
        case IR1: result = r[1] / value; rest = r[1] % value; r[1] = result; break;
        case IR2: result = r[2] / value; rest = r[2] % value; r[2] = result; break;
        case IR3: result = r[3] / value; rest = r[3] % value; r[3] = result; break;
        case IR4: result = r[4] / value; rest = r[4] % value; r[4] = result; break;
        case IR5: result = r[5] / value; rest = r[5] % value; r[5] = result; break;
        case IR6: result = r[6] / value; rest = r[6] % value; r[6] = result; break;
        case IR7: result = r[7] / value; rest = r[7] % value; r[7] = result; break;
        default: STOP = 1; break;
    }
    
    switch (dest_register_rest)
    {
        case IR0: r[0] = rest; break;
        case IR1: r[1] = rest; break;
        case IR2: r[2] = rest; break;
        case IR3: r[3] = rest; break;
        case IR4: r[4] = rest; break;
        case IR5: r[5] = rest; break;
        case IR6: r[6] = rest; break;
        case IR7: r[7] = rest; break;
        default: STOP = 1; break;
    }
    
    ip += 4;
}

/*
 *
 * Shifts value to the right. If last shifted bit was 1, then sets carry to 1.
 *
 */
void shrInstruction()
{
    static uint8_t what;
    static uint8_t val;
    
    val = mem[ip + 1];
    what = mem[ip + 2];

    switch (what) 
    {
        case IR0: c = (r[0] >> (val - 1)) % 2; r[0] >>= val; break;
        case IR1: c = (r[1] >> (val - 1)) % 2; r[1] >>= val; break;
        case IR2: c = (r[2] >> (val - 1)) % 2; r[2] >>= val; break;
        case IR3: c = (r[3] >> (val - 1)) % 2; r[3] >>= val; break;
        case IR4: c = (r[4] >> (val - 1)) % 2; r[4] >>= val; break;
        case IR5: c = (r[5] >> (val - 1)) % 2; r[5] >>= val; break;
        case IR6: c = (r[6] >> (val - 1)) % 2; r[6] >>= val; break;
        case IR7: c = (r[7] >> (val - 1)) % 2; r[7] >>= val; break;
        default: STOP = 1; break;
    }

    ip += 3;
}

/*
 *
 * Shifts value to the left. If last shifted bit was 1, then sets carry to 1.
 *
 */
void shl_instruction()
{
    static uint8_t what;
    static uint8_t val;
    
    val = mem[ip + 1];
    what = mem[ip + 2];

    switch (what) 
    {
        case IR0: c = r[0] << (val - 1) > 127 ? 1 : 0; r[0] <<= val; break;
        case IR1: c = r[1] << (val - 1) > 127 ? 1 : 0; r[1] <<= val; break;
        case IR2: c = r[2] << (val - 1) > 127 ? 1 : 0; r[2] <<= val; break;
        case IR3: c = r[3] << (val - 1) > 127 ? 1 : 0; r[3] <<= val; break;
        case IR4: c = r[4] << (val - 1) > 127 ? 1 : 0; r[4] <<= val; break;
        case IR5: c = r[5] << (val - 1) > 127 ? 1 : 0; r[5] <<= val; break;
        case IR6: c = r[6] << (val - 1) > 127 ? 1 : 0; r[6] <<= val; break;
        case IR7: c = r[7] << (val - 1) > 127 ? 1 : 0; r[7] <<= val; break;
        default: STOP = 1; break;
    }

    ip += 3;
}

/**
 *
 * Processes instruction. If unknown instruction or halt, then the VM stops.
 *
 */
void process_instruction()
{
    switch (mem[ip])
    {
        case LOAD: load_instruction(); break;
        case STORE: store_instruction(); break;
        case STORER: storer_instruction(); break;
        case SET: set_instruction(); break;
        case PUSH: push_instruction(); break;
        case POP: pop_instruction(); break;
        case INC: inc_instruction(); break;
        case DEC: dec_instruction(); break;
        case JMP: jmp_instruction(); break;
        case CMP: cmp_instruction(); break;
        case CMPR: cmpr_instruction(); break;
        case JZ: jz_instruction(); break;
        case JNZ: jnz_instruction(); break;
        case JC: jc_instruction(); break;
        case JNC: jnc_instruction(); break;
        case ADD: add_instruction(); break;
        case ADDR: addr_instruction(); break;
        case CALL: call_instruction(); break;
        case RET: ret_instruction(); break;
        case SUB: sub_instruction(); break;
        case SUBR: subr_instruction(); break;
        case MUL: mul_instruction(); break;
        case MULR: mulr_instruction(); break;
        case DIV: divInstruction(); break;
        case DIVR: divr_instruction(); break;
        case SHL: shl_instruction(); break;
        case SHR: shrInstruction(); break;
        case NOP: ip++; break;
        default: STOP = 1; break;
    }
}

/**
 *
 * Prints Memory
 *
 */
void print_memory()
{
    for (uint16_t i = 0; i < MEM_SIZE; i++)
    {
        if (i % 64 == 0)
        {
            // ReSharper disable once CppPrintfRiskyFormat
            printf("\n%#06x:", i);
        }

        printf(" %02x", mem[i]);
    }

    printf("\n");
}

/**
 *
 * Print registers
 *
 */
void print_registers()
{
    for (uint8_t i = 0; i < 8; i++)
    {
        printf("R%d = 0x%02x ", i, r[i]);
    }

    printf("IP = 0x%04x ", ip);
    printf("SP = 0x%04x ", sp);
    printf("BP = 0x%04x ", bp);
    printf("C = %d\n", c ? 1 : 0);
}

void run()
{
    while (!STOP)
    {
        process_instruction();
    }

    print_memory();
    print_registers();
}

void load_test_code()
{
    uint8_t test_code[202] = {
        SET,   0x0A,       IR0,        // 3
        STORE, IR0,        0xFF, 0xC0, // 7
        LOAD,  0xFF, 0xC0, IR1,        // 11
        SET,   0x01,       IR0,        // 14
        SET,   0x02,       IR1,        // 17
        SET,   0x03,       IR2,        // 20
        SET,   0x04,       IR3,        // 23
        SET,   0x05,       IR4,        // 26
        SET,   0x06,       IR5,        // 29
        SET,   0x07,       IR6,        // 32
        SET,   0x08,       IR7,        // 35
        PUSH,  IR0,                    // 37
        PUSH,  IR1,                    // 39
        PUSH,  IR2,                    // 41
        PUSH,  IR3,                    // 43
        PUSH,  IR4,                    // 45
        PUSH,  IR5,                    // 47
        PUSH,  IR6,                    // 49
        PUSH,  IR7,                    // 51
        POP,   IR0,                    // 53
        POP,   IR1,                    // 55
        POP,   IR2,                    // 57
        POP,   IR3,                    // 59
        POP,   IR4,                    // 61
        POP,   IR5,                    // 63
        POP,   IR6,                    // 65
        POP,   IR7,                    // 67
        SET,   0x00,       IR7,        // 70
        SET,   0xFF,       IR6,        // 73
        DEC,   IR7,                    // 75
        INC,   IR6,                    // 77
        SET,   0xBB,       IR0,        // 80
        SET,   0xFF,       IR1,        // 83
        SET,   0xC1,       IR2,        // 86
        STORER,IR0,        IR1, IR2,   // 90
        CMP,   IR0,        0x10,       // 93
        CMPR,  IR0,        IR1,        // 96
        NOP,                           // 97
        SET,   0xFF,       IR0,        // 100
        SET,   0x0A,       IR1,        // 103
        STORER,IR1,        IR0, IR1,   // 107
        DEC,   IR1,                    // 109
        JNZ,   IR1,        0x00, 0x67, // 113
        SET,   0xAA,       IR0,        // 116
        ADD,   0x01,       IR0,        // 119
        ADD,   0xFF,       IR0,        // 122
        SET,   0x00,       IR1,        // 125
        ADDR,  IR0,        IR1,        // 128
        CALL,  0x00, 0xC9,             // 131
        SET,   0x09,       IR0,        // 134
        SUB,   0x0A,       IR0,        // 137
        SET,   0x09,       IR1,        // 140
        SET,   0x0A,       IR2,        // 143
        SUBR,  IR1,        IR2,        // 146
        SET,   0xEE,       IR1,        // 149
        MUL,   0xEE,       IR0, IR1,   // 153
        SET,   0xEE,       IR0,        // 156
        SET,   0xEE,       IR2,        // 159
        MULR,  IR0,        IR1, IR2,   // 163
        SET,   0x0A,       IR0,        // 166
        DIV,   0x06,       IR0, IR1,   // 170
        SET,   0x06,       IR0,        // 173
        SET,   0x0A,       IR1,        // 176
        DIVR,  IR0,        IR1, IR2,   // 180
        SET,   0x01,       IR0,        // 183
        SHL,   0x07,       IR0,        // 186
        SHL,   0x01,       IR0,        // 189
        SET,   0x80,       IR0,        // 192
        SHR,   0x07,       IR0,        // 195
        SHR,   0x01,       IR0,        // 198
        JMP,   0xAB, 0xCD,             // 201
        RET};                          // 202

    for (uint16_t i = 0; i < 202; i++)
    {
        mem[i] = test_code[i];
    }
}

/**
 *
 * Starts the code until it reaches halt instruction or end of code memory.
 *
 */
int main()
{
    init_machine();
    load_test_code();
    run();
    return 0;
}

