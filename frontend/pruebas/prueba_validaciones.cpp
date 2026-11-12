/* Pruebas de las validaciones que usa la carga de turnos de Gestión
 * (nombre, DNI y teléfono) y del cálculo de la seña. Las de Cliente y las de precio y duración están
 * en tests/test_cliente.cpp. Cada validación tiene casos válidos, inválidos
 * y bordes. Se corre con el ejecutable prueba_validaciones o con `ctest`. */
#include "sena.h"
#include "validaciones.h"

#include <QtTest>
#include <QRegularExpressionValidator>
#include <cmath>

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
    void nombreApellido_data();
    void nombreApellido();
    void apellido();
    void email_data();
    void email();
    void fechaNacimiento();
    void fechaDesdeTexto();
    void matricula_data();
    void matricula();
    void usuarioYClave();
    void codigoTarjeta();
    void textoObligatorio();
    void precioYDuracion();
    void filtros();
    void sena_data();
    void sena();
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
    QTest::newRow("número en medio") << "Mar1a Sosa" << false;
    QTest::newRow("símbolos") << "María@Sosa" << false;
    QTest::newRow("solo guiones") << "--" << false;
    QTest::newRow("apóstrofes seguidos") << "O''Neill" << false;
    QTest::newRow("termina en guion") << "Ana-" << false;
    QTest::newRow("apóstrofo tipográfico") << "Ana D\u2019Alessio" << true;
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

/* La seña es solo un porcentaje del precio, sin mínimo. */
void PruebaValidaciones::sena_data()
{
    QTest::addColumn<int>("precio");
    QTest::addColumn<int>("porcentaje");
    QTest::addColumn<int>("esperada");
    QTest::newRow("30% de un protocolo") << 40000 << 30 << 12000;
    QTest::newRow("40% de una cirugía") << 450000 << 40 << 180000;
    QTest::newRow("sin mínimo: 30% de $18.000") << 18000 << 30 << 5400;
    QTest::newRow("redondeo al peso") << 18333 << 30 << 5500;
    QTest::newRow("precio 0") << 0 << 30 << 0;
    QTest::newRow("porcentaje 0") << 40000 << 0 << 0;
}

void PruebaValidaciones::sena()
{
    QFETCH(int, precio);
    QFETCH(int, porcentaje);
    QFETCH(int, esperada);
    QCOMPARE(Sena::calcular(precio, porcentaje), esperada);
}


void PruebaValidaciones::nombreApellido_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("valido");
    QTest::newRow("dos palabras") << "María Sosa" << true;
    QTest::newRow("tres palabras") << "María José Sosa" << true;
    QTest::newRow("una sola palabra") << "María" << false;
    QTest::newRow("con número") << "María Sosa3" << false;
    QTest::newRow("vacío") << "" << false;
}

void PruebaValidaciones::nombreApellido()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QString error;
    QCOMPARE(Validaciones::nombreApellidoValido(entrada, &error), valido);
    QCOMPARE(error.isEmpty(), valido);
}

void PruebaValidaciones::apellido()
{
    QString error;
    QVERIFY(Validaciones::apellidoValido("Pérez", &error));
    QVERIFY(Validaciones::apellidoValido("De la Torre", &error));
    QVERIFY(!Validaciones::apellidoValido("", &error));
    QVERIFY(!Validaciones::apellidoValido("P", &error));
    QVERIFY(!Validaciones::apellidoValido("Pérez2", &error));
    QVERIFY(!Validaciones::apellidoValido(QString(51, 'a'), &error));
}

void PruebaValidaciones::email_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("obligatorio");
    QTest::addColumn<bool>("valido");
    QTest::newRow("correcto") << "maria.sosa@correo.com" << true << true;
    QTest::newRow("subdominio") << "a@mail.dermalia.com.ar" << true << true;
    QTest::newRow("vacío y opcional") << "" << false << true;
    QTest::newRow("vacío y obligatorio") << "" << true << false;
    QTest::newRow("sin arroba") << "maria.correo.com" << true << false;
    QTest::newRow("sin dominio") << "maria@" << true << false;
    QTest::newRow("sin extensión") << "maria@correo" << true << false;
    QTest::newRow("con espacio") << "maria sosa@correo.com" << true << false;
    QTest::newRow("dos arrobas") << "a@b@correo.com" << true << false;
    QTest::newRow("puntos seguidos") << "maria..sosa@correo.com" << true << false;
    QTest::newRow("más de 100") << QString(95, 'a') + "@b.com" << true << false;
}

void PruebaValidaciones::email()
{
    QFETCH(QString, entrada);
    QFETCH(bool, obligatorio);
    QFETCH(bool, valido);
    QString error;
    QCOMPARE(Validaciones::emailValido(entrada, obligatorio, &error), valido);
    QCOMPARE(error.isEmpty(), valido);
}

void PruebaValidaciones::fechaNacimiento()
{
    const QDate hoy(2026, 11, 12);
    QString error;
    QVERIFY(Validaciones::fechaNacimientoValida(QDate(1990, 7, 25), hoy, &error));
    QVERIFY(Validaciones::fechaNacimientoValida(QDate(2026, 11, 11), hoy, &error));
    QVERIFY(!Validaciones::fechaNacimientoValida(hoy, hoy, &error));                // hoy no
    QVERIFY(!Validaciones::fechaNacimientoValida(QDate(2027, 1, 1), hoy, &error));  // futuro
    QVERIFY(!Validaciones::fechaNacimientoValida(QDate(1800, 1, 1), hoy, &error));  // más de 120 años
    QVERIFY(!Validaciones::fechaNacimientoValida(QDate(), hoy, &error));
}

void PruebaValidaciones::fechaDesdeTexto()
{
    QString error;
    QCOMPARE(Validaciones::fechaDesdeTexto("25/07/1990", &error), QDate(1990, 7, 25));
    QCOMPARE(Validaciones::fechaDesdeTexto(" 5/7/1990 ", &error), QDate(1990, 7, 5));
    QVERIFY(!Validaciones::fechaDesdeTexto("31/02/1990", &error).isValid());   // el día no existe
    QVERIFY(!error.isEmpty());
    QVERIFY(!Validaciones::fechaDesdeTexto("25/07/90").isValid());             // año de 2 dígitos
    QVERIFY(!Validaciones::fechaDesdeTexto("1990-07-25").isValid());
    QVERIFY(!Validaciones::fechaDesdeTexto("veinticinco").isValid());
    QVERIFY(!Validaciones::fechaDesdeTexto("").isValid());
}

void PruebaValidaciones::matricula_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("valido");
    QTest::newRow("MN con espacio") << "MN 123456" << true;
    QTest::newRow("sin espacio y minúsculas") << "mp778899" << true;
    QTest::newRow("vacía") << "" << false;
    QTest::newRow("solo letras") << "MNMN" << false;
    QTest::newRow("solo números") << "123456" << false;
    QTest::newRow("muy corta") << "MN 12" << false;
    QTest::newRow("símbolos") << "MN-123456" << false;
}

void PruebaValidaciones::matricula()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QString error;
    QCOMPARE(Validaciones::matriculaValida(entrada, &error), valido);
    QCOMPARE(error.isEmpty(), valido);
}

void PruebaValidaciones::usuarioYClave()
{
    QString error;
    QVERIFY(Validaciones::usuarioValido("lorena.vidal", &error));
    QVERIFY(Validaciones::usuarioValido("dr_perez-2", &error));
    QVERIFY(!Validaciones::usuarioValido("", &error));
    QVERIFY(!Validaciones::usuarioValido("abc", &error));
    QVERIFY(!Validaciones::usuarioValido("Lorena", &error));       // mayúscula
    QVERIFY(!Validaciones::usuarioValido("lorena vidal", &error)); // espacio
    QVERIFY(Validaciones::claveValida("secreto1", &error));
    QVERIFY(!Validaciones::claveValida("", &error));
    QVERIFY(!Validaciones::claveValida("abc12", &error));          // corta
    QVERIFY(!Validaciones::claveValida("con espacio", &error));
    QVERIFY(!Validaciones::claveValida(QString(51, 'x'), &error));
}

void PruebaValidaciones::codigoTarjeta()
{
    QString error;
    QVERIFY(Validaciones::codigoTarjetaValido("GIFT-2026-0001", &error));
    QVERIFY(Validaciones::codigoTarjetaValido(" ABCD1234 ", &error));
    QVERIFY(!Validaciones::codigoTarjetaValido("", &error));
    QVERIFY(!Validaciones::codigoTarjetaValido("AB", &error));
    QVERIFY(!Validaciones::codigoTarjetaValido("ABC DEF!", &error));
}

void PruebaValidaciones::textoObligatorio()
{
    QString error;
    QVERIFY(Validaciones::textoObligatorioValido("No tiene WhatsApp", 200, "el motivo", &error));
    QVERIFY(!Validaciones::textoObligatorioValido("   ", 200, "el motivo", &error));
    QVERIFY(!Validaciones::textoObligatorioValido("ab", 200, "el motivo", &error));
    QVERIFY(!Validaciones::textoObligatorioValido(QString(201, 'a'), 200, "el motivo", &error));
}

void PruebaValidaciones::precioYDuracion()
{
    QString error;
    QVERIFY(Validaciones::precioValido(0, &error));
    QVERIFY(Validaciones::precioValido(25000, &error));
    QVERIFY(!Validaciones::precioValido(-1, &error));
    QVERIFY(!Validaciones::precioValido(10000000.01, &error));
    QVERIFY(!Validaciones::precioValido(std::nan(""), &error));
    QVERIFY(Validaciones::duracionValida(1, &error));
    QVERIFY(Validaciones::duracionValida(600, &error));
    QVERIFY(!Validaciones::duracionValida(0, &error));
    QVERIFY(!Validaciones::duracionValida(-5, &error));
    QVERIFY(!Validaciones::duracionValida(601, &error));
}

/* Lo que se puede tipear en cada campo (QRegularExpressionValidator). */
void PruebaValidaciones::filtros()
{
    auto acepta = [](const QRegularExpression &filtro, const QString &texto) {
        QRegularExpressionValidator v(filtro);
        QString t = texto;
        int pos = 0;
        return v.validate(t, pos) == QValidator::Acceptable;
    };
    QVERIFY(acepta(Validaciones::filtroNombre(), "María José O'Neill-Pérez"));
    QVERIFY(!acepta(Validaciones::filtroNombre(), "María2"));
    QVERIFY(!acepta(Validaciones::filtroNombre(), "Ana_Sosa"));
    QVERIFY(!acepta(Validaciones::filtroNombre(), QString(61, 'a')));
    QVERIFY(acepta(Validaciones::filtroEmail(), "ana@correo.com"));
    QVERIFY(!acepta(Validaciones::filtroEmail(), "ana @correo.com"));
    QVERIFY(acepta(Validaciones::filtroMatricula(), "MN 123456"));
    QVERIFY(!acepta(Validaciones::filtroMatricula(), "MN-123456"));
}

QTEST_APPLESS_MAIN(PruebaValidaciones)
#include "prueba_validaciones.moc"
