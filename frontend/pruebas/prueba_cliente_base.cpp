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
};

QTEST_MAIN(PruebaClienteBase)
#include "prueba_cliente_base.moc"
