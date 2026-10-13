/* Pruebas de las validaciones que usa la carga de turnos de Gestión
 * (nombre, DNI y teléfono). Las de Cliente y las de precio y duración están
 * en tests/test_cliente.cpp. Cada validación tiene casos válidos, inválidos
 * y bordes. Se corre con el ejecutable prueba_validaciones o con `ctest`. */
#include "validaciones.h"

#include <QtTest>

class PruebaValidaciones : public QObject
{
    Q_OBJECT

private slots:
    void nombre_data();
    void nombre();
    void dni_data();
    void dni();
    void telefono_data();
    void telefono();
    void normalizar();
};

/* Cada caso: dato de entrada y si tiene que ser válido. */
void PruebaValidaciones::nombre_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("valido");
    QTest::newRow("nombre y apellido") << "María Sosa" << true;
    QTest::newRow("con apóstrofo y guion") << "Ana O'Neill-Pérez" << true;
    QTest::newRow("espacios en los extremos") << "  Lucía Fernández " << true;
    QTest::newRow("vacío") << "" << false;
    QTest::newRow("solo espacios") << "   " << false;
    QTest::newRow("una letra") << "A" << false;
    QTest::newRow("con números") << "María Sosa 2" << false;
    QTest::newRow("más de 60 caracteres") << QString(61, 'a') << false;
}

void PruebaValidaciones::nombre()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QString error;
    QCOMPARE(Validaciones::nombreValido(entrada, &error), valido);
    QCOMPARE(error.isEmpty(), valido);   /* si es inválido, trae el mensaje */
}

void PruebaValidaciones::dni_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("valido");
    QTest::newRow("8 dígitos") << "30111222" << true;
    QTest::newRow("7 dígitos") << "5123456" << true;
    QTest::newRow("con puntos") << "30.111.222" << true;
    QTest::newRow("vacío") << "" << false;
    QTest::newRow("con letras") << "30A11222" << false;
    QTest::newRow("6 dígitos") << "123456" << false;
    QTest::newRow("9 dígitos") << "301112223" << false;
}

void PruebaValidaciones::dni()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QString error;
    QCOMPARE(Validaciones::dniValido(entrada, &error), valido);
    QCOMPARE(error.isEmpty(), valido);
}

void PruebaValidaciones::telefono_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("valido");
    QTest::newRow("10 dígitos") << "1155550102" << true;
    QTest::newRow("con espacio y guion") << "11 5555-0102" << true;
    QTest::newRow("interior con paréntesis") << "(351) 555-0102" << true;
    QTest::newRow("con +54 9") << "+54 9 11 5555-0102" << true;
    QTest::newRow("vacío") << "" << false;
    QTest::newRow("con letras") << "11 5555-01OZ" << false;
    QTest::newRow("corto") << "5555-0102" << false;
    QTest::newRow("14 dígitos") << "54911555501022" << false;
}

void PruebaValidaciones::telefono()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QString error;
    QCOMPARE(Validaciones::telefonoValido(entrada, &error), valido);
    QCOMPARE(error.isEmpty(), valido);
}

/* Lo que se guarda y se busca: solo los dígitos. */
void PruebaValidaciones::normalizar()
{
    QCOMPARE(Validaciones::normalizar("11 5555-0102"), QString("1155550102"));
    QCOMPARE(Validaciones::normalizar("(351) 555-0102"), QString("3515550102"));
    QCOMPARE(Validaciones::normalizar("30.111.222"), QString("30111222"));
    QCOMPARE(Validaciones::normalizar("  "), QString());
}

QTEST_APPLESS_MAIN(PruebaValidaciones)
#include "prueba_validaciones.moc"
