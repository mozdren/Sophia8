main: sophia8.c
	gcc -g sophia8.c -o sophia8

debug:
	gdb sophia8

clean:
	rm sophia8
