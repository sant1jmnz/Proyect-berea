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
#include <QTimeEdit>
#include <QCalendarWidget>
#include <QCheckBox>
#include <QComboBox>
#include <QDateEdit>

#include "avisoconexion.h"
#include "basedatos.h"
#include "conexionapp.h"
#include "datosbase.h"
#include "repositorio.h"
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
        QLocale::setDefault(QLocale(QLocale::Spanish, QLocale::Argentina));   // como main.cpp: $30.000
    }

    // Con la base conectada, las pantallas muestran los datos de la base.
    void ventana_leeLosDatosDeLaBase()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"), true);
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

    // Pantallas nuevas: cupones de una paciente, venta de una tarjeta de regalo con su saldo
    // y la lista de consultas previas de cirugía.
    void ventana_cuponesTarjetasYConsultasPrevias()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"), true);
        QTest::qWait(1500);
        if (!w.usaBase())
            QSKIP("Sin base de datos o sin ingreso (definir DERMALIA_DB_USER, etc.).");

        // Cupones: la paciente 36861630 tiene cupones en los datos de ejemplo.
        auto *cupones = w.findChild<QWidget *>("pagCupones");
        cupones->findChild<QLineEdit *>("editDniCupon")->setText("36861630");
        cupones->findChild<QPushButton *>("btnBuscarCupones")->click();
        QVERIFY(cupones->findChild<QTableWidget *>("tablaCupones")->rowCount() >= 3);

        // Tarjeta de regalo: se vende y queda consultada con su saldo completo.
        auto *tarjetas = w.findChild<QWidget *>("pagTarjetas");
        tarjetas->findChild<QLineEdit *>("editMontoTarjeta")->setText("30000");
        tarjetas->findChild<QLineEdit *>("editCompradorTarjeta")->setText("Ana Regalo");
        responderDialogos({});
        tarjetas->findChild<QPushButton *>("btnVenderTarjeta")->click();
        QVERIFY(tarjetas->findChild<QLineEdit *>("editCodigoTarjeta")->text().startsWith("GC-"));
        const QString saldo = tarjetas->findChild<QLabel *>("lblSaldoTarjeta")->text();
        QVERIFY2(saldo.contains("30.000"), qPrintable(saldo));

        // Un monto fuera de rango no se vende.
        tarjetas->findChild<QLineEdit *>("editMontoTarjeta")->setText("100");
        tarjetas->findChild<QLineEdit *>("editCompradorTarjeta")->setText("Ana Regalo");
        responderDialogos({});
        tarjetas->findChild<QPushButton *>("btnVenderTarjeta")->click();
        QCOMPARE(tarjetas->findChild<QLineEdit *>("editMontoTarjeta")->text(), QString("100"));   // no se limpió

        // Consultas previas: hay evaluaciones de cirugía en los datos de ejemplo.
        auto *evaluaciones = w.findChild<QWidget *>("pagEvaluaciones");
        QVERIFY(evaluaciones->findChild<QTableWidget *>("tablaEvaluaciones")->rowCount() >= 20);
        evaluaciones->findChild<QCheckBox *>("checkPendientes")->setChecked(true);
        const int pendientes = evaluaciones->findChild<QTableWidget *>("tablaEvaluaciones")->rowCount();
        QVERIFY(pendientes < 20);
        for (int fila = 0; fila < pendientes; ++fila)
            QCOMPARE(evaluaciones->findChild<QTableWidget *>("tablaEvaluaciones")->item(fila, 4)->text(), QString("Pendiente"));
    }

    // Modo contingencia (RNF-09): un turno guardado sin conexión se envía a la base cuando vuelve.
    void contingencia_sincronizaAlVolverLaConexion()
    {
        BaseDatos base(ConfigBD::desdeEntorno());
        if (!base.conectar())
            QSKIP("Sin base de datos (definir DERMALIA_DB_USER, etc.).");
        Repositorio repo(base);

        // Un horario libre de una limpieza facial (protocolo 1), al menos 2 días adelante.
        HorarioLibre libre;
        for (int d = 2; d <= 30 && libre.idProfesional == 0; ++d) {
            const QVector<HorarioLibre> horarios = repo.horariosLibres(QDate::currentDate().addDays(d), { 1 });
            if (!horarios.isEmpty())
                libre = horarios.first();
        }
        if (libre.idProfesional == 0)
            QSKIP("No hay horarios libres en los próximos 30 días.");

        QTemporaryDir carpeta;
        AvisoConexion franja;
        ConexionApp conexion(&franja, ConfigBD::desdeEntorno(), carpeta.filePath("pendientes.json"));
        // María Sosa (30111222) y un protocolo del catálogo, guardados como si no hubiera habido conexión.
        TurnoPendiente t;
        t.paciente = "María Sosa";
        t.dni = "30111222";
        t.telefono = "1155550102";
        t.protocolo = "Limpieza facial profunda";
        t.inicio = libre.inicio;
        t.sena = 27000;
        t.senaPagada = true;
        t.origen = "Gestión";
        QVERIFY(conexion.guardarEnContingencia(t));
        QCOMPARE(conexion.contingencia().cantidad(), 1);

        QVERIFY(conexion.probar());   // vuelve la conexión: se sincroniza
        QCOMPARE(conexion.contingencia().cantidad(), 0);
        bool encontrado = false;
        for (const TurnoBD &turno : repo.buscarTurnos("30111222")) {
            if (turno.inicio == libre.inicio && turno.estado == "confirmado") {
                encontrado = true;
                repo.cancelarTurno(turno.id, "gestion");   // limpieza
            }
        }
        QVERIFY(encontrado);
    }

    // La pantalla Reportes llama a los stored procedures de reportes y de auditoría.
    void ventana_reportesYAuditoria()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"), true);
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
        VentanaGestion w(nullptr, carpeta.filePath("p.json"), true);
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

    // La Terminal (otro programa) reserva y después se cancela en la base: Gestión,
    // abierta al mismo tiempo, lo muestra sola en pocos segundos, sin tocar nada.
    void ventana_seActualizaSolaConLosCambiosDeLaBase()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"), true);
        QTest::qWait(1500);
        if (!w.usaBase())
            QSKIP("Sin base de datos o sin ingreso (definir DERMALIA_DB_USER, etc.).");
        BaseDatos base(ConfigBD::desdeEntorno());
        QVERIFY(base.conectar());
        Repositorio repo(base);

        // Un horario libre del primer protocolo activo, al menos 3 días adelante.
        QVector<Protocolo> catalogo;
        QString error;
        QVERIFY(DatosBase::cargarProtocolos(repo, catalogo, &error));
        int idProtocolo = 0;
        HorarioLibre libre;
        for (const Protocolo &p : catalogo) {
            if (!p.activo)
                continue;
            for (int d = 3; d <= 30 && idProtocolo == 0; ++d) {
                const QVector<HorarioLibre> lista = repo.horariosLibres(QDate::currentDate().addDays(d), { p.id });
                if (!lista.isEmpty()) {
                    idProtocolo = p.id;
                    libre = lista.first();
                }
            }
            if (idProtocolo != 0)
                break;
        }
        if (idProtocolo == 0)
            QSKIP("No hay horarios libres en los próximos 30 días.");

        const QString dni = QString::number(60000000 + int(QRandomGenerator::global()->bounded(9999999)));
        const Respuesta paciente = repo.altaPaciente(dni, "Desde", "Terminal", QDate(1993, 8, 9), QString(),
                                                     "1166665555", "terminal");
        QVERIFY2(paciente.ok, qPrintable(paciente.mensaje));
        const Respuesta turno = repo.altaTurno(paciente.id, libre.idProfesional, libre.inicio, { idProtocolo }, "terminal");
        QVERIFY2(turno.ok, qPrintable(turno.mensaje));

        // Aparece en la tabla de turnos de Gestión sin buscar nada.
        auto *tabla = w.findChild<QTableWidget *>("tablaTurnos");
        auto filaDelDni = [&] {
            for (int f = 0; f < tabla->rowCount(); ++f)
                if (tabla->item(f, 1) && tabla->item(f, 1)->text() == dni)
                    return f;
            return -1;
        };
        QTRY_VERIFY_WITH_TIMEOUT(filaDelDni() >= 0, 8000);

        // Se cancela desde la Terminal: el estado cambia solo en Gestión.
        QVERIFY(repo.cancelarTurno(turno.id, "terminal").ok);
        QTRY_COMPARE_WITH_TIMEOUT(tabla->item(filaDelDni(), 5)->text(), QString("Cancelado"), 8000);
    }

    // Cada pestaña que carga datos los deja en la base (no solo en la pantalla):
    // Protocolos (alta y cambio de precio), Pacientes, Profesionales (franja) y Avisos.
    void ventana_cadaPestaniaGuardaEnLaBase()
    {
        QTemporaryDir carpeta;
        VentanaGestion w(nullptr, carpeta.filePath("p.json"), true);
        QTest::qWait(1500);
        if (!w.usaBase())
            QSKIP("Sin base de datos o sin ingreso (definir DERMALIA_DB_USER, etc.).");
        BaseDatos base(ConfigBD::desdeEntorno());
        QVERIFY(base.conectar());
        Repositorio repo(base);
        QString letras;
        for (int i = 0; i < 6; ++i)
            letras += QChar('a' + QRandomGenerator::global()->bounded(26));

        // Protocolos: alta y después cambio de precio.
        QWidget *protocolos = w.findChild<QWidget *>("pagProtocolos");
        const QString nombre = "Prueba " + letras;
        protocolos->findChild<QLineEdit *>("editNombre")->setText(nombre);
        protocolos->findChild<QLineEdit *>("editPrecio")->setText("50000");
        protocolos->findChild<QLineEdit *>("editDuracion")->setText("45");
        responderDialogos({});
        protocolos->findChild<QPushButton *>("btnGuardar")->click();
        QVector<ProtocoloBD> enLaBase = repo.listarProtocolos(nombre);
        QCOMPARE(enLaBase.size(), 1);
        QCOMPARE(enLaBase.first().precio, 50000);
        protocolos->findChild<QLineEdit *>("editPrecio")->setText("60000");
        responderDialogos({});
        protocolos->findChild<QPushButton *>("btnGuardar")->click();
        enLaBase = repo.listarProtocolos(nombre);
        QCOMPARE(enLaBase.first().precio, 60000);

        // Pacientes: alta.
        QWidget *pacientes = w.findChild<QWidget *>("pagPacientes");
        const QString dni = QString::number(50000000 + int(QRandomGenerator::global()->bounded(9999999)));
        pacientes->findChild<QLineEdit *>("editNombrePaciente")->setText("Paciente Pestania");
        pacientes->findChild<QLineEdit *>("editDniPaciente")->setText(dni);
        pacientes->findChild<QLineEdit *>("editTelefonoPaciente")->setText("1133332222");
        pacientes->findChild<QDateEdit *>("editNacimientoPaciente")->setDate(QDate(1988, 4, 12));
        responderDialogos({});
        pacientes->findChild<QPushButton *>("btnGuardarPaciente")->click();
        bool pacienteGuardada = false;
        for (const QVariantMap &fila : repo.buscarPaciente(dni).filas)
            pacienteGuardada = pacienteGuardada || fila.value("dni").toString() == dni;
        QVERIFY(pacienteGuardada);

        // Profesionales: una franja de atención nueva.
        QWidget *profesionales = w.findChild<QWidget *>("pagProfesionales");
        profesionales->findChild<QListWidget *>("listaProfesionales")->setCurrentRow(0);
        const QDate dia = QDate::currentDate().addDays(200 + QRandomGenerator::global()->bounded(300));
        profesionales->findChild<QDateEdit *>("editDia")->setDate(dia);
        profesionales->findChild<QTimeEdit *>("editDesde")->setTime(QTime(10, 0));
        profesionales->findChild<QTimeEdit *>("editHasta")->setTime(QTime(12, 0));
        profesionales->findChild<QPushButton *>("btnFranja")->click();   // no muestra ningún cartel si sale bien
        bool franjaGuardada = false;
        for (const QVariantMap &fila : repo.listarDisponibilidad(dia).filas)
            franjaGuardada = franjaGuardada || (fila.value("fecha").toString() == dia.toString("yyyy-MM-dd")
                                                && fila.value("hora_inicio").toString() == "10:00:00");
        QVERIFY(franjaGuardada);

        // Avisos: un recordatorio pendiente se marca como fallido con un motivo.
        QWidget *avisos = w.findChild<QWidget *>("pagAvisos");
        auto *tablaAvisos = avisos->findChild<QTableWidget *>("tablaAvisos");
        int pendiente = -1;
        for (int f = 0; f < tablaAvisos->rowCount() && pendiente < 0; ++f)
            if (tablaAvisos->item(f, 2)->text() == "Pendiente")
                pendiente = f;
        if (pendiente >= 0) {
            tablaAvisos->selectRow(pendiente);
            const QString motivo = "Prueba de la pestania " + letras;
            responderDialogos({ motivo });
            for (QPushButton *b : avisos->findChildren<QPushButton *>())
                if (b->text() == "Marcar como fallido")
                    b->click();
            bool avisoGuardado = false;
            const QDate hoy = QDate::currentDate();
            for (const QVariantMap &fila : repo.listarNotificaciones(hoy.addDays(-90), hoy.addDays(90)).filas)
                avisoGuardado = avisoGuardado || fila.value("detalle_error").toString() == motivo;
            QVERIFY(avisoGuardado);
        }
    }
};

QTEST_MAIN(PruebaGestionBase)
#include "prueba_gestion_base.moc"
