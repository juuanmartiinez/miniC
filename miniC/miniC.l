%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "miniC.tab.h"

#define LEN_MAX 32
#define NUM_MAX "2147483648"

void error_lexico(const char *mensaje);
int comprueba_identificador();
int comprueba_entero();
char *copia_lexema(const char *s);
int hay_error_lexico = 0;
%}

%option yylineno
%option noyywrap
%option noinput
%option nounput

%x COMENTARIO
%x PANICO

digito        [0-9]
letra         [a-zA-Z]
identificador ({letra}|_)({letra}|{digito}|_)*
entero        {digito}+
cadena        \"([^\"\\\n\r]|\\[\"tnr])*\"

%%

[ \t\n\r]+                         ;

"//"[^\n]*                         ;

"/*"                               BEGIN(COMENTARIO);
<COMENTARIO>"*/"                   BEGIN(INITIAL);
<COMENTARIO>[^*\n]+                ;
<COMENTARIO>"*"                    ;
<COMENTARIO>\n                     ;
<COMENTARIO><<EOF>>                { error_lexico("comentario multilinea sin cerrar"); yyterminate(); }

"void"                              return VOID;
"var"                               return VAR;
"const"                             return CONST;
"int"                               return INT;
"if"                                return IF;
"else"                              return ELSE;
"while"                             return WHILE;
"do"                                return DO;
"print"                             return PRINT;
"read"                              return READ;

{identificador}                     return comprueba_identificador();
{entero}                            return comprueba_entero();
{cadena}                            { yylval.cadena = copia_lexema(yytext); return STRING; }

{digito}+({letra}|_)+({letra}|{digito}|_)*  { error_lexico("identificador no valido: no puede comenzar por digito"); BEGIN(PANICO); }

\"([^\"\\\n\r]|\\.)*              { error_lexico("cadena sin cerrar"); BEGIN(PANICO); }

";"                                 return PUNTOCOMA;
","                                 return COMA;
"+"                                 return SUMA;
"-"                                 return RESTA;
"*"                                 return MULTI;
"/"                                 return DIV;
"<="                                return MENORIGUAL;
">="                                return MAYORIGUAL;
"=="                                return IGUALDAD;
"!="                                return DISTINTO;
"<"                                 return MENOR;
">"                                 return MAYOR;
"="                                 return IGUAL;
"("                                 return LPAREN;
")"                                 return RPAREN;
"{"                                 return LCORCHETE;
"}"                                 return RCORCHETE;

.                                    { error_lexico("simbolo no reconocido"); BEGIN(PANICO); }

<PANICO>[ \t\n\r]+                 BEGIN(INITIAL);
<PANICO>"//"[^\n]*                 BEGIN(INITIAL);
<PANICO>"/*"                       BEGIN(COMENTARIO);
<PANICO>[a-zA-Z_0-9\";,\+\-\*/=(){}<>!] { yyless(0); BEGIN(INITIAL); }
<PANICO>.                           ;
<PANICO><<EOF>>                    yyterminate();

%%

char *copia_lexema(const char *s)
{
    char *copia;
    if (s == NULL) return NULL;
    copia = malloc(strlen(s) + 1);
    if (copia == NULL) {
        fprintf(stderr, "ERROR: memoria insuficiente\n");
        exit(1);
    }
    strcpy(copia, s);
    return copia;
}

void error_lexico(const char *mensaje)
{
    fprintf(stderr, "ERROR LEXICO en linea %d: %s provocado por '%s'\n", yylineno, mensaje, yytext);
    hay_error_lexico = 1;
}

int comprueba_identificador()
{
    yylval.cadena = copia_lexema(yytext);

    if (yyleng > LEN_MAX) {
        error_lexico("identificador con mas de 32 caracteres");
    }

    return ID;
}

int comprueba_entero()
{
    char *inicio = yytext;
    int len;
    int max_len = strlen(NUM_MAX);

    while (*inicio == '0' && *(inicio + 1) != '\0') {
        inicio++;
    }

    len = strlen(inicio);
    yylval.cadena = copia_lexema(yytext);

    if (!(len < max_len || (len == max_len && strcmp(inicio, NUM_MAX) <= 0))) {
        error_lexico("entero fuera de rango");
    }

    return NUM;
}
