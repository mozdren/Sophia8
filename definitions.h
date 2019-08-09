#ifndef __DEFINITIONS_H_
#define __DEFINITIONS_H_

/* GENERAL CONSTANTS *********************************************************/

#define MEM_SIZE 0xFFFF         /* memory size                               */

/* INSTRUCTIONS **************************************************************/

#define LOAD    0x01            /* loads memory to register             A    */
#define STORE   0x02            /* stores register to memory            A    */
#define STORER  0x03            /* sto. reg. val. to mem. def in regs   A    */
#define SET     0x04            /* sets register to value               A    */
#define INC     0x05            /* increases register by 1              A    */
#define DEC     0x06            /* decreases register by 1              A    */
#define JMP     0x07            /* jumps to location                    A    */
#define CMP     0x08            /* compares register to value           A    */
#define CMPR    0x09            /* compares register to register        A    */
#define JZ      0x0A            /* jump if reg set to zero              A    */
#define JNZ     0x0B            /* jump if reg not set to zero          A    */
#define JC      0x0C            /* jump if carry is set                 A    */
#define JNC     0x0D            /* jump if carry is not set             A    */
#define ADD     0x0E            /* adds value to register               A    */
#define ADDR    0x0F            /* adds register to register            A    */
#define PUSH    0x10            /* pushes register to stack             A    */
#define POP     0x11            /* pops from stack to register          A    */
#define CALL    0x12            /* calls procedure                      A    */
#define RET     0x13            /* returns from the procedure           A    */
#define SUB     0x14            /* subtracts value from register        A    */
#define SUBR    0x15            /* subtracts register from register     A    */
#define MUL     0x16            /* multiplies register by value         A    */
#define MULR    0x17            /* multiplies register by register      A    */
#define DIV     0x18            /* divides register by value            A    */
#define DIVR    0x19            /* divides register by register         A    */
#define SHL     0x1A            /* shifts register to the left          A    */
#define SHR     0x1B            /* shifts register to the right         A    */

/* special instructions */

#define HALT    0x00            /* no operation                         A    */
#define NOP     0xFF            /* stops/exits the virtual machine      A    */

/* INSTRUCTIONS LENGTHS ******************************************************/

#define LOAD_LEN    4 
#define STORE_LEN   4
#define STORER_LEN  4
#define SET_LEN     3
#define INC_LEN     2
#define DEC_LEN     2
#define JMP_LEN     3
#define CMP_LEN     3
#define CMPR_LEN    3
#define JZ_LEN      4
#define JNZ_LEN     4
#define JC_LEN      3
#define JNC_LEN     3
#define ADD_LEN     3
#define ADDR_LEN    3
#define PUSH_LEN    2
#define POP_LEN     2
#define CALL_LEN    3
#define RET_LEN     1
#define SUB_LEN     3
#define SUBR_LEN    3
#define MUL_LEN     4
#define MULR_LEN    4
#define DIV_LEN     4
#define DIVR_LEN    4
#define SHL_LEN     3
#define SHR_LEN     3

/* special instructions */

#define HALT_LEN    1
#define NOP_LEN     1

/* REGISTERS CODES ***********************************************************/

#define IR0     0xF2            /* R0                                        */
#define IR1     0xF3            /* .                                         */
#define IR2     0xF4            /* .                                         */
#define IR3     0xF5            /* .                                         */
#define IR4     0xF6            /* .                                         */
#define IR5     0xF7            /* .                                         */
#define IR6     0xF8            /* .                                         */
#define IR7     0xF9            /* R7 general purpose regs indexes           */
#define IIP     0xFA            /* instruction pointer register index        */
#define ISP     0xFB            /* stack pointer register index              */
#define IBP     0xFC            /* block pointer register index              */
#define IC      0xFE            /* carry flag register index                 */

/* LEXER VALUES **************************************************************/

#define LEX_END_OF_LINE     0xFFFF0001
#define LEX_HEX_NUMBER      0xFFFF0002
#define LEX_DEC_NUMBER      0xFFFF0003
#define LEX_BIN_NUMBER      0xFFFF0004
#define LEX_COLON           0xFFFF0005
#define LEX_LABEL           0xFFFF0006
#define LEX_COMMENT         0xFFFF0007
#define LEX_COMMA           0xFFFF0008

/* MEMORY MAPPINGS ***********************************************************/

#define VIDEO_MEM_ADDRESS 0xC000
#define COLOR_MEM_ADDRESS 0xDF40
#define CONSOLE_X_ADDRESS 0xE000
#define CONSOLE_Y_ADDRESS 0xE001
#define CURSOR_ON_ADDRESS 0xE002
#define VIDEO_MODE_ADDRESS 0xE003
#define KEY_BUF_SIZE_ADDRESS 0xE004
#define KEY_BUFFER_ADDRESS 0xE005
#define CHAR_MEM_ADDRESS 0xE069

#endif