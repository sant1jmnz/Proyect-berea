// Prueba de la terminal del Cliente conectada a la base real: catálogo, horarios libres,
// reserva con seña simulada y búsqueda por DNI. Necesita MySQL con la base cargada
// (backend/01 a 06) y DERMALIA_DB_HOST, _PORT, _USER, _PASS. Sin base, se saltea.
// ATENCIÓN: escribe en la base (usar una de pruebas).
//   QT_QPA_PLATFORM=offscreen DERMALIA_DB_USER=root ./prueba_cliente_base
#include <QtTest>
#include <QApplication>
#include <QComboBox>
#include <QDateEdit>
#include <QLineEdit>
#include <QInputDialog>
#include <QMessageBox>
#include <QPushButton>
#include <QRandomGenerator>

#include "basedatos.h"
#include "mainwindow.h"
#include "pasoscargaturnowidget.h"
#include "repositorio.h"

namespace {

// Contesta los próximos cuadros de diálogo: a los QInputDialog les escribe la respuesta y acepta;
// a los QMessageBox les aprieta Ok.
void responderDialogos(QStringList respuestas)
{
    QTimer::singleShot(30, [respuestas]() mutable {
        QWidget *dialogo = QApplication::activeModalWidget();
        if (!dialogo) {
            responderDialogos(respuestas);   // todavía no apareció: reintenta
            return;
        }
        if (auto *entrada = qobject_cast<QInputDialog *>(dialogo)) {
            entrada->setTextValue(respuestas.isEmpty() ? QString() : respuestas.takeFirst());
            entrada->accept();
        } else if (auto *mensaje = qobject_cast<QMessageBox *>(dialogo)) {
            if (QAbstractButton *ok = mensaje->button(QMessageBox::Ok))
                ok->click();
            else
                mensaje->close();
        }
        if (!respuestas.isEmpty() || qobject_cast<QInputDialog *>(dialogo))
            QTimer::singleShot(50, [respuestas]() { responderDialogos(respuestas); });
    });
}

}  // namespace

class PruebaClienteBase : public QObject
{
    Q_OBJECT

private slots:
    void terminal_reservaUnTurnoEnLaBase()
    {
        MainWindow w;
        QTest::qWait(1500);   // prueba la conexión apenas se muestra y pasa a leer de la base
        BaseDatos base(ConfigBD::desdeEntorno());
        if (!base.conectar())
            QSKIP("Sin base de datos (definir DERMALIA_DB_USER, etc.).");
        Repositorio repo(base);

        auto *pasos = w.findChild<PasosCargaTurnoWidget *>();
        QVERIFY(pasos);

        // Paso 1: datos de la paciente (el protocolo por defecto es el primero del catálogo de la base).
        const QString dni = QString::number(70000000 + int(QRandomGenerator::global()->bounded(9999999)));
        pasos->findChild<QLineEdit *>("txtNombre")->setText("Prueba Terminal");
        pasos->findChild<QLineEdit *>("txtDni")->setText(dni);
        pasos->findChild<QLineEdit *>("txtTelefono")->setText("1155557777");
        pasos->findChild<QPushButton *>("btnPaso1Siguiente")->click();
        QVERIFY(pasos->findChild<QComboBox *>("comboProf")->count() > 0);   // profesionales que hacen el protocolo

        // Paso 2: un día con horarios libres, al menos 2 días adelante (cancelar reembolsa todo).
        auto *fecha = pasos->findChild<QDateEdit *>("dateEdit");
        QPushButton *horario = nullptr;
        for (int d = 2; d <= 30 && !horario; ++d) {
            fecha->setDate(QDate::currentDate().addDays(d));
            for (QPushButton *boton : pasos->findChildren<QPushButton *>()) {
                if (boton->text().endsWith(" hs") && boton->isEnabled()) {
                    horario = boton;
                    break;
                }
            }
        }
        if (!horario)
            QSKIP("No hay horarios libres en los próximos 30 días (los datos de ejemplo llegan hasta fines de noviembre de 2026).");
        horario->click();
        pasos->findChild<QPushButton *>("btnPaso2Siguiente")->click();

        // Paso 3: confirmar. Es la primera vez de la paciente: pide apellido y fecha de nacimiento.
        responderDialogos({ "Terminal", "25/07/1990" });
        pasos->findChild<QPushButton *>("btnPaso3Confirmar")->click();

        // El turno quedó en la base, confirmado y con la seña pagada.
        const QVector<TurnoBD> turnos = repo.buscarTurnos(dni);
        QCOMPARE(turnos.size(), 1);
        QCOMPARE(turnos.first().estado, QString("confirmado"));
        QCOMPARE(turnos.first().estadoSena, QString("pagada"));
        QCOMPARE(turnos.first().origen, QString("terminal"));

        // Limpieza: se cancela para no dejar el horario ocupado.
        QVERIFY(repo.cancelarTurno(turnos.first().id, "terminal").ok);
    }
};

QTEST_MAIN(PruebaClienteBase)
#include "prueba_cliente_base.moc"
