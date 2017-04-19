main: sophia8.c definitions.h assembler.lex
	gcc -g sophia8.c -o sophia8
	flex assembler.lex
	gcc -g lex.yy.c -o lexer

debug:
	gdb sophia8

clean:
	rm sophia8
