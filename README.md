Tarea final - Ejecucion y evaluacion del codigo generado
========================================================

Compilar:
    make clean
    make

Generar codigo MIPS:
    ./minic ficheros_de_prueba/correcto_basico.mc > correcto_basico.s

Ejecutar en SPIM:
    spim -file correcto_basico.s


Pruebas recomendadas
--------------------

1) Programa basico:
    ./minic ficheros_de_prueba/correcto_basico.mc > correcto_basico.s
    spim -file correcto_basico.s

2) Aritmetica:
    ./minic ficheros_de_prueba/correcto_aritmetica.mc > correcto_aritmetica.s
    spim -file correcto_aritmetica.s

3) Lectura:
    ./minic ficheros_de_prueba/correcto_read.mc > correcto_read.s
    spim -file correcto_read.s

    Durante la ejecucion, introducir por teclado:
    7

4) Mejoras opcionales:
    ./minic ficheros_de_prueba/correcto_mejoras.mc > correcto_mejoras.s
    spim -file correcto_mejoras.s

    ./minic ficheros_de_prueba/correcto_relacionales.mc > correcto_relacionales.s
    spim -file correcto_relacionales.s


Salidas esperadas
-----------------

Salida esperada de correcto_mejoras.mc:
    tres
    i = 5
    suma = 15

Salida esperada de correcto_relacionales.mc:
    <
    >
    <=
    >=
    ==
    !=


Notas
-----

Los ficheros .mc son programas fuente escritos en miniC.

Los ficheros .s son los programas ensamblador MIPS generados por el compilador.

Si se quiere limpiar el proyecto y borrar los ficheros generados:
    make clean
