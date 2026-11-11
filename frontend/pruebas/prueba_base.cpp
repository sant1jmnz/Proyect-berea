// Prueba de integración: la capa Repositorio contra los stored procedures
// reales. Necesita MySQL con la base cargada (backend/01 a 06) y los datos de
// conexión en las variables DERMALIA_DB_HOST, _PORT, _USER, _PASS (ver
// docs/conexion-base.md). Sin conexión la prueba se saltea (no falla), así
// `ctest` sigue andando en una PC sin base.
//
// ATENCIÓN: escribe en la base (da de alta una paciente de prueba, agenda un
// turno, lo paga y lo cancela). Usar una base de pruebas, no la de producción.
//   QT_QPA_PLATFORM=offscreen DERMALIA_DB_USER=root ./prueba_base
#include <QtTest>
#include <QRandomGenerator>

#include "basedatos.h"
#include "repositorio.h"

class PruebaBase : public QObject
{
    Q_OBJECT

private:
    BaseDatos *base = nullptr;
    Repositorio *repo = nullptr;

private slots:
    // Se conecta una sola vez; sin base, todas las pruebas se saltean.
    void initTestCase()
    {
        base = new BaseDatos(ConfigBD::desdeEntorno());
        if (!BaseDatos::compiladoConMysql())
            QSKIP("Compilado sin el cliente de MySQL (libmysqlclient-dev).");
        if (!base->conectar())
            QSKIP(qPrintable("Sin base de datos: " + base->ultimoError()));
        repo = new Repositorio(*base);
    }

    void cleanupTestCase()
    {
        delete repo;
        delete base;
    }

    // El catálogo trae los protocolos con su seña calculada por la base.
    void catalogoDeProtocolos()
    {
        const QVector<ProtocoloBD> todos = repo->listarProtocolos();
        QVERIFY2(todos.size() >= 30, "El catálogo de ejemplo tiene 30 protocolos");
        const QVector<ProtocoloBD> laser = repo->listarProtocolos("láser");
        QVERIFY(!laser.isEmpty());
        QVERIFY(laser.first().nombre.contains("láser", Qt::CaseInsensitive));
        QCOMPARE(repo->listarProtocolos("xyzxyz").size(), 0);
        // la seña es el porcentaje de la categoría sobre el precio
        for (const ProtocoloBD &p : todos)
            QCOMPARE(p.sena, qRound(p.precio * p.porcentajeSena / 100.0));
    }

    // Login: el administrador entra; con la clave mal, no.
    void loginDelPersonal()
    {
        const Respuesta ok = repo->login("admin", "dermalia2026", "127.0.0.1", "gestion");
        QVERIFY2(ok.ok, qPrintable(ok.mensaje));
        QCOMPARE(ok.dato, QString("administrador"));
        const Respuesta mal = repo->login("recepcion1", "clave-mala", "127.0.0.1", "gestion");
        QVERIFY(!mal.ok);
        QCOMPARE(mal.codigo, 52011);
    }

    // Recorrido completo de una paciente: alta, horario libre, turno, seña, búsqueda y cancelación.
    void reservaDePuntaAPunta()
    {
        // 1. Paciente nueva (DNI de 8 dígitos al azar para poder repetir la prueba).
        const QString dni = QString::number(50000000 + int(QRandomGenerator::global()->bounded(9999999)));
        const Respuesta alta = repo->altaPaciente(dni, "Prueba", "Integracion", QDate(1990, 5, 5), QString(), "1155559999", "gestion");
        QVERIFY2(alta.ok, qPrintable(alta.mensaje));
        QVERIFY(alta.id > 0);
        // El mismo DNI otra vez: la regla de la base lo rechaza con su código.
        const Respuesta repetida = repo->altaPaciente(dni, "Otra", "Persona", QDate(1990, 5, 5), QString(), "1155559998", "gestion");
        QVERIFY(!repetida.ok);
        QCOMPARE(repetida.codigo, 52035);

        // 2. Primer horario libre para una limpieza facial (protocolo 1) en los próximos 30 días.
        //    Se pide con más de 24 h de anticipación, así la cancelación del final reembolsa todo.
        HorarioLibre h;
        const QDateTime minimo = QDateTime::currentDateTime().addSecs(25 * 3600);
        for (int d = 1; d <= 30 && h.idProfesional == 0; ++d) {
            const QVector<HorarioLibre> libres = repo->horariosLibres(QDate::currentDate().addDays(d), { 1 });
            for (const HorarioLibre &candidato : libres) {
                if (candidato.inicio >= minimo) {
                    h = candidato;
                    break;
                }
            }
        }
        if (h.idProfesional == 0)
            QSKIP("No hay horarios libres en los próximos 30 días (los datos de ejemplo llegan hasta fines de noviembre de 2026).");

        // 3. Turno: queda pendiente y devuelve la seña a pagar.
        const Respuesta turno = repo->altaTurno(alta.id, h.idProfesional, h.inicio, { 1 }, "gestion");
        QVERIFY2(turno.ok, qPrintable(turno.mensaje));
        QVERIFY(turno.id > 0);
        QVERIFY(turno.valor > 0);
        // Mismo horario con el mismo profesional: error 52081 (superposición).
        const Respuesta pisado = repo->altaTurno(alta.id, h.idProfesional, h.inicio, { 1 }, "gestion");
        QVERIFY(!pisado.ok);
        QCOMPARE(pisado.codigo, 52081);

        // 4. Seña simulada: confirma el turno y devuelve el código SIM-...
        const Respuesta sena = repo->registrarSena(turno.id, "efectivo", QString(), "gestion");
        QVERIFY2(sena.ok, qPrintable(sena.mensaje));
        QVERIFY(!sena.dato.isEmpty());
        QCOMPARE(sena.valor, turno.valor);

        // 5. La búsqueda por DNI lo encuentra confirmado y con la seña pagada.
        const QVector<TurnoBD> encontrados = repo->buscarTurnos(dni);
        QCOMPARE(encontrados.size(), 1);
        QCOMPARE(encontrados.first().estado, QString("confirmado"));
        QCOMPARE(encontrados.first().estadoSena, QString("pagada"));
        QCOMPARE(encontrados.first().inicio, h.inicio);

        // 6. Cancelar con más de 24 h: reembolso total.
        const Respuesta cancel = repo->cancelarTurno(turno.id, "gestion");
        QVERIFY2(cancel.ok, qPrintable(cancel.mensaje));
        QCOMPARE(cancel.dato, QString("reembolsada"));
        QCOMPARE(cancel.valor, turno.valor);
        // Cancelar de nuevo: la base lo rechaza.
        QVERIFY(!repo->cancelarTurno(turno.id, "gestion").ok);
    }

    // Los reportes y la auditoría devuelven filas por nombre de columna.
    void reportesYAuditoria()
    {
        const Resultado r = repo->reporte("pagos.sp_reporte_ingresos_sena", QDate(2026, 9, 1), QDate(2026, 11, 30));
        QVERIFY2(r.ok, qPrintable(r.error));
        QVERIFY(!r.filas.isEmpty());
        QVERIFY(r.filas.first().contains("cobrado"));
        const Resultado aud = repo->auditoria(QDate::currentDate().addDays(-1), QDate::currentDate().addDays(1), "inicio_sesion");
        QVERIFY2(aud.ok, qPrintable(aud.error));
        QVERIFY(!aud.filas.isEmpty());   // el login de arriba quedó en el log
    }
};

QTEST_MAIN(PruebaBase)
#include "prueba_base.moc"
