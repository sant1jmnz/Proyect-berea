#include "repositorio.h"

#include <QCryptographicHash>
#include <QStringList>

/* Formato de fecha y hora que usan los stored procedures. */
const QString FORMATO_FECHA_HORA = "yyyy-MM-dd HH:mm:ss";

/* SHA-256 en hexadecimal: es lo que esperan sp_login y sp_crear_cuenta_paciente. */
QString Repositorio::hashClave(const QString &clave)
{
    return QString::fromLatin1(QCryptographicHash::hash(clave.toUtf8(), QCryptographicHash::Sha256).toHex());
}

/* Resume lo que devolvió `BaseDatos::llamar` de un SP que escribe. Si el SP
 * devolvió ERROR, `llamar` ya dejó el mensaje en español y el código. */
Respuesta Repositorio::aRespuesta(const Resultado &r)
{
    Respuesta resp;
    if (!r.ok) {
        /* El SP devolvió ERROR: BaseDatos ya dejó el mensaje en español y el código. */
        resp.codigo = r.codigoSql;
        resp.mensaje = r.error;
        return resp;
    }
    resp.ok = true;
    if (!r.filas.isEmpty()) {
        const QVariantMap &f = r.filas.first();
        resp.codigo = f.value("codigo").toInt();
        resp.mensaje = f.value("mensaje").toString();
        resp.id = f.value("id").toInt();
        resp.valor = f.value("valor").toDouble();
        resp.dato = f.value("dato").toString();
    }
    return resp;
}

QVariant Repositorio::idONulo(int id)
{
    if (id > 0)
        return QVariant(id);
    return QVariant();
}

QVariant Repositorio::textoONulo(const QString &texto)
{
    if (texto.isEmpty())
        return QVariant();
    return QVariant(texto);
}

/* [3, 7] → "3,7": así reciben los SP una lista de protocolos. */
QString Repositorio::lista(const QVector<int> &ids)
{
    QStringList partes;
    for (int id : ids)
        partes << QString::number(id);
    return partes.join(',');
}

Respuesta Repositorio::login(const QString &usuario, const QString &clave, const QString &ip, const QString &origen)
{
    return aRespuesta(base.llamar("seguridad.sp_login", { usuario, hashClave(clave), textoONulo(ip), origen }));
}

Respuesta Repositorio::altaPaciente(const QString &dni, const QString &nombre, const QString &apellido, const QDate &nacimiento,
                                    const QString &email, const QString &telefono, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_alta_paciente",
        { dni, nombre, apellido, nacimiento.toString("yyyy-MM-dd"), textoONulo(email), telefono, origen, idONulo(idUsuario) }));
}

Resultado Repositorio::buscarPaciente(const QString &texto)
{
    return base.llamar("personas.sp_buscar_paciente", { texto });
}

QVector<ProtocoloBD> Repositorio::listarProtocolos(const QString &texto, int idCategoria, bool incluirBajas)
{
    QVector<ProtocoloBD> out;
    const Resultado r = base.llamar("clinica.sp_listar_protocolos", { textoONulo(texto), idONulo(idCategoria), incluirBajas ? 1 : 0 });
    error = r.ok ? QString() : r.error;
    /* Cada fila del resultado es una columna → valor; se pasa a la estructura. */
    for (const QVariantMap &f : r.filas) {
        ProtocoloBD p;
        p.id = f.value("id_protocolo").toInt();
        p.idCategoria = f.value("id_categoria").toInt();
        p.nombre = f.value("nombre").toString();
        p.descripcion = f.value("descripcion").toString();
        p.categoria = f.value("categoria").toString();
        p.precio = f.value("precio").toDouble();
        p.duracionMin = f.value("duracion_min").toInt();
        p.porcentajeSena = f.value("porcentaje_sena").toDouble();
        p.sena = f.value("sena").toDouble();
        p.requiereEvaluacion = f.value("requiere_evaluacion").toInt() == 1;
        p.activo = f.value("activo").toInt() == 1;
        out.append(p);
    }
    return out;
}

Respuesta Repositorio::altaProtocolo(int idCategoria, const QString &nombre, const QString &descripcion, double precio,
                                     int duracionMin, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_alta_protocolo",
        { idCategoria, nombre, textoONulo(descripcion), precio, duracionMin, origen, idONulo(idUsuario) }));
}

Respuesta Repositorio::modificarProtocolo(int idProtocolo, const QString &nombre, const QString &descripcion, double precio,
                                          int duracionMin, bool activo, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_modificar_protocolo",
        { idProtocolo, nombre, textoONulo(descripcion), precio, duracionMin, activo ? 1 : 0, origen, idONulo(idUsuario) }));
}

Respuesta Repositorio::modificarPaciente(int idPaciente, const QString &nombre, const QString &apellido, const QString &email,
                                         const QString &telefonoNuevo, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_modificar_paciente",
        { idPaciente, nombre, apellido, textoONulo(email), textoONulo(telefonoNuevo), origen, idONulo(idUsuario) }));
}

Resultado Repositorio::listarPacientes() { return base.llamar("personas.sp_listar_pacientes"); }
Resultado Repositorio::listarProfesionales() { return base.llamar("personas.sp_listar_profesionales"); }
Resultado Repositorio::listarProfesionalProtocolo() { return base.llamar("clinica.sp_listar_profesional_protocolo"); }

Resultado Repositorio::listarDisponibilidad(const QDate &desde)
{
    return base.llamar("personas.sp_listar_disponibilidad", { desde.toString("yyyy-MM-dd") });
}

Resultado Repositorio::listarNotificaciones(const QDate &desde, const QDate &hasta)
{
    return base.llamar("notificaciones.sp_listar_notificaciones", { desde.toString("yyyy-MM-dd"), hasta.toString("yyyy-MM-dd") });
}

Respuesta Repositorio::altaProfesional(const QString &matricula, const QString &nombre, const QString &apellido, const QString &email,
                                       const QString &telefono, const QString &usuario, const QString &clave,
                                       const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_alta_profesional",
        { matricula, nombre, apellido, email, telefono, usuario, hashClave(clave), origen, idONulo(idUsuario) }));
}

Respuesta Repositorio::modificarProfesional(int idProfesional, const QString &nombre, const QString &apellido, const QString &email,
                                            bool activo, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_modificar_profesional",
        { idProfesional, nombre, apellido, email, activo ? 1 : 0, origen, idONulo(idUsuario) }));
}

Respuesta Repositorio::cargarDisponibilidad(int idProfesional, const QDate &fecha, const QTime &desde, const QTime &hasta,
                                            const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_cargar_disponibilidad",
        { idProfesional, fecha.toString("yyyy-MM-dd"), desde.toString("HH:mm:ss"), hasta.toString("HH:mm:ss"), origen, idONulo(idUsuario) }));
}

Respuesta Repositorio::bajaDisponibilidad(int idDisponibilidad, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_baja_disponibilidad", { idDisponibilidad, origen, idONulo(idUsuario) }));
}

Respuesta Repositorio::asignarProtocolo(int idProfesional, int idProtocolo, bool habilitar, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_asignar_protocolo", { idProfesional, idProtocolo, habilitar ? 1 : 0, origen, idONulo(idUsuario) }));
}

Respuesta Repositorio::marcarNotificacion(int idNotificacion, const QString &resultado, const QString &detalle)
{
    return aRespuesta(base.llamar("notificaciones.sp_marcar_notificacion", { idNotificacion, resultado, textoONulo(detalle) }));
}

Resultado Repositorio::profesionalesParaProtocolos(const QVector<int> &idsProtocolo)
{
    return base.llamar("personas.sp_profesionales_para_protocolos", { lista(idsProtocolo) });
}

QVector<HorarioLibre> Repositorio::horariosLibres(const QDate &fecha, const QVector<int> &idsProtocolo, int idProfesional)
{
    QVector<HorarioLibre> out;
    const Resultado r = base.llamar("agenda.sp_horarios_libres", { fecha.toString("yyyy-MM-dd"), lista(idsProtocolo), idONulo(idProfesional) });
    error = r.ok ? QString() : r.error;
    for (const QVariantMap &f : r.filas) {
        HorarioLibre h;
        h.idProfesional = f.value("id_profesional").toInt();
        h.profesional = f.value("profesional").toString();
        h.inicio = QDateTime::fromString(f.value("inicio").toString(), FORMATO_FECHA_HORA);
        h.fin = QDateTime::fromString(f.value("fin").toString(), FORMATO_FECHA_HORA);
        out.append(h);
    }
    return out;
}

Respuesta Repositorio::altaTurno(int idPaciente, int idProfesional, const QDateTime &inicio, const QVector<int> &idsProtocolo,
                                 const QString &origen, int idUsuario, const QString &codigoCupon)
{
    return aRespuesta(base.llamar("agenda.sp_alta_turno",
        { idPaciente, idProfesional, inicio.toString(FORMATO_FECHA_HORA), lista(idsProtocolo), origen,
          idONulo(idUsuario), textoONulo(codigoCupon), QVariant() }));
}

Respuesta Repositorio::registrarSena(int idTurno, const QString &medioPago, const QString &codigoTarjeta,
                                     const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("pagos.sp_registrar_sena", { idTurno, medioPago, textoONulo(codigoTarjeta), idONulo(idUsuario), origen }));
}

Respuesta Repositorio::cancelarTurno(int idTurno, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("agenda.sp_cancelar_turno", { idTurno, idONulo(idUsuario), origen }));
}

/* Una fila de sp_buscar_turnos o sp_turnos_del_periodo → TurnoBD. */
TurnoBD Repositorio::aTurno(const QVariantMap &f)
{
    TurnoBD t;
    t.id = f.value("id_turno").toInt();
    t.idPaciente = f.value("id_paciente").toInt();
    t.paciente = f.value("paciente").toString();
    t.dni = f.value("dni").toString();
    t.telefono = f.value("telefono").toString();
    t.profesional = f.value("profesional").toString();
    t.inicio = QDateTime::fromString(f.value("fecha_hora_inicio").toString(), FORMATO_FECHA_HORA);
    t.fin = QDateTime::fromString(f.value("fecha_hora_fin").toString(), FORMATO_FECHA_HORA);
    t.estado = f.value("estado").toString();
    t.origen = f.value("origen").toString();
    t.protocolos = f.value("protocolos").toString();
    t.precioFinal = f.value("precio_final").toDouble();
    t.sena = f.value("sena").toDouble();
    t.estadoSena = f.value("estado_sena").toString();
    t.codigoOperacion = f.value("codigo_operacion").toString();
    t.recordatorioCanal = f.value("recordatorio_canal").toString();
    t.recordatorioEstado = f.value("recordatorio_estado").toString();
    t.recordatorioProgramado = QDateTime::fromString(f.value("recordatorio_programado").toString(), FORMATO_FECHA_HORA);
    return t;
}

QVector<TurnoBD> Repositorio::buscarTurnos(const QString &texto, bool soloVigentes)
{
    QVector<TurnoBD> out;
    const Resultado r = base.llamar("agenda.sp_buscar_turnos", { texto, soloVigentes ? 1 : 0 });
    error = r.ok ? QString() : r.error;
    for (const QVariantMap &f : r.filas)
        out.append(aTurno(f));
    return out;
}

QVector<TurnoBD> Repositorio::listarTurnos(const QDate &desde, const QDate &hasta)
{
    QVector<TurnoBD> out;
    const Resultado r = base.llamar("agenda.sp_turnos_del_periodo", { desde.toString("yyyy-MM-dd"), hasta.toString("yyyy-MM-dd") });
    error = r.ok ? QString() : r.error;
    for (const QVariantMap &f : r.filas)
        out.append(aTurno(f));
    return out;
}

/* Reportes 1 a 8: `sp` es el nombre con schema, por ejemplo
 * "pagos.sp_reporte_ingresos_sena". `extra` son los parámetros que siguen a las fechas. */
Resultado Repositorio::reporte(const QString &sp, const QDate &desde, const QDate &hasta, const QVariantList &extra)
{
    QVariantList p{ desde.toString("yyyy-MM-dd"), hasta.toString("yyyy-MM-dd") };
    p += extra;
    return base.llamar(sp, p);
}

Resultado Repositorio::auditoria(const QDate &desde, const QDate &hasta, const QString &tipoEvento,
                                 int idUsuario, int idPaciente, int exitoso, const QString &origen)
{
    return base.llamar("auditoria.sp_reporte_auditoria",
        { desde.toString("yyyy-MM-dd"), hasta.toString("yyyy-MM-dd"), textoONulo(tipoEvento), idONulo(idUsuario),
          idONulo(idPaciente), exitoso < 0 ? QVariant() : QVariant(exitoso), textoONulo(origen) });
}
