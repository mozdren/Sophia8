%{

#include <stdio.h>
#include "definitions.h"

%}
%%
0x[0-9A-F]+     {printf("HEX_NUMBER"); return LEX_HEX_NUMBER;}
[1-9]+[0-9]*    {printf("DEC_NUMBER"); return LEX_DEC_NUMBER;}
[01]+b          {printf("BIN_NUMBER"); return LEX_BIN_NUMBER;}
"\n"            {printf("\n"); return LEX_END_OF_LINE;}
;.+             {return LEX_COMMENT;}
","             {printf(","); return LEX_COMMA;}
"LOAD"          {printf("LOAD"); return LOAD;}
"STORE"         {printf("STORE"); return STORE;}
"STORER"        {printf("STORER"); return STORER;}
"SET"           {printf("SET"); return SET;}
"INC"           {printf("INC"); return INC;}
"DEC"           {printf("DEC"); return DEC;}
"JMP"           {printf("JMP"); return JMP;}
"CMP"           {printf("CMP"); return CMP;}
"CMPR"          {printf("CMPR"); return CMPR;}
"JZ"            {printf("JZ"); return JZ;}
"JNZ"           {printf("JNZ"); return JNZ;}
"JC"            {printf("JC"); return JC;}
"JNC"           {printf("JNC"); return JNC;}
"ADD"           {printf("ADD"); return ADD;}
"ADDR"          {printf("ADDR"); return ADDR;}
"PUSH"          {printf("PUSH"); return PUSH;}
"POP"           {printf("POP"); return POP;}
"CALL"          {printf("CALL"); return CALL;}
"RET"           {printf("RET"); return RET;}
"SUB"           {printf("SUB"); return SUB;}
"SUBR"          {printf("SUBR"); return SUBR;}
"MUL"           {printf("MUL"); return MUL;}
"MULR"          {printf("MULR"); return MULR;}
"DIV"           {printf("DIV"); return DIV;}
"DIVR"          {printf("DIVR"); return DIVR;}
"SHL"           {printf("SHL"); return SHL;}
"SHR"           {printf("SHR"); return SHR;}
"HALT"          {printf("HALT"); return HALT;}
"NOP"           {printf("NOP"); return NOP;}
"R0"            {printf("R0"); return IR0;}
"R1"            {printf("R1"); return IR1;}
"R2"            {printf("R2"); return IR2;}
"R3"            {printf("R3"); return IR3;}
"R4"            {printf("R4"); return IR4;}
"R5"            {printf("R5"); return IR5;}
"R6"            {printf("R6"); return IR6;}
"R7"            {printf("R7"); return IR7;}
"IP"            {printf("IP"); return IIP;}
"SP"            {printf("SP"); return ISP;}
"BP"            {printf("BP"); return IBP;}
"C"             {printf("C"); return IC;}
":"             {printf(":"); return LEX_COLON;}
[a-zA-Z]+       {printf("LABEL"); return LEX_LABEL;}
%%

int yywrap(void)
{
    return 1;
}

int main()
{
    yyin = fopen("test.asm", "r");
    int n = yylex();
    while (n != 0)
    {
        n = yylex();
    }
}