#include "datosbase.h"

namespace DatosBase {

QString nombreYApellido(const QString &apellidoComaNombre)
{
    const int coma = apellidoComaNombre.indexOf(", ");
    if (coma < 0)
        return apellidoComaNombre;
    return apellidoComaNombre.mid(coma + 2) + " " + apellidoComaNombre.left(coma);
}

/* Deja solo los dígitos del teléfono (así se compara y se guarda en las pantallas). */
static QString soloDigitos(const QString &texto)
{
    QString limpio;
    for (QChar c : texto) {
        if (c.isDigit())
            limpio += c;
    }
    return limpio;
}

bool cargarProtocolos(Repositorio &repo, QVector<Protocolo> &protocolos, QString *error)
{
    /* Con las bajas incluidas: la pantalla Protocolos permite reactivarlos. */
    const QVector<ProtocoloBD> filas = repo.listarProtocolos(QString(), 0, true);
    if (filas.isEmpty() && !repo.ultimoError().isEmpty()) {
        *error = repo.ultimoError();
        return false;
    }
    protocolos.clear();
    for (const ProtocoloBD &f : filas) {
        Protocolo p;
        p.id = f.id;
        p.nombre = f.nombre;
        p.duracionMin = f.duracionMin;
        p.descripcion = f.descripcion;
        p.precio = f.precio;
        p.activo = f.activo;
        p.categoria.id = f.idCategoria;
        p.categoria.nombre = f.categoria;
        p.categoria.porcentajeSena = f.porcentajeSena;
        p.categoria.requiereEvaluacion = f.requiereEvaluacion;
        protocolos.append(p);
    }
    return true;
}

bool cargarPacientes(Repositorio &repo, QVector<Paciente> &pacientes, QString *error)
{
    const Resultado r = repo.listarPacientes();
    if (!r.ok) {
        *error = r.error;
        return false;
    }
    pacientes.clear();
    for (const QVariantMap &f : r.filas) {
        Paciente p;
        p.id = f.value("id_paciente").toInt();
        p.nombre = f.value("nombre").toString() + " " + f.value("apellido").toString();
        p.dni = f.value("dni").toString();
        p.telefono = soloDigitos(f.value("telefono").toString());
        p.email = f.value("email").toString();
        p.nacimiento = QDate::fromString(f.value("fecha_nacimiento").toString(), "yyyy-MM-dd");
        pacientes.append(p);
    }
    return true;
}

bool cargarProfesionales(Repositorio &repo, const QVector<Protocolo> &protocolos,
                         QVector<Profesional> &profesionales, QString *error)
{
    const Resultado lista = repo.listarProfesionales();
    const Resultado hace = repo.listarProfesionalProtocolo();
    const Resultado franjas = repo.listarDisponibilidad(QDate::currentDate());
    for (const Resultado *r : { &lista, &hace, &franjas }) {
        if (!r->ok) {
            *error = r->error;
            return false;
        }
    }

    profesionales.clear();
    for (const QVariantMap &f : lista.filas) {
        Profesional p;
        p.id = f.value("id_profesional").toInt();
        p.nombre = f.value("nombre").toString() + " " + f.value("apellido").toString();
        p.matricula = f.value("matricula").toString();
        p.email = f.value("email").toString();
        p.activo = f.value("activo").toInt() == 1;
        profesionales.append(p);
    }
    /* Qué protocolos hace cada profesional: la base da ids, las pantallas usan nombres. */
    for (const QVariantMap &f : hace.filas) {
        const int idProfesional = f.value("id_profesional").toInt();
        const int idProtocolo = f.value("id_protocolo").toInt();
        for (Profesional &p : profesionales) {
            if (p.id != idProfesional)
                continue;
            for (const Protocolo &protocolo : protocolos) {
                if (protocolo.id == idProtocolo)
                    p.protocolos << protocolo.nombre;
            }
        }
    }
    for (const QVariantMap &f : franjas.filas) {
        const int idProfesional = f.value("id_profesional").toInt();
        for (Profesional &p : profesionales) {
            if (p.id != idProfesional)
                continue;
            Franja franja;
            franja.id = f.value("id_disponibilidad").toInt();
            franja.fecha = QDate::fromString(f.value("fecha").toString(), "yyyy-MM-dd");
            franja.desde = QTime::fromString(f.value("hora_inicio").toString(), "HH:mm:ss");
            franja.hasta = QTime::fromString(f.value("hora_fin").toString(), "HH:mm:ss");
            p.franjas.append(franja);
        }
    }
    return true;
}

Turno aTurno(const TurnoBD &t)
{
    Turno turno;
    turno.id = t.id;
    turno.idPaciente = t.idPaciente;
    turno.paciente = nombreYApellido(t.paciente);
    turno.dni = t.dni;
    turno.telefono = soloDigitos(t.telefono);
    turno.protocolo = t.protocolos;
    turno.precioAplicado = qRound(t.precioFinal);
    turno.sena = qRound(t.sena);
    turno.inicio = t.inicio;
    turno.fin = t.fin;
    turno.profesional = nombreYApellido(t.profesional);
    turno.senaPagada = t.estadoSena != "sin seña";
    turno.codigoOperacion = t.codigoOperacion;

    if (t.estado == "confirmado")
        turno.estado = EstadoTurno::Confirmado;
    else if (t.estado == "realizado")
        turno.estado = EstadoTurno::Realizado;
    else if (t.estado == "cancelado")
        turno.estado = EstadoTurno::Cancelado;
    else if (t.estado == "ausente")
        turno.estado = EstadoTurno::Ausente;
    else
        turno.estado = EstadoTurno::Pendiente;

    /* Origen: la base guarda "gestion", "terminal", "web", "sistema". */
    if (t.origen == "gestion")
        turno.origen = "Gestión";
    else if (t.origen == "terminal")
        turno.origen = "Terminal";
    else if (t.origen == "web")
        turno.origen = "Web";
    else
        turno.origen = "Sistema";

    if (t.estadoSena == "reembolsada")
        turno.reembolsado = turno.sena;
    return turno;
}

bool cargarTurnos(Repositorio &repo, const QDate &hoy, int dias, QVector<Turno> &turnos, QString *error)
{
    const QVector<TurnoBD> filas = repo.listarTurnos(hoy.addDays(-dias), hoy.addDays(dias));
    if (filas.isEmpty() && !repo.ultimoError().isEmpty()) {
        *error = repo.ultimoError();
        return false;
    }
    turnos.clear();
    for (const TurnoBD &f : filas)
        turnos.append(aTurno(f));
    return true;
}

bool cargarAvisos(Repositorio &repo, const QDate &hoy, int dias, RegistroAvisos &avisos, QString *error)
{
    const Resultado r = repo.listarNotificaciones(hoy.addDays(-dias), hoy.addDays(dias));
    if (!r.ok) {
        *error = r.error;
        return false;
    }
    QVector<Aviso> lista;
    for (const QVariantMap &f : r.filas) {
        Aviso a;
        a.id = f.value("id_notificacion").toInt();
        a.paciente = nombreYApellido(f.value("paciente").toString());
        a.dni = f.value("dni").toString();
        a.telefono = soloDigitos(f.value("telefono").toString());
        a.inicioTurno = QDateTime::fromString(f.value("fecha_hora_inicio").toString(), "yyyy-MM-dd HH:mm:ss");
        a.programado = QDateTime::fromString(f.value("fecha_programada").toString(), "yyyy-MM-dd HH:mm:ss");
        a.enviado = QDateTime::fromString(f.value("fecha_envio").toString(), "yyyy-MM-dd HH:mm:ss");
        a.intentos = f.value("intentos").toInt();
        a.mensaje = f.value("mensaje").toString();
        a.detalleError = f.value("detalle_error").toString();

        const QString canal = f.value("canal").toString();
        if (canal == "Telegram")
            a.canal = CanalAviso::Telegram;
        else if (canal == "WhatsApp")
            a.canal = CanalAviso::WhatsApp;
        else if (canal == "Google Calendar")
            a.canal = CanalAviso::GoogleCalendar;
        else
            a.canal = CanalAviso::WhatsAppAsistido;

        const QString estado = f.value("estado").toString();
        if (estado == "cancelada")
            continue;   /* el turno se canceló: el aviso ya no sale y no se muestra */
        if (estado == "enviada")
            a.estado = EstadoAviso::Enviado;
        else if (estado == "fallida")
            a.estado = EstadoAviso::Fallido;
        else
            a.estado = EstadoAviso::Pendiente;
        lista.append(a);
    }
    avisos.reemplazar(lista);
    return true;
}

}
