%code requires {
#include "listaCodigo.h"
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "listaSimbolos.h"
#include "listaCodigo.h"

int yylex();
void yyerror(const char *s);

extern FILE *yyin;
extern int yylineno;
extern char *yytext;
extern int hay_error_lexico;

int hay_error_sintactico = 0;
int hay_error_semantico = 0;
static int tablaLiberada = 0;

static Lista tablaSimbolos;
static Tipo tipoDeclaracionActual;
static int contadorCadenas = 1;
static int contadorEtiquetas = 1;
static int registrosUsados[10] = {0};

static char *copia_cadena(const char *s);
static char *formato(const char *fmt, ...);
static ListaC lista_vacia();
static void emite(ListaC codigo, const char *op, const char *res, const char *arg1, const char *arg2);
static ListaC concatena_codigo(ListaC a, ListaC b);
static char *nuevo_registro();
static void libera_registro(const char *reg);
static char *nueva_etiqueta();
static char *etiqueta_variable(const char *id);
static char *inserta_cadena_tabla(const char *literal);
static int simbolo_existe(const char *nombre);
static Simbolo recupera_simbolo(const char *nombre);
static void inserta_variable_constante(const char *nombre, Tipo tipo);
static void error_semantico(const char *fmt, ...);
static ListaC codigo_cargar_entero(const char *num);
static ListaC codigo_cargar_variable(const char *id);
static ListaC codigo_guardar_variable(const char *id, ListaC expr);
static ListaC codigo_print_entero(ListaC expr);
static ListaC codigo_print_cadena(const char *literal);
static ListaC codigo_read_id(const char *id);
static ListaC codigo_binario(ListaC izq, const char *op, ListaC der);
static ListaC codigo_relacional(ListaC izq, const char *op, ListaC der);
static ListaC codigo_unario_menos(ListaC expr);
static void imprimir_datos();
static void imprimir_codigo(ListaC codigo);
static void imprimir_operacion(Operacion o);
%}

%define parse.error verbose

%union {
    char *cadena;
    ListaC codigo;
}

%token VOID VAR CONST INT IF ELSE WHILE DO PRINT READ
%token <cadena> ID NUM STRING
%token PUNTOCOMA COMA SUMA RESTA MULTI DIV IGUAL LPAREN RPAREN LCORCHETE RCORCHETE
%token MENOR MAYOR MENORIGUAL MAYORIGUAL IGUALDAD DISTINTO

%type <codigo> body declaration id_list id_decl statement statement_list print_list print_item read_list expression

%nonassoc MENOR MAYOR MENORIGUAL MAYORIGUAL IGUALDAD DISTINTO
%left SUMA RESTA
%left MULTI DIV
%right MENOS_UNARIO
%nonassoc IF_SIN_ELSE
%nonassoc ELSE

%start program

%%

program
    : VOID ID LPAREN RPAREN LCORCHETE body RCORCHETE
      {
          if (strcmp($2, "main") != 0) {
              error_semantico("el identificador del programa debe ser main y se ha encontrado '%s'", $2);
          }

          if (!hay_error_lexico && !hay_error_sintactico && !hay_error_semantico) {
              imprimir_datos();
              imprimir_codigo($6);
          }

          liberaLC($6);
          liberaLS(tablaSimbolos);
          tablaLiberada = 1;
          free($2);
      }
    ;

body
    : body declaration
      { $$ = concatena_codigo($1, $2); }
    | body statement
      { $$ = concatena_codigo($1, $2); }
    | body error PUNTOCOMA
      {
          $$ = $1;
          yyerrok;
      }
    | /* empty */
      { $$ = lista_vacia(); }
    ;

declaration
    : VAR tipo { tipoDeclaracionActual = VARIABLE; } id_list PUNTOCOMA
      { $$ = $4; }
    | CONST tipo { tipoDeclaracionActual = CONSTANTE; } id_list PUNTOCOMA
      { $$ = $4; }
    ;

tipo
    : INT
    ;

id_list
    : id_decl
      { $$ = $1; }
    | id_list COMA id_decl
      { $$ = concatena_codigo($1, $3); }
    ;

id_decl
    : ID
      {
          inserta_variable_constante($1, tipoDeclaracionActual);
          $$ = lista_vacia();
          free($1);
      }
    | ID IGUAL expression
      {
          int redeclarado = simbolo_existe($1);
          inserta_variable_constante($1, tipoDeclaracionActual);
          if (!redeclarado) {
              char *mem = etiqueta_variable($1);
              char *reg = recuperaResLC($3);
              emite($3, "sw", mem, reg, NULL);
              libera_registro(reg);
              free(mem);
          } else {
              libera_registro(recuperaResLC($3));
          }
          $$ = $3;
          free($1);
      }
    ;

statement
    : ID IGUAL expression PUNTOCOMA
      {
          $$ = codigo_guardar_variable($1, $3);
          free($1);
      }
    | LCORCHETE statement_list RCORCHETE
      { $$ = $2; }
    | IF LPAREN expression RPAREN statement ELSE statement
      {
          char *lelse = nueva_etiqueta();
          char *lfin = nueva_etiqueta();
          char *reg = recuperaResLC($3);

          emite($3, "beqz", lelse, reg, NULL);
          libera_registro(reg);
          concatenaLC($3, $5);
          emite($3, "b", lfin, NULL, NULL);
          emite($3, "label", lelse, NULL, NULL);
          concatenaLC($3, $7);
          emite($3, "label", lfin, NULL, NULL);

          liberaLC($5);
          liberaLC($7);
          free(lelse);
          free(lfin);
          $$ = $3;
      }
    | IF LPAREN expression RPAREN statement %prec IF_SIN_ELSE
      {
          char *lfin = nueva_etiqueta();
          char *reg = recuperaResLC($3);

          emite($3, "beqz", lfin, reg, NULL);
          libera_registro(reg);
          concatenaLC($3, $5);
          emite($3, "label", lfin, NULL, NULL);

          liberaLC($5);
          free(lfin);
          $$ = $3;
      }
    | WHILE LPAREN expression RPAREN statement
      {
          char *linicio = nueva_etiqueta();
          char *lfin = nueva_etiqueta();
          char *reg = recuperaResLC($3);
          ListaC codigo = lista_vacia();

          emite(codigo, "label", linicio, NULL, NULL);
          concatenaLC(codigo, $3);
          emite(codigo, "beqz", lfin, reg, NULL);
          libera_registro(reg);
          concatenaLC(codigo, $5);
          emite(codigo, "b", linicio, NULL, NULL);
          emite(codigo, "label", lfin, NULL, NULL);

          liberaLC($3);
          liberaLC($5);
          free(linicio);
          free(lfin);
          $$ = codigo;
      }
    | DO statement WHILE LPAREN expression RPAREN PUNTOCOMA
      {
          char *linicio = nueva_etiqueta();
          char *reg = recuperaResLC($5);
          ListaC codigo = lista_vacia();

          emite(codigo, "label", linicio, NULL, NULL);
          concatenaLC(codigo, $2);
          concatenaLC(codigo, $5);
          emite(codigo, "bnez", linicio, reg, NULL);
          libera_registro(reg);

          liberaLC($2);
          liberaLC($5);
          free(linicio);
          $$ = codigo;
      }
    | PRINT LPAREN print_list RPAREN PUNTOCOMA
      { $$ = $3; }
    | READ LPAREN read_list RPAREN PUNTOCOMA
      { $$ = $3; }
    ;

statement_list
    : statement_list statement
      { $$ = concatena_codigo($1, $2); }
    | statement_list error PUNTOCOMA
      {
          $$ = $1;
          yyerrok;
      }
    | /* empty */
      { $$ = lista_vacia(); }
    ;

print_list
    : print_item
      { $$ = $1; }
    | print_list COMA print_item
      { $$ = concatena_codigo($1, $3); }
    ;

print_item
    : expression
      { $$ = codigo_print_entero($1); }
    | STRING
      {
          $$ = codigo_print_cadena($1);
          free($1);
      }
    ;

read_list
    : ID
      {
          $$ = codigo_read_id($1);
          free($1);
      }
    | read_list COMA ID
      {
          ListaC codigo = codigo_read_id($3);
          $$ = concatena_codigo($1, codigo);
          free($3);
      }
    ;

expression
    : expression MENOR expression
      { $$ = codigo_relacional($1, "slt", $3); }
    | expression MAYOR expression
      { $$ = codigo_relacional($1, "sgt", $3); }
    | expression MENORIGUAL expression
      { $$ = codigo_relacional($1, "sle", $3); }
    | expression MAYORIGUAL expression
      { $$ = codigo_relacional($1, "sge", $3); }
    | expression IGUALDAD expression
      { $$ = codigo_relacional($1, "seq", $3); }
    | expression DISTINTO expression
      { $$ = codigo_relacional($1, "sne", $3); }
    | expression SUMA expression
      { $$ = codigo_binario($1, "add", $3); }
    | expression RESTA expression
      { $$ = codigo_binario($1, "sub", $3); }
    | expression MULTI expression
      { $$ = codigo_binario($1, "mul", $3); }
    | expression DIV expression
      { $$ = codigo_binario($1, "div", $3); }
    | RESTA expression %prec MENOS_UNARIO
      { $$ = codigo_unario_menos($2); }
    | LPAREN expression RPAREN
      { $$ = $2; }
    | ID
      {
          $$ = codigo_cargar_variable($1);
          free($1);
      }
    | NUM
      {
          $$ = codigo_cargar_entero($1);
          free($1);
      }
    ;

%%

void yyerror(const char *s)
{
    if (yytext != NULL &&
        (!strcmp(yytext, "print") || !strcmp(yytext, "read") ||
         !strcmp(yytext, "if") || !strcmp(yytext, "while") ||
         !strcmp(yytext, "do") ||
         !strcmp(yytext, "var") || !strcmp(yytext, "const") ||
         !strcmp(yytext, "}"))) {
        fprintf(stderr,
                "ERROR SINTACTICO en linea %d cerca de '%s': probablemente falta ';' al final de la sentencia o declaracion anterior\n",
                yylineno, yytext);
    } else {
        fprintf(stderr, "ERROR SINTACTICO en linea %d cerca de '%s': %s\n",
                yylineno, yytext ? yytext : "fin de fichero", s);
    }
    hay_error_sintactico = 1;
}

static char *copia_cadena(const char *s)
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

static char *formato(const char *fmt, ...)
{
    va_list ap;
    va_list ap2;
    int n;
    char *res;

    va_start(ap, fmt);
    va_copy(ap2, ap);
    n = vsnprintf(NULL, 0, fmt, ap);
    va_end(ap);

    if (n < 0) {
        va_end(ap2);
        fprintf(stderr, "ERROR: no se pudo formatear cadena\n");
        exit(1);
    }

    res = malloc((size_t)n + 1);
    if (res == NULL) {
        va_end(ap2);
        fprintf(stderr, "ERROR: memoria insuficiente\n");
        exit(1);
    }

    vsnprintf(res, (size_t)n + 1, fmt, ap2);
    va_end(ap2);
    return res;
}

static ListaC lista_vacia()
{
    return creaLC();
}

static void emite(ListaC codigo, const char *op, const char *res, const char *arg1, const char *arg2)
{
    Operacion o;
    o.op = copia_cadena(op);
    o.res = copia_cadena(res);
    o.arg1 = copia_cadena(arg1);
    o.arg2 = copia_cadena(arg2);
    insertaLC(codigo, finalLC(codigo), o);
}

static ListaC concatena_codigo(ListaC a, ListaC b)
{
    concatenaLC(a, b);
    liberaLC(b);
    return a;
}

static char *nuevo_registro()
{
    int i;
    for (i = 0; i < 10; i++) {
        if (!registrosUsados[i]) {
            registrosUsados[i] = 1;
            return formato("$t%d", i);
        }
    }

    error_semantico("expresion demasiado compleja: no quedan registros temporales libres");
    return copia_cadena("$t0");
}

static void libera_registro(const char *reg)
{
    if (reg != NULL && strlen(reg) == 3 && reg[0] == '$' && reg[1] == 't' && reg[2] >= '0' && reg[2] <= '9') {
        registrosUsados[reg[2] - '0'] = 0;
    }
}

static char *nueva_etiqueta()
{
    return formato("$l%d", contadorEtiquetas++);
}

static char *etiqueta_variable(const char *id)
{
    return formato("_%s", id);
}

static char *inserta_cadena_tabla(const char *literal)
{
    Simbolo s;
    int numero = contadorCadenas++;
    s.nombre = copia_cadena(literal);
    s.tipo = CADENA;
    s.valor = numero;
    insertaLS(tablaSimbolos, finalLS(tablaSimbolos), s);
    return formato("$str%d", numero);
}

static int simbolo_existe(const char *nombre)
{
    PosicionLista p = buscaLS(tablaSimbolos, (char *)nombre);
    return p != finalLS(tablaSimbolos);
}

static Simbolo recupera_simbolo(const char *nombre)
{
    PosicionLista p = buscaLS(tablaSimbolos, (char *)nombre);
    if (p == finalLS(tablaSimbolos)) {
        Simbolo s;
        s.nombre = NULL;
        s.tipo = VARIABLE;
        s.valor = 0;
        return s;
    }
    return recuperaLS(tablaSimbolos, p);
}

static void inserta_variable_constante(const char *nombre, Tipo tipo)
{
    Simbolo s;
    if (simbolo_existe(nombre)) {
        error_semantico("identificador '%s' declarado mas de una vez", nombre);
        return;
    }

    s.nombre = copia_cadena(nombre);
    s.tipo = tipo;
    s.valor = 0;
    insertaLS(tablaSimbolos, finalLS(tablaSimbolos), s);
}

static void error_semantico(const char *fmt, ...)
{
    va_list ap;
    fprintf(stderr, "ERROR SEMANTICO en linea %d: ", yylineno);
    va_start(ap, fmt);
    vfprintf(stderr, fmt, ap);
    va_end(ap);
    fprintf(stderr, "\n");
    hay_error_semantico = 1;
}

static ListaC codigo_cargar_entero(const char *num)
{
    ListaC codigo = lista_vacia();
    char *reg = nuevo_registro();
    emite(codigo, "li", reg, num, NULL);
    guardaResLC(codigo, reg);
    return codigo;
}

static ListaC codigo_cargar_variable(const char *id)
{
    ListaC codigo = lista_vacia();
    char *reg = nuevo_registro();

    if (!simbolo_existe(id)) {
        error_semantico("identificador '%s' usado sin haber sido declarado", id);
        emite(codigo, "li", reg, "0", NULL);
    } else {
        char *mem = etiqueta_variable(id);
        emite(codigo, "lw", reg, mem, NULL);
        free(mem);
    }

    guardaResLC(codigo, reg);
    return codigo;
}

static ListaC codigo_guardar_variable(const char *id, ListaC expr)
{
    if (!simbolo_existe(id)) {
        error_semantico("identificador '%s' usado sin haber sido declarado", id);
    } else {
        Simbolo s = recupera_simbolo(id);
        if (s.tipo == CONSTANTE) {
            error_semantico("no se puede asignar un nuevo valor a la constante '%s'", id);
        } else {
            char *mem = etiqueta_variable(id);
            char *reg = recuperaResLC(expr);
            emite(expr, "sw", mem, reg, NULL);
            free(mem);
        }
    }

    libera_registro(recuperaResLC(expr));
    return expr;
}

static ListaC codigo_print_entero(ListaC expr)
{
    char *reg = recuperaResLC(expr);
    emite(expr, "move", "$a0", reg, NULL);
    emite(expr, "li", "$v0", "1", NULL);
    emite(expr, "syscall", NULL, NULL, NULL);
    libera_registro(reg);
    return expr;
}

static ListaC codigo_print_cadena(const char *literal)
{
    ListaC codigo = lista_vacia();
    char *label = inserta_cadena_tabla(literal);
    emite(codigo, "la", "$a0", label, NULL);
    emite(codigo, "li", "$v0", "4", NULL);
    emite(codigo, "syscall", NULL, NULL, NULL);
    free(label);
    return codigo;
}

static ListaC codigo_read_id(const char *id)
{
    ListaC codigo = lista_vacia();

    if (!simbolo_existe(id)) {
        error_semantico("identificador '%s' usado sin haber sido declarado", id);
    } else {
        Simbolo s = recupera_simbolo(id);
        if (s.tipo == CONSTANTE) {
            error_semantico("no se puede leer sobre la constante '%s'", id);
        } else {
            char *mem = etiqueta_variable(id);
            emite(codigo, "li", "$v0", "5", NULL);
            emite(codigo, "syscall", NULL, NULL, NULL);
            emite(codigo, "sw", mem, "$v0", NULL);
            free(mem);
        }
    }

    return codigo;
}

static ListaC codigo_binario(ListaC izq, const char *op, ListaC der)
{
    char *regIzq = recuperaResLC(izq);
    char *regDer = recuperaResLC(der);

    concatenaLC(izq, der);
    emite(izq, op, regIzq, regIzq, regDer);
    libera_registro(regDer);
    guardaResLC(izq, regIzq);
    liberaLC(der);
    return izq;
}

static ListaC codigo_relacional(ListaC izq, const char *op, ListaC der)
{
    char *regIzq = recuperaResLC(izq);
    char *regDer = recuperaResLC(der);

    concatenaLC(izq, der);
    emite(izq, op, regIzq, regIzq, regDer);
    libera_registro(regDer);
    guardaResLC(izq, regIzq);
    liberaLC(der);
    return izq;
}

static ListaC codigo_unario_menos(ListaC expr)
{
    char *reg = recuperaResLC(expr);
    emite(expr, "neg", reg, reg, NULL);
    guardaResLC(expr, reg);
    return expr;
}

static void imprimir_datos()
{
    PosicionLista p;
    int hayCadenas = 0;
    int hayVariables = 0;

    printf("##################\n");
    printf("# Seccion de datos\n");
    printf(".data\n\n");

    for (p = inicioLS(tablaSimbolos); p != finalLS(tablaSimbolos); p = siguienteLS(tablaSimbolos, p)) {
        Simbolo s = recuperaLS(tablaSimbolos, p);
        if (s.tipo == CADENA) {
            if (!hayCadenas) {
                printf("# Cadenas del programa\n");
                hayCadenas = 1;
            }
            printf("$str%d:\n", s.valor);
            printf("\t.asciiz %s\n", s.nombre);
        }
    }

    if (hayCadenas) printf("\n");

    for (p = inicioLS(tablaSimbolos); p != finalLS(tablaSimbolos); p = siguienteLS(tablaSimbolos, p)) {
        Simbolo s = recuperaLS(tablaSimbolos, p);
        if (s.tipo == VARIABLE || s.tipo == CONSTANTE) {
            if (!hayVariables) {
                printf("# Variables y constantes\n");
                hayVariables = 1;
            }
            printf("_%s:\n", s.nombre);
            printf("\t.word 0\n");
        }
    }

    printf("\n");
}

static void imprimir_codigo(ListaC codigo)
{
    PosicionListaC p;

    printf("###################\n");
    printf("# Seccion de codigo\n");
    printf(".text\n");
    printf(".globl main\n");
    printf("main:\n");

    for (p = inicioLC(codigo); p != finalLC(codigo); p = siguienteLC(codigo, p)) {
        imprimir_operacion(recuperaLC(codigo, p));
    }

    printf("\n##############\n");
    printf("# Fin\n");
    printf("\tli $v0, 10\n");
    printf("\tsyscall\n");
}

static void imprimir_operacion(Operacion o)
{
    if (o.op == NULL) return;

    if (!strcmp(o.op, "label")) {
        printf("%s:\n", o.res);
    } else if (!strcmp(o.op, "syscall")) {
        printf("\tsyscall\n");
    } else if (!strcmp(o.op, "b")) {
        printf("\tb %s\n", o.res);
    } else if (!strcmp(o.op, "beqz") || !strcmp(o.op, "bnez")) {
        printf("\t%s %s, %s\n", o.op, o.arg1, o.res);
    } else if (!strcmp(o.op, "li") || !strcmp(o.op, "lw") || !strcmp(o.op, "la")) {
        printf("\t%s %s, %s\n", o.op, o.res, o.arg1);
    } else if (!strcmp(o.op, "sw")) {
        printf("\tsw %s, %s\n", o.arg1, o.res);
    } else if (!strcmp(o.op, "move") || !strcmp(o.op, "neg")) {
        printf("\t%s %s, %s\n", o.op, o.res, o.arg1);
    } else if (!strcmp(o.op, "add") || !strcmp(o.op, "sub") || !strcmp(o.op, "mul") || !strcmp(o.op, "div") ||
               !strcmp(o.op, "slt") || !strcmp(o.op, "sgt") || !strcmp(o.op, "sle") ||
               !strcmp(o.op, "sge") || !strcmp(o.op, "seq") || !strcmp(o.op, "sne")) {
        printf("\t%s %s, %s, %s\n", o.op, o.res, o.arg1, o.arg2);
    } else {
        fprintf(stderr, "ERROR INTERNO: operacion no reconocida '%s'\n", o.op);
    }
}

int main(int argc, char *argv[])
{
    int resultado;

    tablaSimbolos = creaLS();

    if (argc != 2) {
        fprintf(stderr, "Uso correcto: %s fichero.mc\n", argv[0]);
        liberaLS(tablaSimbolos);
        return 1;
    }

    yyin = fopen(argv[1], "r");
    if (yyin == NULL) {
        fprintf(stderr, "No se puede abrir %s\n", argv[1]);
        liberaLS(tablaSimbolos);
        return 1;
    }

    resultado = yyparse();
    fclose(yyin);

    if (resultado == 0 && !hay_error_lexico && !hay_error_sintactico && !hay_error_semantico) {
        return 0;
    }

    fprintf(stderr, "Analisis terminado con errores\n");
    if (!tablaLiberada) {
        liberaLS(tablaSimbolos);
    }
    return 1;
}
