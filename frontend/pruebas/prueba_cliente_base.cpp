// Prueba de la terminal (dermalia_cliente) conectada a la base real: catálogo de la base,
// horarios libres, reserva de una paciente nueva con seña simulada, búsqueda por DNI y
// cancelación. Necesita MySQL con la base cargada (backend/) y DERMALIA_DB_HOST, _USER, _PASS.
// Sin base, se saltea. ATENCIÓN: escribe en la base (usar una de pruebas).
//   QT_QPA_PLATFORM=offscreen DERMALIA_DB_USER=root DERMALIA_DB_PASS=... ./prueba_cliente_base
#include <QtTest>
#include <QApplication>
#include <QCalendarWidget>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QRandomGenerator>
#include <QTemporaryDir>

#include "basedatos.h"
#include "repositorio.h"
#include "ventanacliente.h"

namespace {

// Contesta el próximo cuadro: a un QInputDialog le escribe `texto` y acepta;
// a un QMessageBox le toca el botón que se llama `boton`. Guarda el texto del mensaje.
void contestar(const QString &boton, const QString &texto = QString(), QString *mensaje = nullptr)
{
    QTimer::singleShot(30, [boton, texto, mensaje]() {
        QWidget *dialogo = QApplication::activeModalWidget();
        if (auto *entrada = qobject_cast<QInputDialog *>(dialogo)) {
            entrada->setTextValue(texto);
            entrada->accept();
            return;
        }
        auto *cuadro = qobject_cast<QMessageBox *>(dialogo);
        if (!cuadro) {
            contestar(boton, texto, mensaje);   // todavía no apareció: reintenta
            return;
        }
        if (mensaje)
            *mensaje = cuadro->text();
        for (QAbstractButton *b : cuadro->buttons())
            if (b->text().remove('&') == boton)
                return b->click();
        cuadro->close();
    });
}

// Marca el protocolo con ese nombre en el paso 1.
bool marcarProtocolo(VentanaCliente &w, const QString &nombre)
{
    auto *lista = w.findChild<QListWidget *>("listaProtocolos");
    for (int i = 0; i < lista->count(); ++i) {
        if (lista->item(i)->text().startsWith(nombre + "\n")) {
            lista->item(i)->setSelected(true);
            return true;
        }
    }
    return false;
}

// Pasos 1 y 2: continúa y elige el primer horario libre (desde pasado mañana). false si no hay ninguno.
bool irAlPaso3(VentanaCliente &w)
{
    w.findChild<QPushButton *>("btnContinuar1")->click();
    auto *calendario = w.findChild<QCalendarWidget *>("calendario");
    auto *horarios = w.findChild<QListWidget *>("listaHorarios");
    for (int d = 2; d <= 40 && horarios->count() == 0; ++d)
        calendario->setSelectedDate(QDate::currentDate().addDays(d));
    if (horarios->count() == 0)
        return false;
    horarios->setCurrentRow(0);
    horarios->item(0)->setSelected(true);
    w.findChild<QPushButton *>("btnContinuar2")->click();
    return true;
}

}  // namespace

class PruebaClienteBase : public QObject
{
    Q_OBJECT

    QTemporaryDir carpeta;

private slots:
    void terminal_reservaBuscaYCancelaEnLaBase()
    {
        BaseDatos base(ConfigBD::desdeEntorno());
        if (!base.conectar())
            QSKIP("Sin base de datos (definir DERMALIA_DB_USER, etc.).");
        Repositorio repo(base);

        VentanaCliente w(nullptr, carpeta.filePath("local.json"), carpeta.filePath("pendientes.json"));
        w.show();
        QTRY_VERIFY_WITH_TIMEOUT(w.usaBase(), 5000);   // se conecta apenas se muestra

        // Paso 1: el catálogo es el de la base (más de 4 protocolos). Se elige el primero.
        auto *protocolos = w.findChild<QListWidget *>("listaProtocolos");
        QVERIFY(protocolos->count() > 4);
        protocolos->setCurrentRow(0);
        protocolos->item(0)->setSelected(true);
        w.findChild<QPushButton *>("btnContinuar1")->click();

        // Paso 2: el primer día, desde pasado mañana, con horarios libres en la base.
        auto *calendario = w.findChild<QCalendarWidget *>("calendario");
        auto *horarios = w.findChild<QListWidget *>("listaHorarios");
        for (int d = 2; d <= 40 && horarios->count() == 0; ++d)
            calendario->setSelectedDate(QDate::currentDate().addDays(d));
        QVERIFY2(horarios->count() > 0, "No hay horarios libres en los próximos 40 días");
        horarios->setCurrentRow(0);
        horarios->item(0)->setSelected(true);
        w.findChild<QPushButton *>("btnContinuar2")->click();

        // Paso 3: paciente nueva (DNI al azar): pregunta la fecha de nacimiento y reserva.
        const QString dni = QString::number(70000000 + QRandomGenerator::global()->bounded(9999999));
        w.findChild<QLineEdit *>("editNombre")->setText("Prueba Terminal");
        w.findChild<QLineEdit *>("editDni")->setText(dni);
        w.findChild<QLineEdit *>("editTelefono")->setText("1155557777");
        w.findChild<QPushButton *>("btnSena")->setChecked(true);
        QString confirmado;
        contestar("", "15/03/1990");             // fecha de nacimiento
        QTimer::singleShot(200, [&confirmado] { contestar("OK", QString(), &confirmado); });
        w.findChild<QPushButton *>("btnConfirmar")->click();
        QVERIFY2(confirmado.contains("SIM-"), qPrintable(confirmado));   // seña simulada registrada

        // Quedó en la base y la terminal lo muestra en "Buscar mi turno".
        const QVector<TurnoBD> enLaBase = repo.buscarTurnos(dni);
        QCOMPARE(enLaBase.size(), 1);
        QCOMPARE(enLaBase.first().estado, QString("confirmado"));
        QCOMPARE(w.findChild<QLabel *>("lblResTurnoPaciente")->text(), QString("Prueba Terminal"));

        // Cancelar: faltan más de 24 horas, se devuelve la seña completa.
        contestar("Yes");
        QTimer::singleShot(400, [] { contestar("OK"); });
        w.findChild<QPushButton *>("btnCancelarMiTurno")->click();
        QCOMPARE(repo.buscarTurnos(dni).first().estado, QString("cancelado"));
        QCOMPARE(w.findChild<QLabel *>("lblEstadoTurno")->text(), QString("Cancelado"));
    }

    // Dos protocolos en un turno, con un cupón real de la paciente (RF-01, RF-17): igual que el sitio web.
    void terminal_variosProtocolosConCuponReal()
    {
        BaseDatos base(ConfigBD::desdeEntorno());
        if (!base.conectar())
            QSKIP("Sin base de datos (definir DERMALIA_DB_USER, etc.).");
        Repositorio repo(base);

        // Una paciente con un cupón vigente y sin usar.
        QString dni, codigo, nombre;
        int porcentaje = 0;
        for (const QVariantMap &paciente : repo.listarPacientes().filas) {
            for (const QVariantMap &c : repo.listarCupones(paciente.value("dni").toString()).filas) {
                if (c.value("usado").toInt() == 0 && c.value("vigente").toInt() == 1) {
                    dni = paciente.value("dni").toString();
                    codigo = c.value("codigo").toString();
                    porcentaje = qRound(c.value("porcentaje_descuento").toDouble());
                    nombre = "Prueba Cupon";
                }
            }
            if (!codigo.isEmpty())
                break;
        }
        if (codigo.isEmpty())
            QSKIP("No quedan cupones sin usar en la base: recargarla.");

        VentanaCliente w(nullptr, carpeta.filePath("local.json"), carpeta.filePath("pendientes.json"));
        w.show();
        QTRY_VERIFY_WITH_TIMEOUT(w.usaBase(), 5000);
        QVERIFY(marcarProtocolo(w, "Limpieza facial profunda"));
        QVERIFY(marcarProtocolo(w, "Peeling químico"));
        if (!irAlPaso3(w))
            QSKIP("No hay horarios libres para esos dos protocolos en los próximos 40 días.");

        w.findChild<QLineEdit *>("editNombre")->setText(nombre);
        w.findChild<QLineEdit *>("editDni")->setText(dni);
        w.findChild<QLineEdit *>("editTelefono")->setText("1155558888");
        // Un código ajeno se rechaza y el real se aplica.
        w.findChild<QLineEdit *>("editCodigo")->setText("DER-NOEXISTE");
        w.findChild<QPushButton *>("btnAplicarCodigo")->click();
        QVERIFY(w.findChild<QLabel *>("lblEstadoCodigo")->text().contains("no existe"));
        w.findChild<QLineEdit *>("editCodigo")->setText(codigo);
        w.findChild<QPushButton *>("btnAplicarCodigo")->click();
        QVERIFY2(w.findChild<QLabel *>("lblEstadoCodigo")->text().contains("Cupón aplicado"),
                 qPrintable(w.findChild<QLabel *>("lblEstadoCodigo")->text()));
        QVERIFY(w.findChild<QLabel *>("lblResPrecio")->text().contains(QString("cupón −%1 %").arg(porcentaje)));

        w.findChild<QPushButton *>("btnSena")->setChecked(true);
        QString confirmado;
        contestar("OK", QString(), &confirmado);
        w.findChild<QPushButton *>("btnConfirmar")->click();
        QVERIFY2(confirmado.contains("Limpieza facial profunda + Peeling químico"), qPrintable(confirmado));

        // En la base: un turno confirmado con el precio de los dos protocolos menos el cupón, y el cupón ya usado.
        // (sp_buscar_turnos devuelve un solo nombre de protocolo por turno, por eso se comprueba el precio.)
        const double esperado = 210000.0 * (100 - porcentaje) / 100.0;   // $90.000 + $120.000
        bool encontrado = false;
        for (const TurnoBD &t : repo.buscarTurnos(dni))
            if (qAbs(t.precioFinal - esperado) < 1 && t.estado == "confirmado")
                encontrado = true;
        QVERIFY2(encontrado, "No está el turno con los dos protocolos y el cupón");
        for (const QVariantMap &c : repo.listarCupones(dni).filas)
            if (c.value("codigo").toString() == codigo)
                QCOMPARE(c.value("usado").toInt(), 1);
    }

    // La seña se paga con una tarjeta de regalo (RF-23): se descuenta de su saldo.
    void terminal_senaConTarjetaDeRegalo()
    {
        BaseDatos base(ConfigBD::desdeEntorno());
        if (!base.conectar())
            QSKIP("Sin base de datos (definir DERMALIA_DB_USER, etc.).");
        Repositorio repo(base);
        const Respuesta compra = repo.comprarTarjeta(100000, "efectivo", "Prueba Terminal", "1155559999", "terminal");
        QVERIFY2(compra.ok, qPrintable(compra.mensaje));
        const QString tarjeta = compra.dato;

        VentanaCliente w(nullptr, carpeta.filePath("local.json"), carpeta.filePath("pendientes.json"));
        w.show();
        QTRY_VERIFY_WITH_TIMEOUT(w.usaBase(), 5000);
        QVERIFY(marcarProtocolo(w, "Limpieza facial profunda"));   // $90.000: seña $27.000
        if (!irAlPaso3(w))
            QSKIP("No hay horarios libres en los próximos 40 días.");

        const QString dni = QString::number(70000000 + QRandomGenerator::global()->bounded(9999999));
        w.findChild<QLineEdit *>("editNombre")->setText("Prueba Tarjeta");
        w.findChild<QLineEdit *>("editDni")->setText(dni);
        w.findChild<QLineEdit *>("editTelefono")->setText("1155557766");
        w.findChild<QLineEdit *>("editCodigo")->setText(tarjeta);
        w.findChild<QPushButton *>("btnAplicarCodigo")->click();
        QVERIFY2(w.findChild<QLabel *>("lblEstadoCodigo")->text().contains("Tarjeta de regalo aplicada"),
                 qPrintable(w.findChild<QLabel *>("lblEstadoCodigo")->text()));

        w.findChild<QPushButton *>("btnSena")->setChecked(true);
        QString confirmado;
        contestar("", "15/03/1990");             // fecha de nacimiento (paciente nueva)
        QTimer::singleShot(200, [&confirmado] { contestar("OK", QString(), &confirmado); });
        w.findChild<QPushButton *>("btnConfirmar")->click();
        QVERIFY2(confirmado.contains("con tu tarjeta de regalo"), qPrintable(confirmado));

        const Resultado saldo = repo.saldoTarjeta(tarjeta, "terminal");
        QVERIFY(saldo.ok && !saldo.filas.isEmpty());
        QCOMPARE(qRound(saldo.filas.first().value("saldo").toDouble()), 100000 - 27000);
    }
};

QTEST_MAIN(PruebaClienteBase)
#include "prueba_cliente_base.moc"
