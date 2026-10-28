// Pruebas automáticas de lo que se agregó en las Semanas 2 y 3 del apartado
// Gestión: reglas de reembolso, recordatorios, disponibilidad, modo
// contingencia, conexión a la base y pantallas nuevas. Corren sin base de
// datos y sin pantalla:  QT_QPA_PLATFORM=offscreen ./prueba_gestion
#include <QtTest>
#include <QApplication>
#include <QCalendarWidget>
#include <QDir>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QStackedWidget>
#include <QTableWidget>
#include <QTemporaryDir>
#include <QDateEdit>
#include <QTimeEdit>

#include "avisoconexion.h"
#include "basedatos.h"
#include "conexionapp.h"
#include "contingencia.h"
#include "datosprueba.h"
#include "disponibilidad.h"
#include "paginapacientes.h"
#include "paginaprotocolos.h"
#include "recordatorios.h"
#include "reembolso.h"
#include "ventanagestion.h"

namespace {

// Cierra el próximo cuadro de diálogo modal. Si `boton` es Yes, lo acepta.
void cerrarDialogo(QMessageBox::StandardButton boton, QString *texto = nullptr)
{
    QTimer::singleShot(30, [boton, texto]() {
        if (auto *mb = qobject_cast<QMessageBox *>(QApplication::activeModalWidget())) {
            if (texto)
                *texto = mb->text();
            if (QAbstractButton *b = mb->button(boton))
                b->click();
            else
                mb->close();
        } else {
            cerrarDialogo(boton, texto);   // todavía no apareció: reintenta
        }
    });
}

QDateTime en(int dias, int hora, const QDateTime &base)
{
    return QDateTime(base.date().addDays(dias), QTime(hora, 0));
}

}  // namespace

class PruebaGestion : public QObject
{
    Q_OBJECT

private slots:
    // ---- Reembolso (RF-10) ----
    void reembolso_masDe24HorasDevuelveTodo()
    {
        const QDateTime ahora(QDate(2026, 10, 20), QTime(10, 0));
        QCOMPARE(Reembolso::monto(7500, true, ahora.addSecs(25 * 3600), ahora), 7500);
    }
    void reembolso_exactamente24HorasNoAlcanza()
    {
        const QDateTime ahora(QDate(2026, 10, 20), QTime(10, 0));
        QVERIFY(!Reembolso::aTiempo(ahora.addSecs(24 * 3600), ahora));
        QCOMPARE(Reembolso::monto(7500, true, ahora.addSecs(24 * 3600), ahora), 0);
    }
    void reembolso_menosDe24HorasNoDevuelve()
    {
        const QDateTime ahora(QDate(2026, 10, 20), QTime(10, 0));
        QCOMPARE(Reembolso::monto(7500, true, ahora.addSecs(5 * 3600), ahora), 0);
    }
    void reembolso_senaSinPagarNoDevuelveNada()
    {
        const QDateTime ahora(QDate(2026, 10, 20), QTime(10, 0));
        QCOMPARE(Reembolso::monto(7500, false, ahora.addDays(3), ahora), 0);
    }

    // ---- Disponibilidad (RF-03) ----
    void disponibilidad_franjasQueSePisan()
    {
        const QDate dia = QDate::currentDate().addDays(3);
        const Franja a = { dia, QTime(9, 0), QTime(13, 0), true };
        QVERIFY(Disponibilidad::sePisan(a, { dia, QTime(12, 0), QTime(15, 0), true }));
        QVERIFY(Disponibilidad::sePisan(a, { dia, QTime(10, 0), QTime(11, 0), true }));
    }
    void disponibilidad_unaTerminaDondeEmpiezaLaOtraNoSePisan()
    {
        const QDate dia = QDate::currentDate().addDays(3);
        QVERIFY(!Disponibilidad::sePisan({ dia, QTime(9, 0), QTime(13, 0), true },
                                         { dia, QTime(13, 0), QTime(18, 0), true }));
    }
    void disponibilidad_otroDiaNoSePisa()
    {
        const QDate dia = QDate::currentDate().addDays(3);
        QVERIFY(!Disponibilidad::sePisan({ dia, QTime(9, 0), QTime(13, 0), true },
                                         { dia.addDays(1), QTime(9, 0), QTime(13, 0), true }));
    }
    void disponibilidad_puedeAgregarRechazaLoInvalido()
    {
        const QDate dia = QDate::currentDate().addDays(3);
        const QVector<Franja> existentes = { { dia, QTime(9, 0), QTime(13, 0), true } };
        QString error;
        QVERIFY(!Disponibilidad::puedeAgregar(existentes, { dia, QTime(12, 0), QTime(14, 0), true }, &error));
        QVERIFY(error.contains("superpone"));
        QVERIFY(!Disponibilidad::puedeAgregar(existentes, { dia, QTime(15, 0), QTime(14, 0), true }, &error));
        QVERIFY(error.contains("posterior"));
        QVERIFY(!Disponibilidad::puedeAgregar(existentes, { QDate::currentDate().addDays(-1), QTime(9, 0), QTime(10, 0), true }, &error));
        QVERIFY(error.contains("pasados"));
        QVERIFY(Disponibilidad::puedeAgregar(existentes, { dia, QTime(14, 0), QTime(18, 0), true }));
    }
    void disponibilidad_franjaDadaDeBajaNoBloquea()
    {
        const QDate dia = QDate::currentDate().addDays(3);
        const QVector<Franja> existentes = { { dia, QTime(9, 0), QTime(13, 0), false } };
        QVERIFY(Disponibilidad::puedeAgregar(existentes, { dia, QTime(10, 0), QTime(12, 0), true }));
    }

    // ---- Recordatorios (RF-11) ----
    void recordatorio_salen24HorasAntes()
    {
        const QDateTime ahora(QDate(2026, 10, 20), QTime(10, 0));
        const QDateTime turno(QDate(2026, 10, 25), QTime(9, 0));
        QCOMPARE(Recordatorios::momentoDeEnvio(turno, ahora), QDateTime(QDate(2026, 10, 24), QTime(9, 0)));
    }
    void recordatorio_siElMomentoYaPasoSaleEnseguida()
    {
        const QDateTime ahora(QDate(2026, 10, 20), QTime(20, 0));
        const QDateTime turno(QDate(2026, 10, 21), QTime(9, 0));   // mañana temprano
        QCOMPARE(Recordatorios::momentoDeEnvio(turno, ahora), ahora);
    }
    void recordatorio_enlaceDeWhatsApp()
    {
        const QString texto = "Hola María, turno";
        const QString enlace = Recordatorios::enlaceWhatsApp("11 5555-0102", texto);
        QVERIFY(enlace.startsWith("https://wa.me/5491155550102?text="));
        QVERIFY(enlace.contains("Hola%20Mar%C3%ADa"));
        QVERIFY(Recordatorios::enlaceWhatsApp("+54 9 11 5555-0102", texto).startsWith("https://wa.me/5491155550102"));
        QVERIFY(Recordatorios::enlaceWhatsApp("541155550102", texto).startsWith("https://wa.me/5491155550102"));
    }
    void recordatorio_canalSegunTelegram()
    {
        RegistroAvisos r;
        const QDateTime ahora(QDate(2026, 10, 20), QTime(10, 0));
        const QDateTime turno = ahora.addDays(5);
        QCOMPARE(r.programar("Ana Paz", "30111222", "1155550102", "Peeling", turno, ahora).canal,
                 CanalAviso::WhatsAppAsistido);
        QCOMPARE(r.programar("Ana Paz", "30111222", "1155550102", "Peeling", turno, ahora, true).canal,
                 CanalAviso::Telegram);
    }
    void recordatorio_estadosYAnulacion()
    {
        RegistroAvisos r;
        const QDateTime ahora(QDate(2026, 10, 20), QTime(10, 0));
        const QDateTime turno = ahora.addDays(5);
        r.programar("Ana Paz", "30111222", "1155550102", "Peeling", turno, ahora);
        r.programar("Lu Gil", "28444555", "1155550144", "Láser", turno.addDays(1), ahora);
        QCOMPARE(r.pendientesA(ahora).size(), 0);                    // todavía no es la hora
        QCOMPARE(r.pendientesA(turno).size(), 2);
        r.marcarEnviado(0, turno.addSecs(-3600));
        QCOMPARE(r.todos()[0].estado, EstadoAviso::Enviado);
        QCOMPARE(r.todos()[0].intentos, 1);
        r.marcarFallido(1, "sin WhatsApp");
        QCOMPARE(r.todos()[1].estado, EstadoAviso::Fallido);
        QCOMPARE(r.todos()[1].detalleError, QString("sin WhatsApp"));
        QCOMPARE(r.anularDeTurno("30111222", turno), 0);             // ya enviado: no se anula
        RegistroAvisos s;
        s.programar("Ana Paz", "30111222", "1155550102", "Peeling", turno, ahora);
        QCOMPARE(s.anularDeTurno("30111222", turno), 1);
        QCOMPARE(s.todos().size(), 0);
    }
    void recordatorio_indicesInvalidosNoRompen()
    {
        RegistroAvisos r;
        r.marcarEnviado(5, QDateTime::currentDateTime());
        r.marcarFallido(-1, "x");
        QCOMPARE(r.todos().size(), 0);
    }

    // ---- Modo contingencia (RNF-09) ----
    void contingencia_guardaYRecuperaTurnos()
    {
        QTemporaryDir carpeta;
        const QString archivo = carpeta.filePath("datos/pendientes.json");   // la subcarpeta no existe
        Contingencia c(archivo);
        QCOMPARE(c.cantidad(), 0);
        TurnoPendiente t;
        t.paciente = "María Sosa";
        t.dni = "30111222";
        t.telefono = "1155550102";
        t.protocolo = "Peeling químico";
        t.inicio = QDateTime(QDate(2026, 11, 3), QTime(9, 0));
        t.sena = 12000;
        t.senaPagada = true;
        t.origen = "Gestión";
        QVERIFY(c.guardar(t));
        t.paciente = "Carla Gómez";
        QVERIFY(c.guardar(t));
        QCOMPARE(c.cantidad(), 2);

        Contingencia otra(archivo);      // como si se reabriera la app
        const QVector<TurnoPendiente> leidos = otra.pendientes();
        QCOMPARE(leidos.size(), 2);
        QCOMPARE(leidos[0].paciente, QString("María Sosa"));
        QCOMPARE(leidos[0].inicio, t.inicio);
        QCOMPARE(leidos[0].sena, 12000);
        QVERIFY(leidos[0].senaPagada);
        QVERIFY(leidos[0].guardado.isValid());
        QVERIFY(otra.vaciar());
        QCOMPARE(otra.cantidad(), 0);
    }
    void contingencia_archivoRoto()
    {
        QTemporaryDir carpeta;
        QFile f(carpeta.filePath("pendientes.json"));
        QVERIFY(f.open(QIODevice::WriteOnly));
        f.write("esto no es json {{{");
        f.close();
        QCOMPARE(Contingencia(carpeta.filePath("pendientes.json")).cantidad(), 0);
    }

    // ---- Conexión a la base ----
    void basedatos_escapaLosDatos()
    {
        QCOMPARE(BaseDatos::literal(QString("O'Brien")), QString("'O\\'Brien'"));
        QCOMPARE(BaseDatos::literal(QString("a\\b")), QString("'a\\\\b'"));
        QCOMPARE(BaseDatos::literal(QVariant()), QString("NULL"));
        QCOMPARE(BaseDatos::literal(QVariant::fromValue(QString())), QString("''"));   // vacío no es NULL
        QCOMPARE(BaseDatos::literal(42), QString("42"));
        QCOMPARE(BaseDatos::literal(true), QString("1"));
        QCOMPARE(BaseDatos::literal(QDate(2026, 10, 27)), QString("'2026-10-27'"));
        QCOMPARE(BaseDatos::literal(QDateTime(QDate(2026, 10, 27), QTime(9, 30))), QString("'2026-10-27 09:30:00'"));
        // un intento de inyección queda como texto
        QCOMPARE(BaseDatos::literal(QString("x'); DROP TABLE paciente; --")),
                 QString("'x\\'); DROP TABLE paciente; --'"));
    }
    void basedatos_mensajesClaros()
    {
        QVERIFY(BaseDatos::mensajeDeError(2003, "x").contains("No se pudo conectar"));
        QVERIFY(BaseDatos::mensajeDeError(1045, "x").contains("usuario o la contraseña"));
        QVERIFY(BaseDatos::mensajeDeError(9999, "texto original").contains("texto original"));
    }
    void basedatos_sinConfiguracionAvisa()
    {
        BaseDatos base{ConfigBD()};
        QVERIFY(!base.conectar());
        QVERIFY(!base.conectado());
        QVERIFY(!base.ultimoError().isEmpty());
        const Resultado r = base.llamar("cualquier_sp", { 1, "a" });
        QVERIFY(!r.ok);
        QVERIFY(!r.error.isEmpty());
    }
    void basedatos_servidorInalcanzable()
    {
        ConfigBD c;
        c.host = "127.0.0.1";
        c.puerto = 1;            // no hay nada escuchando
        c.usuario = "x";
        c.timeoutSeg = 1;
        BaseDatos base(c);
        QVERIFY(!base.conectar());
        QVERIFY(!base.ultimoError().isEmpty());
        if (BaseDatos::compiladoConMysql())
            QVERIFY2(base.ultimoError().contains("No se pudo conectar"), qPrintable(base.ultimoError()));
    }
    void basedatos_configDesdeEntorno()
    {
        qputenv("DERMALIA_DB_HOST", "mysql.ejemplo.net");
        qputenv("DERMALIA_DB_PORT", "27700");
        qputenv("DERMALIA_DB_USER", "avnadmin");
        qputenv("DERMALIA_DB_SSL", "1");
        const ConfigBD c = ConfigBD::desdeEntorno("no-existe.ini");
        QCOMPARE(c.host, QString("mysql.ejemplo.net"));
        QCOMPARE(c.puerto, 27700u);
        QCOMPARE(c.usuario, QString("avnadmin"));
        QVERIFY(c.ssl);
        QVERIFY(c.completa());
        for (const char *v : { "DERMALIA_DB_HOST", "DERMALIA_DB_PORT", "DERMALIA_DB_USER", "DERMALIA_DB_SSL" })
            qunsetenv(v);
        const ConfigBD vacia = ConfigBD::desdeEntorno("no-existe.ini");
        QCOMPARE(vacia.host, QString("127.0.0.1"));
        QVERIFY(!vacia.completa());   // sin usuario no se intenta conectar
    }

    // ---- Franja de aviso ----
    void franja_sinConexionYRecuperada()
    {
        AvisoConexion franja;
        QVERIFY(!franja.isVisible() || true);
        franja.mostrarSinConexion("No se pudo conectar.", 2);
        QVERIFY(franja.sinConexion());
        QVERIFY(franja.texto().contains("modo contingencia"));
        QVERIFY(franja.texto().contains("2 turnos"));
        franja.mostrarConectado(0);
        QVERIFY(!franja.sinConexion());
        QVERIFY(franja.isHidden());
        franja.mostrarConectado(3);
        QVERIFY(!franja.isHidden());
        QVERIFY(franja.texto().contains("Conexión recuperada"));
    }

    // ---- Formularios ----
    void protocolo_preciosYDuracionesInvalidas()
    {
        const QVector<Protocolo> existentes = DatosPrueba::protocolos();
        QVERIFY(PaginaProtocolos::revisar("Hidrafacial", "30000", "50", existentes, -1).isEmpty());
        QVERIFY(PaginaProtocolos::revisar("Hidrafacial", "30.000,50", "50", existentes, -1).isEmpty());
        QVERIFY(PaginaProtocolos::revisar("Hidrafacial", "0", "50", existentes, -1).isEmpty());   // gratis es válido
        QVERIFY(!PaginaProtocolos::revisar("Hidrafacial", "-1", "50", existentes, -1).isEmpty());
        QVERIFY(!PaginaProtocolos::revisar("Hidrafacial", "abc", "50", existentes, -1).isEmpty());
        QVERIFY(!PaginaProtocolos::revisar("Hidrafacial", "", "50", existentes, -1).isEmpty());
        QVERIFY(!PaginaProtocolos::revisar("Hidrafacial", "30000", "0", existentes, -1).isEmpty());
        QVERIFY(!PaginaProtocolos::revisar("Hidrafacial", "30000", "-5", existentes, -1).isEmpty());
        QVERIFY(!PaginaProtocolos::revisar("Hidrafacial", "30000", "", existentes, -1).isEmpty());
        QVERIFY(!PaginaProtocolos::revisar("ab", "30000", "50", existentes, -1).isEmpty());
    }
    void protocolo_nombreRepetido()
    {
        const QVector<Protocolo> existentes = DatosPrueba::protocolos();
        const QString repetido = existentes[0].nombre;
        QVERIFY(!PaginaProtocolos::revisar(repetido.toUpper(), "30000", "50", existentes, -1).isEmpty());
        QVERIFY(PaginaProtocolos::revisar(repetido, "30000", "50", existentes, 0).isEmpty());   // editándose a sí mismo
    }
    void paciente_validaciones()
    {
        const QVector<Paciente> existentes = DatosPrueba::pacientes();
        const QDate hoy = QDate(2026, 10, 27);
        const Paciente ok = { "Ana Paz", "35111222", "1166667777", "", QDate(1992, 5, 5) };
        QVERIFY(PaginaPacientes::revisar(ok, existentes, -1, hoy).isEmpty());

        Paciente p = ok;
        p.dni = existentes[0].dni;   // DNI repetido
        QVERIFY(PaginaPacientes::revisar(p, existentes, -1, hoy).join(" ").contains("Ya hay una paciente"));
        QVERIFY(PaginaPacientes::revisar(p, existentes, 0, hoy).isEmpty());   // es ella misma

        p = ok;
        p.email = "sin-arroba";
        QVERIFY(!PaginaPacientes::revisar(p, existentes, -1, hoy).isEmpty());
        p.email = "ana@correo.com";
        QVERIFY(PaginaPacientes::revisar(p, existentes, -1, hoy).isEmpty());

        p = ok;
        p.nacimiento = hoy.addDays(1);
        QVERIFY(!PaginaPacientes::revisar(p, existentes, -1, hoy).isEmpty());
        p = ok;
        p.nombre = "Ana123";
        p.dni = "12";
        p.telefono = "11";
        QCOMPARE(PaginaPacientes::revisar(p, existentes, -1, hoy).size(), 3);
    }
    void paciente_busqueda()
    {
        const QVector<Paciente> pacientes = DatosPrueba::pacientes();
        QCOMPARE(PaginaPacientes::buscar(pacientes, "").size(), pacientes.size());
        QCOMPARE(PaginaPacientes::buscar(pacientes, "sosa"), QVector<int>({ 0 }));
        QCOMPARE(PaginaPacientes::buscar(pacientes, "33222111"), QVector<int>({ 1 }));
        QCOMPARE(PaginaPacientes::buscar(pacientes, "1155550144"), QVector<int>({ 2 }));
        QCOMPARE(PaginaPacientes::buscar(pacientes, "zzz").size(), 0);
    }

    // ---- La ventana completa ----
    void ventana_tieneLasPantallasNuevasYLaFranja()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        auto *menu = w.findChild<QListWidget *>("menu");
        auto *paginas = w.findChild<QStackedWidget *>("paginas");
        QVERIFY(menu && paginas);
        QCOMPARE(menu->count(), 8);
        QCOMPARE(paginas->count(), 10);
        for (int fila = 0; fila < menu->count(); ++fila) {   // cada opción del menú abre su pantalla
            menu->setCurrentRow(fila);
            QVERIFY2(paginas->currentWidget() != nullptr, qPrintable(menu->item(fila)->text()));
        }
        menu->setCurrentRow(4);
        QCOMPARE(paginas->currentWidget()->objectName(), QString("pagProtocolos"));
        menu->setCurrentRow(7);
        QCOMPARE(paginas->currentWidget()->objectName(), QString("pagAvisos"));

        auto *franja = w.findChild<AvisoConexion *>("avisoConexion");
        QVERIFY(franja);
        QVERIFY(!w.conexionApp()->probar());   // sin configurar: no hay base
        QVERIFY(franja->sinConexion());
        QVERIFY(!franja->isHidden());
    }

    void ventana_cancelarConMasDe24HorasDevuelveLaSena()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        auto *tabla = w.findChild<QTableWidget *>("tablaTurnos");
        auto *buscar = w.findChild<QLineEdit *>("editBuscar");
        auto *cancelar = w.findChild<QPushButton *>("btnCancelarTurno");
        QVERIFY(tabla && buscar && cancelar);
        QVERIFY(!cancelar->isEnabled());                       // nada elegido
        const int avisosAntes = w.findChild<QTableWidget *>("tablaAvisos")->rowCount();
        QVERIFY(avisosAntes >= 3);

        buscar->setText("30111222");                           // María Sosa
        QTest::keyClick(buscar, Qt::Key_Return);
        QCOMPARE(tabla->rowCount(), 2);
        tabla->selectRow(0);                                   // el realizado
        QVERIFY(!cancelar->isEnabled());                       // un turno realizado no se cancela
        tabla->selectRow(1);                                   // el confirmado con seña pagada
        QVERIFY(cancelar->isEnabled());
        QVERIFY(w.findChild<QLabel *>("lblRecordatorio")->text().contains("Recordatorio por"));

        QString preguntado;
        cerrarDialogo(QMessageBox::Yes, &preguntado);
        QTimer::singleShot(100, []() { cerrarDialogo(QMessageBox::Ok); });
        cancelar->click();
        QVERIFY2(preguntado.contains("se devuelve la seña completa"), qPrintable(preguntado));

        int cancelados = 0;
        for (const Turno &t : w.listaTurnos()) {
            if (t.dni == "30111222" && t.estado == EstadoTurno::Cancelado) {
                ++cancelados;
                QVERIFY(t.reembolsado > 0);
                QCOMPARE(t.reembolsado, t.sena);
            }
        }
        QCOMPARE(cancelados, 1);
        QVERIFY(tabla->item(1, 6)->text().contains("reembolsada"));
        QVERIFY(w.findChild<QLabel *>("lblRecordatorio")->text().contains("cancelado"));
        // CP-11: al cancelar, el recordatorio pendiente de ese turno desaparece
        QCOMPARE(w.findChild<QTableWidget *>("tablaAvisos")->rowCount(), avisosAntes - 1);
    }

    void ventana_cancelarSinSenaNoDevuelveNada()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        auto *tabla = w.findChild<QTableWidget *>("tablaTurnos");
        auto *buscar = w.findChild<QLineEdit *>("editBuscar");
        buscar->setText("33222111");                           // Carla Gómez: seña sin pagar
        QTest::keyClick(buscar, Qt::Key_Return);
        tabla->selectRow(0);
        QString preguntado;
        cerrarDialogo(QMessageBox::Yes, &preguntado);
        QTimer::singleShot(100, []() { cerrarDialogo(QMessageBox::Ok); });
        w.findChild<QPushButton *>("btnCancelarTurno")->click();
        QVERIFY2(preguntado.contains("no estaba pagada"), qPrintable(preguntado));
        for (const Turno &t : w.listaTurnos())
            if (t.dni == "33222111")
                QCOMPARE(t.reembolsado, 0);
    }

    void ventana_cancelarElegirNoDejaTodoIgual()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        auto *tabla = w.findChild<QTableWidget *>("tablaTurnos");
        auto *buscar = w.findChild<QLineEdit *>("editBuscar");
        buscar->setText("33222111");
        QTest::keyClick(buscar, Qt::Key_Return);
        tabla->selectRow(0);
        cerrarDialogo(QMessageBox::No);
        w.findChild<QPushButton *>("btnCancelarTurno")->click();
        for (const Turno &t : w.listaTurnos())
            if (t.dni == "33222111")
                QVERIFY(t.estado == EstadoTurno::Confirmado);
    }

    // ---- CP-08: alta y baja de un protocolo desde la pantalla ----
    void ventana_altaYBajaDeProtocolo()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        auto *pagina = w.findChild<QWidget *>("pagProtocolos");
        auto *lista = w.findChild<QListWidget *>("listaProtocolos");
        auto *tabla = pagina->findChild<QTableWidget *>("tablaProtocolos");
        QCOMPARE(lista->count(), 4);
        QCOMPARE(tabla->rowCount(), 4);

        pagina->findChild<QLineEdit *>("editNombre")->setText("Hidrafacial");
        pagina->findChild<QLineEdit *>("editPrecio")->setText("-1");
        pagina->findChild<QLineEdit *>("editDuracion")->setText("50");
        QString texto;
        cerrarDialogo(QMessageBox::Ok, &texto);
        pagina->findChild<QPushButton *>("btnGuardar")->click();
        QVERIFY2(texto.contains("no puede ser negativo"), qPrintable(texto));
        QCOMPARE(tabla->rowCount(), 4);                         // no se agregó nada

        pagina->findChild<QLineEdit *>("editPrecio")->setText("30000");
        cerrarDialogo(QMessageBox::Ok);
        pagina->findChild<QPushButton *>("btnGuardar")->click();
        QCOMPARE(tabla->rowCount(), 5);
        QCOMPARE(lista->count(), 5);                            // ya se ofrece al cargar un turno
        QVERIFY(lista->item(4)->text().contains("Hidrafacial"));

        // baja: sale de "Cargar turno" pero sigue en la pantalla de protocolos
        tabla->selectRow(4);
        cerrarDialogo(QMessageBox::Yes);
        pagina->findChild<QPushButton *>("btnEstado")->click();
        QCOMPARE(tabla->rowCount(), 5);
        QCOMPARE(tabla->item(4, 5)->text(), QString("De baja"));
        QCOMPARE(lista->count(), 4);
    }

    // ---- CP-09: franjas de disponibilidad desde la pantalla ----
    void ventana_franjasNoSePisan()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"));
        auto *pagina = w.findChild<QWidget *>("pagProfesionales");
        auto *tabla = pagina->findChild<QTableWidget *>("tablaFranjas");
        const int antes = tabla->rowCount();                    // 5 franjas de 9 a 13
        QVERIFY(antes > 0);

        const QDate dia = QDate::currentDate().addDays(60);
        pagina->findChild<QDateEdit *>("editDia")->setDate(dia);
        pagina->findChild<QTimeEdit *>("editDesde")->setTime(QTime(9, 0));
        pagina->findChild<QTimeEdit *>("editHasta")->setTime(QTime(13, 0));
        pagina->findChild<QPushButton *>("btnFranja")->click();   // se agrega sin cartel
        QCOMPARE(tabla->rowCount(), antes + 1);

        pagina->findChild<QTimeEdit *>("editDesde")->setTime(QTime(12, 0));   // se pisa con 9 a 13
        pagina->findChild<QTimeEdit *>("editHasta")->setTime(QTime(14, 0));
        QString texto;
        cerrarDialogo(QMessageBox::Ok, &texto);
        pagina->findChild<QPushButton *>("btnFranja")->click();
        QVERIFY2(texto.contains("superpone"), qPrintable(texto));
        QCOMPARE(tabla->rowCount(), antes + 1);

        pagina->findChild<QTimeEdit *>("editDesde")->setTime(QTime(13, 0));   // justo después: se acepta
        pagina->findChild<QTimeEdit *>("editHasta")->setTime(QTime(18, 0));
        pagina->findChild<QPushButton *>("btnFranja")->click();
        QCOMPARE(tabla->rowCount(), antes + 2);
    }

    // ---- CP-10 y CP-11: cargar un turno sin base y programar su aviso ----
    void ventana_turnoSinConexionQuedaGuardadoYConAviso()
    {
        QTemporaryDir carpeta;
        const QString archivo = carpeta.filePath("p.json");
        {
            VentanaGestion w(nullptr, archivo);
            w.conexionApp()->probar();                          // sin configurar: no hay base
            auto *tablaAvisos = w.findChild<QTableWidget *>("tablaAvisos");
            const int avisosAntes = tablaAvisos->rowCount();

            w.findChild<QLineEdit *>("editPaciente")->setText("Ana Paz");
            w.findChild<QLineEdit *>("editDni")->setText("35111222");
            w.findChild<QLineEdit *>("editTelefono")->setText("11 6666-7777");
            auto *protocolos = w.findChild<QListWidget *>("listaProtocolos");
            protocolos->setCurrentRow(0);
            protocolos->item(0)->setSelected(true);
            w.findChild<QPushButton *>("btnContinuar1")->click();

            QDate dia = QDate::currentDate().addDays(20);        // un día de atención
            if (dia.dayOfWeek() == Qt::Sunday)
                dia = dia.addDays(1);
            w.findChild<QCalendarWidget *>("calendario")->setSelectedDate(dia);
            auto *horarios = w.findChild<QListWidget *>("listaHorarios");
            QVERIFY(horarios->count() > 0);
            horarios->setCurrentRow(0);
            horarios->item(0)->setSelected(true);
            w.findChild<QPushButton *>("btnContinuar2")->click();

            w.findChild<QPushButton *>("btnSena")->setChecked(true);
            QString texto;
            cerrarDialogo(QMessageBox::Ok, &texto);
            w.findChild<QPushButton *>("btnConfirmar")->click();
            QVERIFY2(texto.contains("guardó en este equipo"), qPrintable(texto));
            QVERIFY2(texto.contains("SIM-"), qPrintable(texto));          // seña simulada aprobada

            QCOMPARE(tablaAvisos->rowCount(), avisosAntes + 1);           // aviso 24 h antes
            QVERIFY(w.findChild<AvisoConexion *>("avisoConexion")->texto().contains("1 turno guardado"));
        }
        // "reabrir la aplicación": el turno sigue guardado en el equipo
        Contingencia c(archivo);
        QCOMPARE(c.cantidad(), 1);
        const TurnoPendiente t = c.pendientes().first();
        QCOMPARE(t.dni, QString("35111222"));
        QCOMPARE(t.telefono, QString("1166667777"));
        QVERIFY(t.senaPagada);
        QCOMPARE(t.origen, QString("Gestión"));
    }
};

QTEST_MAIN(PruebaGestion)
#include "prueba_gestion.moc"
