/* Pruebas de la agenda real guardada en la PC: horarios libres que salen igual que en la base (franja, duración,
 * turnos que pisan, profesional), día fuera de la agenda, ida y vuelta por archivo y pendientes viejos sin profesional. */
#include "agendareal.h"
#include "contingencia.h"

#include <QFile>
#include <QTemporaryDir>
#include <QtTest>

class PruebaAgendaReal : public QObject
{
    Q_OBJECT

private slots:
    void init();
    void unaFranja();
    void noEntraLaDuracion();
    void turnoOcupaHorarios();
    void canceladoYOtroProfesionalNoOcupan();
    void turnoExtraOcupa();
    void protocoloInexistenteOBaja();
    void soloProfesionalQueHaceTodos();
    void horasPasadas();
    void diaFueraDeLaAgenda();
    void idaYVuelta();
    void pendienteViejoSinProfesional();

private:
    static Turno turno(const QString &profesional, const QDateTime &inicio, int minutos, EstadoTurno estado = EstadoTurno::Confirmado);

    AgendaReal::Foto foto;
    const QDate dia { 2027, 1, 10 };
    const QDateTime ahora { QDate(2027, 1, 1), QTime(8, 0) };
};

Turno PruebaAgendaReal::turno(const QString &profesional, const QDateTime &inicio, int minutos, EstadoTurno estado)
{
    Turno t {};
    t.profesional = profesional;
    t.inicio = inicio;
    t.fin = inicio.addSecs(minutos * 60);
    t.estado = estado;
    return t;
}

void PruebaAgendaReal::init()
{
    foto = AgendaReal::Foto();
    Protocolo limpieza {};
    limpieza.nombre = "Limpieza facial";
    limpieza.duracionMin = 60;
    limpieza.id = 1;
    Protocolo peeling {};
    peeling.nombre = "Peeling";
    peeling.duracionMin = 150;
    peeling.id = 2;
    Protocolo baja {};
    baja.nombre = "Antiguo";
    baja.duracionMin = 30;
    baja.activo = false;
    baja.id = 3;
    foto.protocolos = { limpieza, peeling, baja };

    Profesional ana {};
    ana.id = 7;
    ana.nombre = "Ana Pérez";
    ana.activo = true;
    ana.protocolos = { "Limpieza facial", "Peeling", "Antiguo" };
    ana.franjas = { Franja { dia, QTime(9, 0), QTime(11, 0), true, 0 } };
    Profesional luis {};
    luis.id = 8;
    luis.nombre = "Luis Gómez";
    luis.activo = true;
    luis.protocolos = { "Limpieza facial" };
    luis.franjas = { Franja { dia, QTime(15, 0), QTime(16, 0), true, 0 } };
    foto.profesionales = { ana, luis };
    foto.tomada = ahora;
}

static QStringList horas(const QVector<HorarioLibre> &libres)
{
    QStringList s;
    for (const HorarioLibre &h : libres)
        s << QString("%1 %2").arg(h.idProfesional).arg(h.inicio.toString("HH:mm"));
    return s;
}

void PruebaAgendaReal::unaFranja()
{
    /* 09:00 a 11:00 con 60 min: caben 09:00, 09:30 y 10:00; Luis aporta 15:00. */
    const QStringList esperado { "7 09:00", "7 09:30", "7 10:00", "8 15:00" };
    QCOMPARE(horas(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, ahora)), esperado);
}

void PruebaAgendaReal::noEntraLaDuracion()
{
    /* Peeling dura 150 min y la franja de Ana tiene 120: no hay horario. */
    QVERIFY(AgendaReal::horariosLibres(foto, { "Peeling" }, dia, ahora).isEmpty());
    /* Dos tratamientos suman 60 + 150: tampoco. */
    QVERIFY(AgendaReal::horariosLibres(foto, { "Limpieza facial", "Peeling" }, dia, ahora).isEmpty());
}

void PruebaAgendaReal::turnoOcupaHorarios()
{
    foto.turnos = { turno("Ana Pérez", QDateTime(dia, QTime(10, 0)), 60) };
    /* Termina justo cuando empieza el turno: 09:00 sigue libre; 09:30 y 10:00 se pisan. */
    const QStringList esperado { "7 09:00", "8 15:00" };
    QCOMPARE(horas(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, ahora)), esperado);
}

void PruebaAgendaReal::canceladoYOtroProfesionalNoOcupan()
{
    foto.turnos = { turno("Ana Pérez", QDateTime(dia, QTime(9, 0)), 120, EstadoTurno::Cancelado),
                    turno("Luis Gómez", QDateTime(dia, QTime(9, 0)), 120) };
    QCOMPARE(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, ahora).size(), 4);
}

void PruebaAgendaReal::turnoExtraOcupa()
{
    /* Un turno agendado sin conexión en esta PC (todavía no está en la foto) también ocupa. */
    const QVector<Turno> extra { turno("Luis Gómez", QDateTime(dia, QTime(15, 0)), 60) };
    const QStringList esperado { "7 09:00", "7 09:30", "7 10:00" };
    QCOMPARE(horas(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, ahora, extra)), esperado);
}

void PruebaAgendaReal::protocoloInexistenteOBaja()
{
    QVERIFY(AgendaReal::horariosLibres(foto, { "No existe" }, dia, ahora).isEmpty());
    QVERIFY(AgendaReal::horariosLibres(foto, { "Antiguo" }, dia, ahora).isEmpty());
    QVERIFY(AgendaReal::horariosLibres(foto, {}, dia, ahora).isEmpty());
}

void PruebaAgendaReal::soloProfesionalQueHaceTodos()
{
    foto.profesionales[1].protocolos = { "Peeling" };   /* Luis ya no hace limpieza */
    const QVector<HorarioLibre> libres = AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, ahora);
    QCOMPARE(libres.size(), 3);
    for (const HorarioLibre &h : libres)
        QCOMPARE(h.idProfesional, 7);
    foto.profesionales[0].activo = false;               /* y Ana está de baja */
    QVERIFY(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, ahora).isEmpty());
}

void PruebaAgendaReal::horasPasadas()
{
    const QDateTime tarde(dia, QTime(9, 30));
    const QStringList esperado { "7 10:00", "8 15:00" };
    QCOMPARE(horas(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, tarde)), esperado);
}

void PruebaAgendaReal::diaFueraDeLaAgenda()
{
    const QDate fuera(2027, 1, 20);
    QVERIFY(AgendaReal::cubreDia(foto, dia));
    QVERIFY(!AgendaReal::cubreDia(foto, fuera));
    QVERIFY(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, fuera, ahora).isEmpty());
    foto.profesionales[0].franjas[0].activa = false;
    foto.profesionales[1].franjas[0].activa = false;
    QVERIFY(!AgendaReal::cubreDia(foto, dia));
}

void PruebaAgendaReal::idaYVuelta()
{
    foto.turnos = { turno("Ana Pérez", QDateTime(dia, QTime(10, 0)), 60) };
    QTemporaryDir carpeta;
    QVERIFY(carpeta.isValid());
    const QString ruta = carpeta.filePath("sub/agenda_real.json");   /* la carpeta se crea sola */
    QVERIFY(AgendaReal::guardar(ruta, foto));

    AgendaReal::Foto leida;
    QVERIFY(AgendaReal::leer(ruta, &leida));
    QVERIFY(!leida.vacia());
    QCOMPARE(leida.tomada, foto.tomada);
    QCOMPARE(leida.turnos.size(), 1);
    QCOMPARE(horas(AgendaReal::horariosLibres(leida, { "Limpieza facial" }, dia, ahora)),
             horas(AgendaReal::horariosLibres(foto, { "Limpieza facial" }, dia, ahora)));

    AgendaReal::Foto intacta = foto;
    QVERIFY(!AgendaReal::leer(carpeta.filePath("no_existe.json"), &intacta));
    QCOMPARE(intacta.profesionales.size(), 2);                       /* si no puede leer, no pisa lo que hay */
    QFile roto(carpeta.filePath("roto.json"));
    QVERIFY(roto.open(QIODevice::WriteOnly));
    roto.write("no es json");
    roto.close();
    QVERIFY(!AgendaReal::leer(roto.fileName(), &intacta));
    QCOMPARE(intacta.profesionales.size(), 2);
}

void PruebaAgendaReal::pendienteViejoSinProfesional()
{
    QTemporaryDir carpeta;
    QVERIFY(carpeta.isValid());
    const QString ruta = carpeta.filePath("pendientes.json");

    /* Archivo escrito por una versión anterior: sin el campo "profesional". */
    QFile viejo(ruta);
    QVERIFY(viejo.open(QIODevice::WriteOnly));
    viejo.write(R"([{"paciente":"Ana Prueba","dni":"30111222","telefono":"1155551234","protocolo":"Limpieza facial",)"
                R"("inicio":"2027-01-10T09:00:00","sena":1000,"senaPagada":false,"origen":"Terminal",)"
                R"("guardado":"2027-01-01T08:00:00","nacimiento":""}])");
    viejo.close();
    Contingencia c(ruta);
    QCOMPARE(c.cantidad(), 1);
    QCOMPARE(c.pendientes().first().profesional, 0);

    TurnoPendiente nuevo;
    nuevo.paciente = "Luis Prueba";
    nuevo.dni = "30999888";
    nuevo.protocolo = "Limpieza facial";
    nuevo.inicio = QDateTime(dia, QTime(15, 0));
    nuevo.profesional = 8;
    QVERIFY(c.guardar(nuevo));
    QCOMPARE(Contingencia(ruta).pendientes().last().profesional, 8);
}

QTEST_MAIN(PruebaAgendaReal)
#include "prueba_agendareal.moc"
