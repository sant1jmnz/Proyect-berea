#include "repositorio.h"

#include <QCryptographicHash>
#include <QStringList>

namespace {
const char *FORMATO_FECHA_HORA = "yyyy-MM-dd HH:mm:ss";
}

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

QVector<ProtocoloBD> Repositorio::listarProtocolos(const QString &texto, int idCategoria)
{
    QVector<ProtocoloBD> out;
    const Resultado r = base.llamar("clinica.sp_listar_protocolos", { textoONulo(texto), idONulo(idCategoria) });
    error = r.ok ? QString() : r.error;
    for (const QVariantMap &f : r.filas) {
        ProtocoloBD p;
        p.id = f.value("id_protocolo").toInt();
        p.nombre = f.value("nombre").toString();
        p.categoria = f.value("categoria").toString();
        p.precio = f.value("precio").toDouble();
        p.duracionMin = f.value("duracion_min").toInt();
        p.porcentajeSena = f.value("porcentaje_sena").toDouble();
        p.sena = f.value("sena").toDouble();
        p.requiereEvaluacion = f.value("requiere_evaluacion").toInt() == 1;
        out.append(p);
    }
    return out;
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

QVector<TurnoBD> Repositorio::buscarTurnos(const QString &texto, bool soloVigentes)
{
    QVector<TurnoBD> out;
    const Resultado r = base.llamar("agenda.sp_buscar_turnos", { texto, soloVigentes ? 1 : 0 });
    error = r.ok ? QString() : r.error;
    for (const QVariantMap &f : r.filas) {
        TurnoBD t;
        t.id = f.value("id_turno").toInt();
        t.paciente = f.value("paciente").toString();
        t.dni = f.value("dni").toString();
        t.profesional = f.value("profesional").toString();
        t.inicio = QDateTime::fromString(f.value("fecha_hora_inicio").toString(), FORMATO_FECHA_HORA);
        t.fin = QDateTime::fromString(f.value("fecha_hora_fin").toString(), FORMATO_FECHA_HORA);
        t.estado = f.value("estado").toString();
        t.origen = f.value("origen").toString();
        t.protocolos = f.value("protocolos").toString();
        t.precioFinal = f.value("precio_final").toDouble();
        t.sena = f.value("sena").toDouble();
        t.estadoSena = f.value("estado_sena").toString();
        out.append(t);
    }
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
