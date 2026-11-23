/* Pruebas del QR del cupón: tamaño según el texto, buscadores en las tres esquinas, imagen con margen y
 * rechazo de lo que no entra. Que un lector real lo decodifique se comprueba aparte (ver HANDOFF):
 * con DERMALIA_QR_SALIDA=<carpeta> esta prueba guarda los PNG para decodificarlos. */
#include "codigoqr.h"

#include <QtTest>

class PruebaCodigoQr : public QObject
{
    Q_OBJECT

private slots:
    void tamanoSegunTexto_data();
    void tamanoSegunTexto();
    void buscadores();
    void imagen();
    void textoDeCupon();
    void noEntra();
    void guardarParaLector();
};

void PruebaCodigoQr::tamanoSegunTexto_data()
{
    QTest::addColumn<QString>("texto");
    QTest::addColumn<int>("lado");
    QTest::newRow("corto: versión 1")   << QStringLiteral("hola") << 21;
    QTest::newRow("token: versión 3")   << QStringLiteral("dermalia:cupon:BIENVENIDA10:123456789") << 29;
    QTest::newRow("largo: versión 10")  << QString(200, QLatin1Char('a')) << 57;
}

void PruebaCodigoQr::tamanoSegunTexto()
{
    QFETCH(QString, texto);
    QFETCH(int, lado);
    const CodigoQr qr = CodigoQr::codificar(texto);
    QVERIFY(qr.valido());
    QCOMPARE(qr.lado(), lado);
}

void PruebaCodigoQr::buscadores()
{
    const CodigoQr qr = CodigoQr::codificar(QStringLiteral("dermalia:cupon:X:1"));
    QVERIFY(qr.valido());
    const int n = qr.lado();
    const int esquinas[3][2] = { { 0, 0 }, { n - 7, 0 }, { 0, n - 7 } };
    for (const auto &e : esquinas) {
        for (int d = 0; d < 7; ++d) {   /* borde del cuadrado de 7x7: todo oscuro */
            QVERIFY(qr.modulo(e[0] + d, e[1]));
            QVERIFY(qr.modulo(e[0] + d, e[1] + 6));
            QVERIFY(qr.modulo(e[0], e[1] + d));
            QVERIFY(qr.modulo(e[0] + 6, e[1] + d));
        }
        QVERIFY(!qr.modulo(e[0] + 1, e[1] + 1));   /* anillo claro */
        QVERIFY(qr.modulo(e[0] + 3, e[1] + 3));    /* centro oscuro */
    }
    QVERIFY(qr.modulo(8, n - 8));   /* módulo oscuro fijo */
}

void PruebaCodigoQr::imagen()
{
    const CodigoQr qr = CodigoQr::codificar(QStringLiteral("hola"));
    const QImage img = qr.imagen(4, 4);
    QCOMPARE(img.width(), (qr.lado() + 8) * 4);
    QCOMPARE(img.height(), img.width());
    QCOMPARE(img.pixel(0, 0), QColor(Qt::white).rgb());                /* zona de silencio */
    QCOMPARE(img.pixel(4 * 4 + 1, 4 * 4 + 1), QColor(Qt::black).rgb()); /* esquina del primer buscador */
}

void PruebaCodigoQr::textoDeCupon()
{
    QCOMPARE(CodigoQr::textoDeCupon("BIENVENIDA10", "123"), QString("dermalia:cupon:BIENVENIDA10:123"));
    QCOMPARE(CodigoQr::tokenDeCupon("dermalia:cupon:BIENVENIDA10:123", "BIENVENIDA10"), QString("123"));
    QCOMPARE(CodigoQr::tokenDeCupon("  dermalia:cupon:bienvenida10:123\n", "BIENVENIDA10"), QString("123"));
    QCOMPARE(CodigoQr::tokenDeCupon(" 123 ", "BIENVENIDA10"), QString("123"));       /* solo el token */
    QVERIFY(CodigoQr::tokenDeCupon("dermalia:cupon:OTRO:123", "BIENVENIDA10").isEmpty());   /* otro cupón */
    QVERIFY(CodigoQr::tokenDeCupon("dermalia:cupon:BIENVENIDA10", "BIENVENIDA10").isEmpty()); /* sin token */
}

void PruebaCodigoQr::noEntra()
{
    QVERIFY(!CodigoQr::codificar(QString(300, QLatin1Char('a'))).valido());
    QVERIFY(!CodigoQr::codificar(QString()).valido());
    QVERIFY(CodigoQr::codificar(QString()).imagen().isNull());
}

void PruebaCodigoQr::guardarParaLector()
{
    const QString carpeta = qEnvironmentVariable("DERMALIA_QR_SALIDA");
    if (carpeta.isEmpty())
        QSKIP("Sin DERMALIA_QR_SALIDA no se guardan imágenes.");
    /* Un texto por cada largo posible: cubre las diez versiones y los saltos de bloques. */
    for (int largo = 1; largo <= 213; ++largo) {
        QString texto;
        for (int i = 0; i < largo; ++i)
            texto += QChar('a' + (i * 7 + largo) % 26);
        QVERIFY(CodigoQr::codificar(texto).imagen(6, 4).save(QStringLiteral("%1/qr%2.png").arg(carpeta).arg(largo)));
    }
}

QTEST_MAIN(PruebaCodigoQr)
#include "prueba_codigoqr.moc"
