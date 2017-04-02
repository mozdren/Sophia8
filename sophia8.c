/*****************************************************************************/
/*                                                                           */
/* Project: Sophia8 - an 8 bit virtual machine                               */
/* Author:  Karel Mozdren                                                    */
/* File:    sophia8.c                                                        */
/* Date:    30.03.2017                                                       */
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

#include <stdio.h>
#include <stdint.h>

/* GENERAL CONSTANTS *********************************************************/

#define MEM_SIZE 0xFFFF         /* memory size                               */

/* REGISTERS *****************************************************************/

/* registers */

static uint8_t  r[8];           /* general purpose registers                 */
static uint16_t ip;             /* instruction pointer                       */
static uint16_t sp;             /* stack pointer                             */
static uint16_t bp;             /* stack frame pointer                       */

/* flags registers */

static uint8_t  c;              /* carry flag                                */

/* INSTRUCTIONS **************************************************************/

#define LOAD    0x01            /* loads memory to register             A    */
#define STORE   0x02            /* stores register to memory            A    */
#define STORER  0x03            /* sto. reg. val. to mem. def in regs   N    */
#define SET     0x04            /* sets register to value               A    */
#define INC     0x05            /* increases register by 1              A    */
#define DEC     0x06            /* decreases register by 1              A    */
#define JMP     0x07            /* jumps to location                    A    */
#define CMP     0x08            /* compares register to value           N    */
#define CMPR    0x09            /* compares register to register        N    */
#define JZ      0x0A            /* jump if reg set to zero              N    */
#define JNZ     0x0B            /* jump if reg not set to zero          N    */
#define JC      0x0C            /* jump if carry is set                 N    */
#define JNC     0x0D            /* jump if carry is not set             N    */
#define ADD     0x0E            /* adds value to register               N    */
#define ADDR    0x0F            /* adds register to register            N    */
#define PUSH    0x10            /* pushes register to stack             A    */
#define POP     0x11            /* pops from stack to register          A    */
#define CLR     0x12            /* clears register                      N    */
#define CALL    0x13            /* calls procedure                      N    */
#define RET     0x14            /* returns from the procedure           N    */

/* special instructions */

#define HALT    0x00            /* no operation                              */
#define NOP     0xFF            /* stops/exits the virtual machine           */

/* REGISTERS CODES ***********************************************************/

#define IR0     0x00            /* R0                                        */
#define IR1     0x01            /* .                                         */
#define IR2     0x02            /* .                                         */
#define IR3     0x03            /* .                                         */
#define IR4     0x04            /* .                                         */
#define IR5     0x05            /* .                                         */
#define IR6     0x06            /* .                                         */
#define IR7     0x07            /* R7 general purpose regs indexes           */
#define IIP     0x08            /* instruction pointer register index        */
#define ISP     0x09            /* stack pointer register index              */
#define IBP     0x0A            /* block pointer register index              */
#define IC      0x0B            /* carry flag register index                 */
#define IZ      0x0C            /* zero flag register index                  */

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
void initMachine()
{
    uint16_t i;

    /* clean all memory */
    for (i=0; i<MEM_SIZE; i++)
    {
        mem[i] = HALT;
    }

    /* initialize registers */
    ip = 0;
    sp = MEM_SIZE;
    bp = MEM_SIZE;
    c = 0;

    for (i=0; i<8; i++)
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
void loadInstruction()
{
    static uint16_t memorySource;
    static uint8_t destination;
    static uint8_t value;

    memorySource = (uint16_t)mem[ip + 1];
    memorySource <<= 8;
    memorySource += (uint16_t)mem[ip + 2];

    value = mem[memorySource];

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
void storeInstruction()
{
    static uint16_t memoryDestination;
    static uint8_t source;
    static uint8_t value;

    source = mem[ip + 1]; 

    memoryDestination = (uint16_t)mem[ip + 2];
    memoryDestination <<= 8;
    memoryDestination += (uint16_t)mem[ip + 3];

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
    
    mem[memoryDestination] = value;

    ip += 4;
}

/**
 * Processing a set instruction. This instruction stores imidiate value to a
 * specific register.
 * 
 * SET 0x1A, R0 -> 03 1A 00
 */
void setInstruction()
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
void pushInstruction()
{
    static uint8_t source;
    static uint8_t value;

    sp--;
    value = 0;

    source = mem[ip+1];

    if (source == IIP)
    {
        value = (uint8_t)(ip & 0x00FF);
        mem[sp] = value;
        value = (uint8_t)((ip & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }
    else if (source == ISP)
    {
        value = (uint8_t)(sp & 0x00FF);
        mem[sp] = value;
        value = (uint8_t)((sp & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }
    else if (source == IBP)
    {
        value = (uint8_t)(bp & 0x00FF);
        mem[sp] = value;
        value = (uint8_t)((bp & 0xFF00) >> 8);
        mem[sp-1] = value;
        sp--;
        ip += 2;
        return;
    }
    else
    {
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
void popInstruction()
{
    static uint8_t source;
    static uint16_t value;

    value = 0;

    source = mem[ip+1];

    if (source == IIP)
    {
        value = ((uint16_t)(mem[sp]) << 8) + (uint16_t)(mem[sp + 1]);
        ip = value;
        sp += 2;
        ip += 2;
        return;
    }
    else if (source == ISP)
    {
        value = ((uint16_t)(mem[sp]) << 8) + (uint16_t)(mem[sp + 1]);
        sp = value;
        sp += 2;
        ip += 2;
        return;
    }
    else if (source == IBP)
    {
        value = ((uint16_t)(mem[sp]) << 8) + (uint16_t)(mem[sp + 1]);
        bp = value;
        sp += 2;
        ip += 2;
        return;
    }
    else
    {
        value = (uint16_t)mem[sp];

        switch (source) 
        {
            case IR0: r[0] = (uint8_t)value; break;
            case IR1: r[1] = (uint8_t)value; break;
            case IR2: r[2] = (uint8_t)value; break;
            case IR3: r[3] = (uint8_t)value; break;
            case IR4: r[4] = (uint8_t)value; break;
            case IR5: r[5] = (uint8_t)value; break;
            case IR6: r[6] = (uint8_t)value; break;
            case IR7: r[7] = (uint8_t)value; break;
            default: STOP = 1; break;
        }
    }

    sp++;
    ip+= 2;
}

/*
 *
 * Increase Instruction. Increases register value by 1.
 *
 */
void incInstruction()
{
    uint8_t what;
    
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
void decInstruction()
{
    uint8_t what;
    
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
void jmpInstruction()
{
    uint16_t jumpAddress;

    jumpAddress = ((uint16_t)mem[ip + 1]) << 8;
    jumpAddress += (uint16_t)mem[ip + 2];

    ip = jumpAddress;
}

/**
 *
 * Processes instruction. If unknown instruction or halt, then the VM stops.
 *
 */
void processInstruction()
{
    switch (mem[ip])
    {
        case LOAD: loadInstruction(); break;
        case STORE: storeInstruction(); break;
        case SET: setInstruction(); break;
        case PUSH: pushInstruction(); break;
        case POP: popInstruction(); break;
        case INC: incInstruction(); break;
        case DEC: decInstruction(); break;
        case JMP: jmpInstruction(); break;
        default: STOP = 1; break;
    }
}

/**
 *
 * Prints Memory
 *
 */
void printMemory()
{
    uint16_t i;

    for (i = 0; i<MEM_SIZE; i++)
    {
        if (i % 64 == 0)
        {
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
void printRegisters()
{
    uint8_t i;
    for (i=0;i<8;i++)
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
        processInstruction();
    }

    printMemory();
    printRegisters();
}

void loadTestCode()
{
    uint8_t testCode[80] =
        {SET,   0x0A,       IR0,        // 3
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
         JMP,   0xAB, 0xCD};            // 80

    uint16_t i;

    for (i=0; i<80; i++)
    {
        mem[i] = testCode[i];
    }
}

/**
 *
 * Starts the code until it reaches halt instruction or end of code memory.
 *
 */
int main(int argc, char **argv)
{
    initMachine();
    loadTestCode();
    run();
    return 0;
}

