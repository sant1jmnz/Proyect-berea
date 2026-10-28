// Casos de prueba automáticos del apartado Cliente (Semana 3, QA).
// Corren sin base de datos y sin pantalla: QT_QPA_PLATFORM=offscreen ./dermalia_tests
#include <QtTest>
#include <QApplication>
#include <QLineEdit>
#include <QPushButton>
#include <QStackedWidget>
#include <QMessageBox>
#include <QFrame>
#include <QLabel>
#include <QDate>
#include <QDateEdit>
#include <QRadioButton>

#include "validaciones.h"
#include "pasoscargaturnowidget.h"
#include "buscadorwidget.h"
#include "buscarturnowidget.h"

namespace {

// Cierra el próximo cuadro de diálogo modal que aparezca. Si `boton` es Yes, lo acepta.
void cerrarDialogo(QMessageBox::StandardButton boton, int *contador = nullptr) {
    QTimer::singleShot(50, [boton, contador]() {
        if (auto *mb = qobject_cast<QMessageBox *>(QApplication::activeModalWidget())) {
            if (contador) {
                ++*contador;
            }
            if (QAbstractButton *b = mb->button(boton)) {
                b->click();
            } else {
                mb->close();
            }
        } else {
            cerrarDialogo(boton, contador); // todavía no apareció: reintenta
        }
    });
}

void completarPaso1(PasosCargaTurnoWidget &w, const QString &nombre, const QString &dni, const QString &tel) {
    w.findChild<QLineEdit *>("txtNombre")->setText(nombre);
    w.findChild<QLineEdit *>("txtDni")->setText(dni);
    w.findChild<QLineEdit *>("txtTelefono")->setText(tel);
}

int paginaActual(PasosCargaTurnoWidget &w) {
    return w.findChild<QStackedWidget *>("stackedPasos")->currentIndex();
}

} // namespace

class TestCliente : public QObject {
    Q_OBJECT

private slots:
    // ---------- Validaciones (RNF / Semana 3) ----------
    void dni_valido_data() {
        QTest::addColumn<QString>("dni");
        QTest::addColumn<bool>("ok");
        QTest::newRow("8 dígitos") << "36123456" << true;
        QTest::newRow("7 dígitos") << "9123456" << true;
        QTest::newRow("con puntos") << "36.123.456" << true;
        QTest::newRow("vacío") << "" << false;
        QTest::newRow("6 dígitos") << "123456" << false;
        QTest::newRow("9 dígitos") << "123456789" << false;
        QTest::newRow("con letras") << "36A23456" << false;
    }
    void dni_valido() {
        QFETCH(QString, dni);
        QFETCH(bool, ok);
        QCOMPARE(Validaciones::dniValido(dni), ok);
    }

    void telefono_valido_data() {
        QTest::addColumn<QString>("tel");
        QTest::addColumn<bool>("ok");
        QTest::newRow("10 dígitos") << "1144332211" << true;
        QTest::newRow("con código de país") << "+5491144332211" << true;
        QTest::newRow("con guiones y espacios") << "11 4433-2211" << true;
        QTest::newRow("vacío") << "" << false;
        QTest::newRow("9 dígitos") << "114433221" << false;
        QTest::newRow("14 dígitos") << "54911443322110" << false;
        QTest::newRow("con letras") << "11443322ab" << false;
    }
    void telefono_valido() {
        QFETCH(QString, tel);
        QFETCH(bool, ok);
        QCOMPARE(Validaciones::telefonoValido(tel), ok);
    }

    void nombre_valido() {
        QVERIFY(Validaciones::nombreValido("Carolina Morales"));
        QVERIFY(Validaciones::nombreValido("María José O'Brien-Pérez"));
        QVERIFY(!Validaciones::nombreValido(""));
        QVERIFY(!Validaciones::nombreValido("A"));
        QVERIFY(!Validaciones::nombreValido("Carolina123"));
    }

    void abm_protocolos_precio_y_duracion() {
        QVERIFY(Validaciones::precioValido(0.0));
        QVERIFY(Validaciones::precioValido(22000.0));
        QVERIFY(!Validaciones::precioValido(-1.0));
        QVERIFY(Validaciones::duracionValida(1));
        QVERIFY(Validaciones::duracionValida(45));
        QVERIFY(!Validaciones::duracionValida(0));
        QVERIFY(!Validaciones::duracionValida(-10));
    }

    // ---------- RF-01 / RF-04 / RF-08 / RF-10: carga de turno en 3 pasos ----------
    void rf01_mascara_de_entrada() {
        PasosCargaTurnoWidget w;
        w.show();
        auto *dni = w.findChild<QLineEdit *>("txtDni");
        QTest::keyClicks(dni, "36ab12.3456789");
        QCOMPARE(dni->text(), QString("36123456")); // solo dígitos y máximo 8
        auto *tel = w.findChild<QLineEdit *>("txtTelefono");
        QTest::keyClicks(tel, "11-44x332211");
        QCOMPARE(tel->text(), QString("1144332211"));
    }

    void rf01_paso1_datos_invalidos_no_avanza() {
        PasosCargaTurnoWidget w;
        auto *btn = w.findChild<QPushButton *>("btnPaso1Siguiente");

        completarPaso1(w, "", "", "");
        cerrarDialogo(QMessageBox::Ok);
        btn->click();
        QCOMPARE(paginaActual(w), 0);

        completarPaso1(w, "Carolina Morales", "123", "1144332211");
        cerrarDialogo(QMessageBox::Ok);
        btn->click();
        QCOMPARE(paginaActual(w), 0);

        completarPaso1(w, "Carolina Morales", "36123456", "123");
        cerrarDialogo(QMessageBox::Ok);
        btn->click();
        QCOMPARE(paginaActual(w), 0);
    }

    void rf01_rf04_rf08_rf10_flujo_completo() {
        PasosCargaTurnoWidget w;
        QSignalSpy spy(&w, &PasosCargaTurnoWidget::turnoConfirmado);

        completarPaso1(w, "Carolina Morales", "36123456", "1144332211");
        w.findChild<QPushButton *>("btnPaso1Siguiente")->click();
        QCOMPARE(paginaActual(w), 1);

        // Paso 2 sin elegir horario: no avanza
        cerrarDialogo(QMessageBox::Ok);
        w.findChild<QPushButton *>("btnPaso2Siguiente")->click();
        QCOMPARE(paginaActual(w), 1);

        // Elegir el primer horario libre
        QPushButton *horario = nullptr;
        for (auto *b : w.findChildren<QPushButton *>()) {
            if (b->text().endsWith(" hs") && b->isEnabled()) {
                horario = b;
                break;
            }
        }
        QVERIFY(horario);
        const QString textoHorario = horario->text();
        horario->click();
        w.findChild<QPushButton *>("btnPaso2Siguiente")->click();
        QCOMPARE(paginaActual(w), 2);

        // Paso 3: seña = 30% con mínimo $5.000 (Láser Diodo Facial $22.000 → $6.600)
        auto *lblSenia = w.findChild<QLabel *>("lblMontoSenia");
        QVERIFY2(lblSenia->text().contains("6600"), qPrintable(lblSenia->text()));

        w.findChild<QPushButton *>("btnPaso3Confirmar")->click();
        QCOMPARE(spy.count(), 1);
        QCOMPARE(paginaActual(w), 3);
        QCOMPARE(spy.at(0).at(1).toString(), QString("36123456"));
        QCOMPARE(spy.at(0).at(7).toDouble(), 6600.0);

        // RF-04: el horario recién reservado queda ocupado para la misma fecha y profesional
        w.findChild<QPushButton *>("btnNuevoTurno")->click();
        const QString hora = textoHorario.section(' ', 0, 0);
        bool ocupado = false;
        for (auto *b : w.findChildren<QPushButton *>()) {
            if (b->text().startsWith(hora + " hs") && b->text().contains("Ocupado") && !b->isEnabled()) {
                ocupado = true;
            }
        }
        QVERIFY(ocupado);
    }

    // ---------- RF-05 / RF-07: buscador de protocolos ----------
    void rf05_buscador_filtra_por_palabra_clave() {
        BuscadorWidget w;
        w.show();
        auto *txt = w.findChild<QLineEdit *>("txtBuscar");
        auto *whatsapp = w.findChild<QFrame *>("frameWhatsApp");

        txt->setText("peeling");
        QVERIFY(!whatsapp->isVisibleTo(&w));
        QSignalSpy spy(&w, &BuscadorWidget::protocoloSeleccionado);
        int botones = 0;
        for (auto *b : w.findChildren<QPushButton *>()) {
            if (b->text() == "Seleccionar") {
                ++botones;
                b->click();
            }
        }
        QCOMPARE(botones, 1);
        QCOMPARE(spy.count(), 1);
        QCOMPARE(spy.at(0).at(0).toString(), QString("Peeling Químico Médico"));
        QCOMPARE(spy.at(0).at(1).toDouble(), 18000.0);
        QCOMPARE(spy.at(0).at(2).toInt(), 40);
    }

    void rf07_sin_coincidencias_deriva_a_whatsapp() {
        BuscadorWidget w;
        w.show();
        w.findChild<QLineEdit *>("txtBuscar")->setText("zzzzzz");
        QVERIFY(w.findChild<QFrame *>("frameWhatsApp")->isVisibleTo(&w));
    }

    // ---------- RF-12 / RF-10: buscar y cancelar mi turno ----------
    void rf12_buscar_por_dni_y_telefono() {
        BuscarTurnoWidget w;
        auto *txt = w.findChild<QLineEdit *>("txtDniTel");
        auto *btn = w.findChild<QPushButton *>("btnBuscar");

        txt->setText("38123456");
        btn->click();
        int cancelar = 0;
        for (auto *b : w.findChildren<QPushButton *>()) {
            if (b->text().contains("Cancelar Turno")) {
                ++cancelar;
            }
        }
        QCOMPARE(cancelar, 1);

        txt->setText("1144332211"); // teléfono de Mariana Fernández (Peeling Químico Médico)
        btn->click();
        bool encontroMariana = false;
        for (auto *l : w.findChildren<QLabel *>()) {
            if (l->text().contains("Peeling Químico Médico")) {
                encontroMariana = true;
            }
        }
        QVERIFY(encontroMariana);

        txt->setText("1100000000"); // teléfono válido pero sin turnos
        btn->click();
        bool sinResultados = false;
        for (auto *l : w.findChildren<QLabel *>()) {
            if (l->text().contains("No se encontraron turnos")) {
                sinResultados = true;
            }
        }
        QVERIFY(sinResultados);
    }

    // ---------- RF-11: recordatorio visible en el turno ----------
    void rf11_cada_turno_muestra_su_recordatorio() {
        BuscarTurnoWidget w;
        w.findChild<QLineEdit *>("txtDniTel")->setText("38123456");
        w.findChild<QPushButton *>("btnBuscar")->click();
        int recordatorios = 0;
        for (auto *l : w.findChildren<QLabel *>()) {
            if (l->text().contains("Recordatorio activo en sistema (RF-11)")) {
                ++recordatorios;
            }
        }
        QCOMPARE(recordatorios, 1);
    }

    void rf12_busqueda_invalida_muestra_aviso() {
        BuscarTurnoWidget w;
        auto *txt = w.findChild<QLineEdit *>("txtDniTel");
        txt->setText("123");
        int avisos = 0;
        cerrarDialogo(QMessageBox::Ok, &avisos);
        w.findChild<QPushButton *>("btnBuscar")->click();
        QCOMPARE(avisos, 1);

        // La máscara impide tipear letras
        txt->clear();
        QTest::keyClicks(txt, "38abc123456");
        QCOMPARE(txt->text(), QString("38123456"));
    }

    void rf10_cancelar_con_mas_de_24hs_reembolsa() {
        BuscarTurnoWidget w;
        QSignalSpy spy(&w, &BuscarTurnoWidget::turnoCancelado);
        w.findChild<QLineEdit *>("txtDniTel")->setText("38123456"); // turno en 3 días
        w.findChild<QPushButton *>("btnBuscar")->click();

        QPushButton *cancelar = nullptr;
        for (auto *b : w.findChildren<QPushButton *>()) {
            if (b->text().contains("Cancelar Turno")) {
                cancelar = b;
            }
        }
        QVERIFY(cancelar);
        cerrarDialogo(QMessageBox::Yes);   // confirmar
        QTimer::singleShot(300, []() { cerrarDialogo(QMessageBox::Ok); }); // aviso final
        cancelar->click();
        QCOMPARE(spy.count(), 1);

        bool reembolsada = false;
        for (auto *l : w.findChildren<QLabel *>()) {
            if (l->text().contains("Reembolsada (100%)")) {
                reembolsada = true;
            }
        }
        QVERIFY(reembolsada);
    }

    void rf10_cancelar_con_menos_de_24hs_no_reembolsa() {
        BuscarTurnoWidget w;
        // Turno de mañana a las 15:00 (Mariana): sus datos de prueba tienen DNI 40987654.
        // Para forzar menos de 24 hs se agrega un turno de hoy a una hora ya pasada o próxima.
        const QString hoy = QDate::currentDate().toString("dd/MM/yyyy");
        w.agregarTurnoDesdeFormulario("Ana Prueba", "30111222", "1166778899", "Peeling Químico Médico",
                                      hoy, "23:59", "Dra. Sofía Martínez", 5400.0);
        w.findChild<QLineEdit *>("txtDniTel")->setText("30111222");
        w.findChild<QPushButton *>("btnBuscar")->click();

        QPushButton *cancelar = nullptr;
        for (auto *b : w.findChildren<QPushButton *>()) {
            if (b->text().contains("Cancelar Turno")) {
                cancelar = b;
            }
        }
        QVERIFY(cancelar);
        cerrarDialogo(QMessageBox::Yes);
        QTimer::singleShot(300, []() { cerrarDialogo(QMessageBox::Ok); });
        cancelar->click();

        bool sinReembolso = false;
        for (auto *l : w.findChildren<QLabel *>()) {
            if (l->text().contains("Sin reembolso")) {
                sinReembolso = true;
            }
        }
        QVERIFY(sinReembolso);
    }
};

QTEST_MAIN(TestCliente)
#include "test_cliente.moc"
