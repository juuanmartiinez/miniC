void main() {
    var int i = 0, suma = 0;

    do {
        i = i + 1;
        if (i == 3) print("tres\n");
        suma = suma + i;
    } while (i < 5);

    print("i = ", i, "\n");
    print("suma = ", suma, "\n");
}
