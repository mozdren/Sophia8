%{

#include "definitions.h"

%}

%token TDECIMAL TBINARY THEXADECIMAL TEOL TCOMMENT TCOMMA TLOAD TSTORE TSTORER 
%token TSET TINC TDEC TJMP TCMP TCMPR TJZ TJNZ TJC TJNC TADD TADDR TPUSH TPOP
%token TCALL TRET TSUB TSUBR TMUL TMULR TDIV TDIVR TSHL TSHR THALT TNOP TR0 TR1
%token TR2 TR3 TR4 TR5 TR6 TR7 TIP TSP TBP TC TCOLON TLABEL

%%

program:
    | command '\n' program
    ;

command:
    TLOAD number ',' register
    |
    TSTORE register ',' number
    |
    TSTORER register ',' register ',' register
    |
    TSET number ',' register
    |
    TINC register
    |
    TDEC register
    |
    TJMP number
    |
    TCMP register ',' number
    |
    TCMPR register ',' register
    |
    TJZ register ',' number
    |
    TJNZ register ',' number
    |
    TJC number
    |
    TJNC number
    |
    TADD number ',' register
    |
    TADDR register ',' register
    |
    TPUSH allregisters
    |
    TPOP allregisters
    |
    TCALL number
    |
    TRET
    |
    TSUB number ',' register
    |
    TSUBR register ',' register
    |
    TMUL number ',' register ',' register
    |
    TMULR register ',' register ',' register
    |
    TDIV number ',' register ',' register
    |
    TDIVR number ',' register ',' register
    |
    TSHL number ',' register
    |
    TSHR number ',' register
    |
    THALT
    |
    TNOP
    ;

number:
    TDECIMAL { $$ = $1; }
    |
    TBINARY  { $$ = $1; }
    |
    THEXADECIMAL { $$ = $1; }
    ;

register:
    TR0 { $$ = IR0; }
    |
    TR1 { $$ = IR1; }
    |
    TR2 { $$ = IR2; }
    |
    TR3 { $$ = IR3; }
    |
    TR4 { $$ = IR4; }
    |
    TR5 { $$ = IR5; }
    |
    TR6 { $$ = IR6; }
    |
    TR7 { $$ = IR7; }
    ;

allregisters:
    register
    |
    TSP { $$ = ISP; }
    |
    TBP { $$ = IBP; }
    |
    TIP { $$ = IIP; }
    ;

%%