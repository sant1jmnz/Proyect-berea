// Prueba de la ventana de Gestión conectada a la base real: ingreso del personal,
// datos leídos de los stored procedures y el recorrido de un turno (cargar,
// pagar la seña, buscar y cancelar). Necesita MySQL con la base cargada
// (backend/01 a 06) y las variables DERMALIA_DB_HOST, _PORT, _USER, _PASS.
// Sin base, se saltea. ATENCIÓN: escribe en la base (usar una de pruebas).
//   QT_QPA_PLATFORM=offscreen DERMALIA_DB_USER=root ./prueba_gestion_base
#include <QtTest>
#include <QApplication>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QRandomGenerator>
#include <QTableWidget>
#include <QTemporaryDir>
#include <QCalendarWidget>
#include <QComboBox>
#include <QDateEdit>

#include "ventanagestion.h"

namespace {

// Contesta los próximos cuadros de diálogo en orden: a los QInputDialog les escribe la
// respuesta de la lista y acepta; a los QMessageBox les aprieta Yes u Ok.
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
            if (QAbstractButton *si = mensaje->button(QMessageBox::Yes))
                si->click();
            else if (QAbstractButton *ok = mensaje->button(QMessageBox::Ok))
                ok->click();
            else
                mensaje->close();
        }
        if (!respuestas.isEmpty() || qobject_cast<QInputDialog *>(dialogo))
            QTimer::singleShot(50, [respuestas]() { responderDialogos(respuestas); });
    });
}

}  // namespace

class PruebaGestionBase : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase()
    {
        // Ingreso automático del personal (sin abrir la ventana de login).
        qputenv("DERMALIA_USUARIO", "recepcion1");
        qputenv("DERMALIA_CLAVE", "dermalia2026");
    }

    // Con la base conectada, las pantallas muestran los datos de la base.
    void ventana_leeLosDatosDeLaBase()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        QTest::qWait(1500);   // la ventana prueba la conexión apenas se muestra, e ingresa con DERMALIA_USUARIO
        if (!w.usaBase())
            QSKIP("Sin base de datos o sin ingreso (definir DERMALIA_DB_USER, etc.).");
        QVERIFY(w.usuarioActual() > 0);

        QVERIFY(w.findChild<QListWidget *>("listaProtocolos")->count() >= 30);   // solo los activos
        QVERIFY(w.findChild<QTableWidget *>("tablaTurnos")->rowCount() > 20);
        QVERIFY(w.findChild<QTableWidget *>("tablaAvisos")->rowCount() > 20);
        QVERIFY(w.findChild<QWidget *>("pagProtocolos")->findChild<QTableWidget *>("tablaProtocolos")->rowCount() >= 30);
        QVERIFY(w.findChild<QWidget *>("pagProfesionales")->findChild<QListWidget *>("listaProfesionales")->count() >= 20);
    }

    // La pantalla Reportes llama a los stored procedures de reportes y de auditoría.
    void ventana_reportesYAuditoria()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        QTest::qWait(1500);
        if (!w.usaBase())
            QSKIP("Sin base de datos o sin ingreso (definir DERMALIA_DB_USER, etc.).");
        auto *pagina = w.findChild<QWidget *>("pagReportes");
        auto *combo = pagina->findChild<QComboBox *>("comboReporte");
        auto *tabla = pagina->findChild<QTableWidget *>("tablaReporte");
        pagina->findChild<QDateEdit *>("editDesdeReporte")->setDate(QDate(2026, 9, 1));
        pagina->findChild<QDateEdit *>("editHastaReporte")->setDate(QDate(2026, 11, 30));
        QVERIFY(pagina->findChild<QPushButton *>("btnConsultar")->isEnabled());

        combo->setCurrentIndex(1);   // ingresos por seña
        pagina->findChild<QPushButton *>("btnConsultar")->click();
        QVERIFY(tabla->rowCount() > 0);
        QCOMPARE(tabla->horizontalHeaderItem(0)->text(), QString("periodo"));   // las columnas salen en el orden del SELECT
        QCOMPARE(tabla->horizontalHeaderItem(1)->text(), QString("medio_pago"));

        combo->setCurrentIndex(8);   // auditoría
        pagina->findChild<QDateEdit *>("editDesdeReporte")->setDate(QDate::currentDate().addDays(-1));
        pagina->findChild<QDateEdit *>("editHastaReporte")->setDate(QDate::currentDate().addDays(1));
        pagina->findChild<QPushButton *>("btnConsultar")->click();
        QVERIFY(tabla->rowCount() > 0);   // el ingreso de esta prueba ya está en el log
    }

    // Cargar un turno de punta a punta: paciente nueva, horario libre de la base, seña, búsqueda y cancelación.
    void ventana_cargarPagarBuscarYCancelar()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        QTest::qWait(1500);   // la ventana prueba la conexión apenas se muestra, e ingresa con DERMALIA_USUARIO
        if (!w.usaBase())
            QSKIP("Sin base de datos o sin ingreso (definir DERMALIA_DB_USER, etc.).");

        const QString dni = QString::number(60000000 + int(QRandomGenerator::global()->bounded(9999999)));
        w.findChild<QLineEdit *>("editPaciente")->setText("Prueba Gestionbase");
        w.findChild<QLineEdit *>("editDni")->setText(dni);
        w.findChild<QLineEdit *>("editTelefono")->setText("1155558888");
        auto *protocolos = w.findChild<QListWidget *>("listaProtocolos");
        protocolos->setCurrentRow(0);
        protocolos->item(0)->setSelected(true);
        w.findChild<QPushButton *>("btnContinuar1")->click();

        // Un día con horarios libres, al menos 2 días adelante (así cancelar reembolsa todo).
        auto *calendario = w.findChild<QCalendarWidget *>("calendario");
        auto *horarios = w.findChild<QListWidget *>("listaHorarios");
        bool hayHorario = false;
        for (int d = 2; d <= 30 && !hayHorario; ++d) {
            calendario->setSelectedDate(QDate::currentDate().addDays(d));
            hayHorario = horarios->count() > 0 && (horarios->item(0)->flags() & Qt::ItemIsSelectable);
        }
        if (!hayHorario)
            QSKIP("No hay horarios libres en los próximos 30 días (los datos de ejemplo llegan hasta fines de noviembre de 2026).");
        QVERIFY(horarios->item(0)->text().contains(" · "));   // "09:00 · Apellido, Nombre"
        horarios->setCurrentRow(0);
        horarios->item(0)->setSelected(true);
        w.findChild<QPushButton *>("btnContinuar2")->click();

        // Confirmar con la seña paga: pide apellido y nacimiento (paciente nueva) y el medio de pago.
        w.findChild<QPushButton *>("btnSena")->setChecked(true);
        responderDialogos({ "Gestionbase", "25/07/1990", "efectivo", "" });
        w.findChild<QPushButton *>("btnConfirmar")->click();

        // El turno quedó en la base: la búsqueda lo trae confirmado y con la seña pagada.
        auto *tabla = w.findChild<QTableWidget *>("tablaTurnos");
        auto *buscar = w.findChild<QLineEdit *>("editBuscar");
        buscar->setText(dni);
        QTest::keyClick(buscar, Qt::Key_Return);
        QCOMPARE(tabla->rowCount(), 1);
        QCOMPARE(tabla->item(0, 5)->text(), QString("Confirmado"));
        QVERIFY2(tabla->item(0, 6)->text().contains("pagada"), qPrintable(tabla->item(0, 6)->text()));

        // Cancelar con más de 24 h: la base reembolsa la seña.
        tabla->selectRow(0);
        QVERIFY(w.findChild<QPushButton *>("btnCancelarTurno")->isEnabled());
        responderDialogos({ "", "" });
        w.findChild<QPushButton *>("btnCancelarTurno")->click();
        QTest::keyClick(buscar, Qt::Key_Return);
        QCOMPARE(tabla->item(0, 5)->text(), QString("Cancelado"));
        QVERIFY2(tabla->item(0, 6)->text().contains("reembolsada"), qPrintable(tabla->item(0, 6)->text()));
    }
};

QTEST_MAIN(PruebaGestionBase)
#include "prueba_gestion_base.moc"
