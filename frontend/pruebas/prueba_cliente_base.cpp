// Prueba de la terminal (dermalia_cliente) conectada a la base real: catálogo de la base,
// horarios libres, reserva de una paciente nueva con seña, búsqueda por DNI y
// cancelación. Necesita MySQL con la base cargada (backend/) y DERMALIA_DB_HOST, _USER, _PASS.
// Sin base, se saltea. ATENCIÓN: escribe en la base (usar una de pruebas).
//   QT_QPA_PLATFORM=offscreen DERMALIA_DB_USER=root DERMALIA_DB_PASS=... ./prueba_cliente_base
#include <QtTest>
#include <QApplication>
#include <QCalendarWidget>
#include <QDateEdit>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QRandomGenerator>
#include <QTemporaryDir>

#include "basedatos.h"
#include "datosbase.h"
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
        QVERIFY2(confirmado.contains("SIM-"), qPrintable(confirmado));   // seña registrada

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

    // Gestión (u otra PC) ocupa un horario y cancela turnos en la base: la terminal,
    // abierta al mismo tiempo, lo muestra sola en pocos segundos, sin tocar nada.
    void terminal_seActualizaSolaConLosCambiosDeLaBase()
    {
        BaseDatos base(ConfigBD::desdeEntorno());
        if (!base.conectar())
            QSKIP("Sin base de datos (definir DERMALIA_DB_USER, etc.).");
        Repositorio repo(base);

        VentanaCliente w(nullptr, carpeta.filePath("local2.json"), carpeta.filePath("pendientes2.json"));
        w.show();
        QTRY_VERIFY_WITH_TIMEOUT(w.usaBase(), 5000);

        auto *protocolos = w.findChild<QListWidget *>("listaProtocolos");
        protocolos->setCurrentRow(0);
        protocolos->item(0)->setSelected(true);
        w.findChild<QPushButton *>("btnContinuar1")->click();
        auto *calendario = w.findChild<QCalendarWidget *>("calendario");
        auto *horarios = w.findChild<QListWidget *>("listaHorarios");
        for (int d = 3; d <= 40 && horarios->count() == 0; ++d)
            calendario->setSelectedDate(QDate::currentDate().addDays(d));
        QVERIFY(horarios->count() > 0);
        const QString hora = horarios->item(0)->text();
        const QDateTime inicio = horarios->item(0)->data(Qt::UserRole).toDateTime();

        // El id del protocolo elegido (la lista muestra el nombre en la primera línea).
        QVector<Protocolo> catalogo;
        QString error;
        QVERIFY(DatosBase::cargarProtocolos(repo, catalogo, &error));
        const QString nombre = protocolos->item(0)->text().section('\n', 0, 0);
        int idProtocolo = 0;
        for (const Protocolo &p : catalogo)
            if (p.nombre == nombre)
                idProtocolo = p.id;
        QVERIFY(idProtocolo != 0);

        // "Gestión" reserva ese horario con todos los profesionales que lo tenían libre.
        const QString dni = QString::number(60000000 + QRandomGenerator::global()->bounded(9999999));
        const Respuesta paciente = repo.altaPaciente(dni, "Otra", "Computadora", QDate(1991, 5, 2), QString(),
                                                     "1144443333", "terminal");
        QVERIFY2(paciente.ok, qPrintable(paciente.mensaje));
        // La primera reserva es de esta paciente; las otras, de pacientes distintas
        // (la base no deja que una misma paciente tenga dos turnos a la misma hora).
        QVector<int> reservados;
        int idPaciente = paciente.id;
        for (const HorarioLibre &h : repo.horariosLibres(inicio.date(), { idProtocolo })) {
            if (h.inicio != inicio)
                continue;
            if (!reservados.isEmpty()) {
                const QString otroDni = QString::number(50000000 + QRandomGenerator::global()->bounded(9999999));
                const Respuesta otra = repo.altaPaciente(otroDni, "Otra", "Paciente", QDate(1990, 1, 1), QString(),
                                                         "1144443334", "terminal");
                QVERIFY2(otra.ok, qPrintable(otra.mensaje));
                idPaciente = otra.id;
            }
            const Respuesta r = repo.altaTurno(idPaciente, h.idProfesional, inicio, { idProtocolo }, "terminal");
            QVERIFY2(r.ok, qPrintable(r.mensaje));
            reservados << r.id;
        }
        QVERIFY(!reservados.isEmpty());

        // La terminal deja de ofrecer esa hora sin que nadie toque nada.
        QTRY_VERIFY_WITH_TIMEOUT(horarios->findItems(hora, Qt::MatchExactly).isEmpty(), 8000);

        // "Mi turno" abierto en la terminal: si Gestión lo cancela, el estado cambia solo.
        w.findChild<QPushButton *>("btnMiTurno")->click();
        w.findChild<QLineEdit *>("editBuscarTurno")->setText(dni);
        w.findChild<QPushButton *>("btnBuscarTurno")->click();
        auto *estado = w.findChild<QLabel *>("lblEstadoTurno");
        QVERIFY(estado->text() != "Cancelado");

        // Una paciente que buscó y todavía no tenía turnos: cuando la recepción le carga
        // uno, aparece solo en la pantalla, sin volver a tocar Buscar.
        const QString dniSinTurnos = QString::number(40000000 + QRandomGenerator::global()->bounded(9999999));
        const Respuesta otra = repo.altaPaciente(dniSinTurnos, "Sin", "Turnos", QDate(1995, 1, 20), QString(),
                                                 "1122221111", "terminal");
        QVERIFY2(otra.ok, qPrintable(otra.mensaje));
        w.findChild<QLineEdit *>("editBuscarTurno")->setText(dniSinTurnos);
        contestar("OK");   // "No encontramos turnos"
        w.findChild<QPushButton *>("btnBuscarTurno")->click();
        auto *tarjeta = w.findChild<QWidget *>("tarjetaMiTurno");
        QVERIFY(!tarjeta->isVisible());
        QDateTime otroInicio;
        int otroProfesional = 0;
        for (int d = 5; d <= 40 && otroProfesional == 0; ++d)
            for (const HorarioLibre &h : repo.horariosLibres(QDate::currentDate().addDays(d), { idProtocolo }))
                if (otroProfesional == 0) {
                    otroInicio = h.inicio;
                    otroProfesional = h.idProfesional;
                }
        const Respuesta nuevo = repo.altaTurno(otra.id, otroProfesional, otroInicio, { idProtocolo }, "terminal");
        QVERIFY2(nuevo.ok, qPrintable(nuevo.mensaje));
        QTRY_VERIFY_WITH_TIMEOUT(tarjeta->isVisible(), 8000);
        QVERIFY(repo.cancelarTurno(nuevo.id, "terminal").ok);

        // Vuelve al turno de la primera paciente para probar la cancelación desde Gestión.
        w.findChild<QLineEdit *>("editBuscarTurno")->setText(dni);
        w.findChild<QPushButton *>("btnBuscarTurno")->click();
        QVERIFY(estado->text() != "Cancelado");
        for (int id : reservados)
            QVERIFY(repo.cancelarTurno(id, "terminal").ok);
        QTRY_COMPARE_WITH_TIMEOUT(estado->text(), QString("Cancelado"), 8000);
    }

    // Cuenta de la paciente: se crea desde "Ingresar" (arriba a la derecha), queda en la base,
    // completa sus datos al sacar turno, se sale y se vuelve a entrar. La cuenta del personal
    // no sirve en la terminal y no se puede crear una segunda cuenta con el mismo DNI.
    void terminal_cuentaDeLaPaciente()
    {
        BaseDatos base(ConfigBD::desdeEntorno());
        if (!base.conectar())
            QSKIP("Sin base de datos (definir DERMALIA_DB_USER, etc.).");
        Repositorio repo(base);

        VentanaCliente w(nullptr, carpeta.filePath("local3.json"), carpeta.filePath("pendientes3.json"));
        w.show();
        QTRY_VERIFY_WITH_TIMEOUT(w.usaBase(), 5000);
        auto *btnCuenta = w.findChild<QPushButton *>("btnCuenta");
        QVERIFY(btnCuenta->isVisible());
        QCOMPARE(btnCuenta->text(), QString("Ingresar"));

        QString letras;
        for (int i = 0; i < 6; ++i)
            letras += QChar('a' + QRandomGenerator::global()->bounded(26));
        const QString usuario = "paciente." + letras;
        const QString dni = QString::number(30000000 + QRandomGenerator::global()->bounded(9999999));

        // Crear la cuenta (paciente nueva): queda ingresada.
        QTimer::singleShot(100, [&] {
            QWidget *d = QApplication::activeModalWidget();
            d->findChild<QPushButton *>("btnIrACrearCuenta")->click();
            d->findChild<QLineEdit *>("editNombreCuenta")->setText("Sofía Cuenta");
            d->findChild<QLineEdit *>("editDniCuenta")->setText(dni);
            d->findChild<QLineEdit *>("editTelefonoCuenta")->setText("1145678901");
            d->findChild<QDateEdit *>("editNacimientoCuenta")->setDate(QDate(1992, 3, 4));
            d->findChild<QLineEdit *>("editEmailCuenta")->setText(usuario + "@correo.example");
            d->findChild<QLineEdit *>("editNuevoUsuarioCuenta")->setText(usuario);
            d->findChild<QLineEdit *>("editNuevaClaveCuenta")->setText("miclave1");
            d->findChild<QLineEdit *>("editRepetirClaveCuenta")->setText("miclave1");
            d->findChild<QPushButton *>("btnCrearCuenta")->click();
            if (QApplication::activeModalWidget() == d)   // si no se cerró, la prueba falla abajo
                d->close();
        });
        btnCuenta->click();
        QVERIFY(w.sesionActual().activa());
        QCOMPARE(w.sesionActual().dni, dni);
        QCOMPARE(btnCuenta->text(), QString("Hola, Sofía"));
        QCOMPARE(w.findChild<QLineEdit *>("editNombre")->text(), QString("Sofía Cuenta"));   // ya no la escribe
        QCOMPARE(w.findChild<QLineEdit *>("editDni")->text(), dni);
        const Respuesta enLaBase = repo.login(usuario, "miclave1", QString(), "terminal");
        QVERIFY2(enLaBase.ok, qPrintable(enLaBase.mensaje));
        QCOMPARE(enLaBase.dato, QString("paciente"));

        // Salir: se borran sus datos de la pantalla.
        contestar("Yes");
        btnCuenta->click();
        QVERIFY(!w.sesionActual().activa());
        QCOMPARE(btnCuenta->text(), QString("Ingresar"));
        QVERIFY(w.findChild<QLineEdit *>("editDni")->text().isEmpty());

        // Otra vez "Ingresar": con la cuenta del personal no deja; con la suya, sí.
        QString errorPersonal, errorSegunda;
        QTimer::singleShot(100, [&] {
            QWidget *d = QApplication::activeModalWidget();
            d->findChild<QLineEdit *>("editUsuarioCuenta")->setText("recepcion1");
            d->findChild<QLineEdit *>("editClaveCuenta")->setText("dermalia2026");
            d->findChild<QPushButton *>("btnIngresarCuenta")->click();
            errorPersonal = d->findChild<QLabel *>("lblErrorIngreso")->text();
            // Una segunda cuenta con el mismo DNI no se puede crear.
            d->findChild<QPushButton *>("btnIrACrearCuenta")->click();
            d->findChild<QLineEdit *>("editNombreCuenta")->setText("Sofía Cuenta");
            d->findChild<QLineEdit *>("editDniCuenta")->setText(dni);
            d->findChild<QLineEdit *>("editTelefonoCuenta")->setText("1145678901");
            d->findChild<QLineEdit *>("editEmailCuenta")->setText("otra." + usuario + "@correo.example");
            d->findChild<QLineEdit *>("editNuevoUsuarioCuenta")->setText("otra." + usuario);
            d->findChild<QLineEdit *>("editNuevaClaveCuenta")->setText("miclave1");
            d->findChild<QLineEdit *>("editRepetirClaveCuenta")->setText("miclave1");
            d->findChild<QPushButton *>("btnCrearCuenta")->click();
            errorSegunda = d->findChild<QLabel *>("lblErrorAlta")->text();
            d->findChild<QPushButton *>("btnVolverAIngresar")->click();
            d->findChild<QLineEdit *>("editUsuarioCuenta")->setText(usuario);
            d->findChild<QLineEdit *>("editClaveCuenta")->setText("miclave1");
            d->findChild<QPushButton *>("btnIngresarCuenta")->click();
            if (QApplication::activeModalWidget() == d)
                d->close();
        });
        btnCuenta->click();
        QVERIFY2(errorPersonal.contains("personal"), qPrintable(errorPersonal));
        QVERIFY2(errorSegunda.contains("Ya tenés una cuenta"), qPrintable(errorSegunda));
        QVERIFY(w.sesionActual().activa());

        // "Buscar mi turno" con la cuenta: busca solo por su DNI (no tiene turnos todavía).
        w.findChild<QPushButton *>("btnMiTurno")->click();
        QCOMPARE(w.findChild<QLineEdit *>("editBuscarTurno")->text(), dni);
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
