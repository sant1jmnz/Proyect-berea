/* Pruebas automáticas de las reglas de negocio (Semana 3, QA).
 * Cada función tiene al menos 4 casos: válidos, inválidos y bordes.
 * Se corren desde Qt Creator (ejecutable prueba_reglas) o con `ctest`. */
#include "reglas.h"

#include <QtTest>

class PruebaReglas : public QObject
{
    Q_OBJECT

private slots:
    void nombre_data();
    void nombre();
    void dni_data();
    void dni();
    void telefono_data();
    void telefono();
    void sena_data();
    void sena();
    void reembolso_data();
    void reembolso();
};

/* Cada caso: dato de entrada y si tiene que ser válido. */
void PruebaReglas::nombre_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("valido");
    QTest::newRow("nombre y apellido") << "María Sosa" << true;
    QTest::newRow("con apóstrofo y guion") << "Ana O'Neill-Pérez" << true;
    QTest::newRow("espacios de más") << "  Lucía   Fernández " << true;
    QTest::newRow("vacío") << "" << false;
    QTest::newRow("solo espacios") << "   " << false;
    QTest::newRow("sin apellido") << "María" << false;
    QTest::newRow("con números") << "María Sosa 2" << false;
}

void PruebaReglas::nombre()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QCOMPARE(Reglas::validarNombre(entrada).isEmpty(), valido);
}

void PruebaReglas::dni_data()
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
    QTest::newRow("empieza con 0") << "01112222" << false;
}

void PruebaReglas::dni()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QCOMPARE(Reglas::validarDni(entrada).isEmpty(), valido);
}

void PruebaReglas::telefono_data()
{
    QTest::addColumn<QString>("entrada");
    QTest::addColumn<bool>("valido");
    QTest::newRow("10 dígitos") << "1155550102" << true;
    QTest::newRow("con espacio y guion") << "11 5555-0102" << true;
    QTest::newRow("interior con paréntesis") << "(351) 555-0102" << true;
    QTest::newRow("vacío") << "" << false;
    QTest::newRow("con letras") << "11 5555-01OZ" << false;
    QTest::newRow("con 0 adelante") << "01155550102" << false;
    QTest::newRow("con 15") << "11 15 5555-0102" << false;
    QTest::newRow("corto") << "5555-0102" << false;
}

void PruebaReglas::telefono()
{
    QFETCH(QString, entrada);
    QFETCH(bool, valido);
    QCOMPARE(Reglas::validarTelefono(entrada).isEmpty(), valido);
}

void PruebaReglas::sena_data()
{
    QTest::addColumn<int>("precio");
    QTest::addColumn<bool>("cirugia");
    QTest::addColumn<int>("esperada");
    QTest::newRow("30% supera el mínimo") << 120000 << false << 36000;
    QTest::newRow("30% no llega al mínimo") << 40000 << false << 20000;
    QTest::newRow("precio menor al mínimo: tope en el precio") << 18000 << false << 18000;
    QTest::newRow("cirugía al 40%") << 450000 << true << 180000;
    QTest::newRow("cirugía barata: mínimo") << 30000 << true << 20000;
    QTest::newRow("redondeo al peso") << 100001 << false << 30000;
    QTest::newRow("precio 0") << 0 << false << 0;
}

void PruebaReglas::sena()
{
    QFETCH(int, precio);
    QFETCH(bool, cirugia);
    QFETCH(int, esperada);
    QCOMPARE(Reglas::calcularSena(precio, cirugia), esperada);
}

void PruebaReglas::reembolso_data()
{
    QTest::addColumn<int>("horasAntes");   /* cuántas horas antes del turno se cancela */
    QTest::addColumn<bool>("reembolsa");
    QTest::newRow("3 días antes") << 72 << true;
    QTest::newRow("25 horas antes") << 25 << true;
    QTest::newRow("justo 24 horas antes") << 24 << false;
    QTest::newRow("3 horas antes") << 3 << false;
    QTest::newRow("después del turno (inasistencia)") << -2 << false;
}

void PruebaReglas::reembolso()
{
    QFETCH(int, horasAntes);
    QFETCH(bool, reembolsa);
    const QDateTime turno(QDate(2026, 10, 22), QTime(9, 0));
    QCOMPARE(Reglas::senaReembolsable(turno, turno.addSecs(-horasAntes * 3600)), reembolsa);
}

QTEST_APPLESS_MAIN(PruebaReglas)
#include "prueba_reglas.moc"
