minic: miniC.tab.c lex.yy.c listaSimbolos.c listaCodigo.c
	gcc -Wall -Wextra -g lex.yy.c miniC.tab.c listaSimbolos.c listaCodigo.c -lfl -o minic

miniC.tab.c miniC.tab.h: miniC.y listaSimbolos.h listaCodigo.h
	bison -d -v miniC.y

lex.yy.c: miniC.l miniC.tab.h
	flex miniC.l

clean:
	rm -f lex.yy.c miniC.tab.c miniC.tab.h miniC.output minic *.s
