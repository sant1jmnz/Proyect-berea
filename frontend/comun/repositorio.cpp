#include <QRandomGenerator>
#include "repositorio.h"

#include <QStringList>

/* Los stored procedures devuelven el apellido en la columna `clave` y el nombre en `clave_nombre`
 * (el material de la cátedra no enseña CONCAT): acá se arma "Apellido, Nombre". */
static QString nombreCompleto(const QVariantMap &fila, const QString &clave)
{
    const QString apellido = fila.value(clave).toString();
    const QString nombre = fila.value(clave + "_nombre").toString();
    return nombre.isEmpty() ? apellido : apellido + ", " + nombre;
}

/* Formato de fecha y hora que usan los stored procedures. */
const QString FORMATO_FECHA_HORA = "yyyy-MM-dd HH:mm:ss";

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

/* Número a parámetro SQL: si el id es 0 o negativo manda NULL ("sin dato") en vez de 0. */
QVariant Repositorio::idONulo(int id)
{
    if (id > 0)
        return QVariant(id);
    return QVariant();
}

/* Texto a parámetro SQL: si está vacío manda NULL en vez de ''. */
QVariant Repositorio::textoONulo(const QString &texto)
{
    if (texto.isEmpty())
        return QVariant();
    return QVariant(texto);
}

/* Los SP reciben hasta 3 protocolos en parámetros separados: el que no se usa va en NULL. */
QVariant Repositorio::protocolo(const QVector<int> &ids, int posicion)
{
    if (posicion < ids.size())
        return QVariant(ids.at(posicion));
    return QVariant();
}

/* Inicia sesión: llama a seguridad.sp_login con usuario, clave, ip y origen. Origen válido: 'terminal', 'web', 'gestion' o 'sistema'.
 * Tras 5 intentos fallidos en 15 minutos el SP bloquea la cuenta un rato. */
Respuesta Repositorio::login(const QString &usuario, const QString &clave, const QString &ip, const QString &origen)
{
    return aRespuesta(base.llamar("seguridad.sp_login", { usuario, clave, textoONulo(ip), origen }));
}

/* Cierra la sesión: el SP solo deja el evento 'cierre_sesion' en el log (la ventana la cierra la app). */
Respuesta Repositorio::cerrarSesion(int idUsuario, const QString &origen)
{
    return aRespuesta(base.llamar("seguridad.sp_cerrar_sesion", { idONulo(idUsuario), origen, QVariant() }));
}

/* El paciente crea su cuenta de la app Cliente (seguridad.sp_crear_cuenta_paciente), validando su DNI. */
Respuesta Repositorio::crearCuentaPaciente(const QString &dni, const QString &usuario, const QString &email,
                                           const QString &clave, const QString &origen)
{
    return aRespuesta(base.llamar("seguridad.sp_crear_cuenta_paciente", { dni, usuario, email, clave, origen }));
}

/* Da de alta un paciente nuevo (personas.sp_alta_paciente). La fecha viaja como 'yyyy-MM-dd'. */
Respuesta Repositorio::altaPaciente(const QString &dni, const QString &nombre, const QString &apellido, const QDate &nacimiento,
                                    const QString &email, const QString &telefono, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_alta_paciente",
        { dni, nombre, apellido, nacimiento.toString("yyyy-MM-dd"), textoONulo(email), telefono, origen, idONulo(idUsuario) }));
}

/* Busca pacientes por texto (DNI, nombre o apellido) con personas.sp_buscar_paciente. Devuelve las filas tal cual. */
Resultado Repositorio::buscarPaciente(const QString &texto)
{
    return base.llamar("personas.sp_buscar_paciente", { texto });
}

/* Lista los tratamientos (protocolos) con clinica.sp_listar_protocolos y pasa cada fila a un ProtocoloBD.
 * Para cambiar qué datos de un tratamiento se muestran: agregar el campo en ProtocoloBD (repositorio.h) y leerlo acá. */
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

/* Crea un tratamiento nuevo (clinica.sp_alta_protocolo): categoría, nombre, precio y duración. */
Respuesta Repositorio::altaProtocolo(int idCategoria, const QString &nombre, const QString &descripcion, double precio,
                                     int duracionMin, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_alta_protocolo",
        { idCategoria, nombre, textoONulo(descripcion), precio, duracionMin, origen, idONulo(idUsuario) }));
}

/* Modifica un tratamiento (clinica.sp_modificar_protocolo). Así se cambia un PRECIO desde la app: el SP guarda el precio nuevo. */
Respuesta Repositorio::modificarProtocolo(int idProtocolo, const QString &nombre, const QString &descripcion, double precio,
                                          int duracionMin, bool activo, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_modificar_protocolo",
        { idProtocolo, nombre, textoONulo(descripcion), precio, duracionMin, activo ? 1 : 0, origen, idONulo(idUsuario) }));
}

/* Cambia nombre, apellido, mail o teléfono de un paciente (personas.sp_modificar_paciente). */
Respuesta Repositorio::modificarPaciente(int idPaciente, const QString &nombre, const QString &apellido, const QString &email,
                                         const QString &telefonoNuevo, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_modificar_paciente",
        { idPaciente, nombre, apellido, textoONulo(email), textoONulo(telefonoNuevo), origen, idONulo(idUsuario) }));
}

/* Lista todos los pacientes (personas.sp_listar_pacientes). */
Resultado Repositorio::listarPacientes() { return base.llamar("personas.sp_listar_pacientes"); }
/* Lista todos los profesionales (personas.sp_listar_profesionales). */
Resultado Repositorio::listarProfesionales() { return base.llamar("personas.sp_listar_profesionales"); }
/* Lista qué profesional atiende qué tratamiento (clinica.sp_listar_profesional_protocolo). */
Resultado Repositorio::listarProfesionalProtocolo() { return base.llamar("clinica.sp_listar_profesional_protocolo"); }

/* Lista los horarios que cargaron los profesionales desde una fecha (personas.sp_listar_disponibilidad). */
Resultado Repositorio::listarDisponibilidad(const QDate &desde)
{
    return base.llamar("personas.sp_listar_disponibilidad", { desde.toString("yyyy-MM-dd") });
}

/* Lista los avisos (recordatorios) programados entre dos fechas (notificaciones.sp_listar_notificaciones). */
Resultado Repositorio::listarNotificaciones(const QDate &desde, const QDate &hasta)
{
    return base.llamar("notificaciones.sp_listar_notificaciones", { desde.toString("yyyy-MM-dd"), hasta.toString("yyyy-MM-dd") });
}

/* Da de alta un profesional con su usuario y clave (personas.sp_alta_profesional). */
Respuesta Repositorio::altaProfesional(const QString &matricula, const QString &nombre, const QString &apellido, const QString &email,
                                       const QString &telefono, const QString &usuario, const QString &clave,
                                       const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_alta_profesional",
        { matricula, nombre, apellido, email, telefono, usuario, clave, origen, idONulo(idUsuario) }));
}

/* Modifica datos de un profesional o lo activa/desactiva (personas.sp_modificar_profesional). */
Respuesta Repositorio::modificarProfesional(int idProfesional, const QString &nombre, const QString &apellido, const QString &email,
                                            bool activo, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_modificar_profesional",
        { idProfesional, nombre, apellido, email, activo ? 1 : 0, origen, idONulo(idUsuario) }));
}

/* Carga un bloque de horario libre de un profesional: fecha, desde y hasta (personas.sp_cargar_disponibilidad). */
Respuesta Repositorio::cargarDisponibilidad(int idProfesional, const QDate &fecha, const QTime &desde, const QTime &hasta,
                                            const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_cargar_disponibilidad",
        { idProfesional, fecha.toString("yyyy-MM-dd"), desde.toString("HH:mm:ss"), hasta.toString("HH:mm:ss"), origen, idONulo(idUsuario) }));
}

/* Baja lógica de un bloque de disponibilidad. El SP no deja si hay turnos activos dentro del bloque. */
Respuesta Repositorio::bajaDisponibilidad(int idDisponibilidad, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("personas.sp_baja_disponibilidad", { idDisponibilidad, origen, idONulo(idUsuario) }));
}

/* Habilita o quita un tratamiento a un profesional (clinica.sp_asignar_protocolo). habilitar=true lo asigna. */
Respuesta Repositorio::asignarProtocolo(int idProfesional, int idProtocolo, bool habilitar, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_asignar_protocolo", { idProfesional, idProtocolo, habilitar ? 1 : 0, origen, idONulo(idUsuario) }));
}

/* n8n informa cómo salió el envío de un aviso. Un fallo se reintenta hasta 3 veces; recién al tercero queda 'fallida'. */
Respuesta Repositorio::marcarNotificacion(int idNotificacion, const QString &resultado, const QString &detalle)
{
    return aRespuesta(base.llamar("notificaciones.sp_marcar_notificacion", { idNotificacion, resultado, textoONulo(detalle) }));
}

/* Devuelve qué profesionales pueden hacer TODOS los tratamientos elegidos (hasta 3). */
Resultado Repositorio::profesionalesParaProtocolos(const QVector<int> &idsProtocolo)
{
    return base.llamar("personas.sp_profesionales_para_protocolos",
                       { protocolo(idsProtocolo, 0), protocolo(idsProtocolo, 1), protocolo(idsProtocolo, 2) });
}

/* Pide los horarios libres de un día para los tratamientos elegidos (agenda.sp_horarios_libres) y los pasa a HorarioLibre.
 * Si idProfesional es 0 trae todos los profesionales. */
QVector<HorarioLibre> Repositorio::horariosLibres(const QDate &fecha, const QVector<int> &idsProtocolo, int idProfesional)
{
    QVector<HorarioLibre> out;
    const Resultado r = base.llamar("agenda.sp_horarios_libres", { fecha.toString("yyyy-MM-dd"), protocolo(idsProtocolo, 0), protocolo(idsProtocolo, 1), protocolo(idsProtocolo, 2), idONulo(idProfesional) });
    error = r.ok ? QString() : r.error;
    for (const QVariantMap &f : r.filas) {
        HorarioLibre h;
        h.idProfesional = f.value("id_profesional").toInt();
        h.profesional = nombreCompleto(f, "profesional");
        h.inicio = QDateTime::fromString(f.value("inicio").toString(), FORMATO_FECHA_HORA);
        h.fin = QDateTime::fromString(f.value("fin").toString(), FORMATO_FECHA_HORA);
        out.append(h);
    }
    return out;
}

/* Reserva un turno (agenda.sp_alta_turno): paciente, profesional, inicio, hasta 3 tratamientos y cupón opcional.
 * El SP valida que no se pise con otro turno; si falla, Respuesta.ok es false y trae el motivo. */
Respuesta Repositorio::altaTurno(int idPaciente, int idProfesional, const QDateTime &inicio, const QVector<int> &idsProtocolo,
                                 const QString &origen, int idUsuario, const QString &codigoCupon)
{
    return aRespuesta(base.llamar("agenda.sp_alta_turno",
        { idPaciente, idProfesional, inicio.toString(FORMATO_FECHA_HORA),
          protocolo(idsProtocolo, 0), protocolo(idsProtocolo, 1), protocolo(idsProtocolo, 2), origen,
          idONulo(idUsuario), textoONulo(codigoCupon), QVariant() }));
}

/* Registra el pago de la seña de un turno (pagos.sp_registrar_sena). La app inventa el código de operación 'SIM-xxxxxx'. */
Respuesta Repositorio::registrarSena(int idTurno, const QString &medioPago, const QString &codigoTarjeta,
                                     const QString &origen, int idUsuario)
{
    /* El código de operación lo genera la aplicación (la base solo lo guarda). */
    const QString codigoOperacion = QString("SIM-%1").arg(QRandomGenerator::global()->bounded(100000, 1000000));
    return aRespuesta(base.llamar("pagos.sp_registrar_sena", { idTurno, medioPago, textoONulo(codigoTarjeta), idONulo(idUsuario), origen, codigoOperacion }));
}

/* Cancela un turno (agenda.sp_cancelar_turno). Con más de 24 h de anticipación la seña se reembolsa al 100%; con menos, queda retenida (lo decide el SP). */
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
    t.paciente = nombreCompleto(f, "paciente");
    t.dni = f.value("dni").toString();
    t.telefono = f.value("telefono").toString();
    t.profesional = nombreCompleto(f, "profesional");
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

/* Busca turnos por texto (DNI o nombre). soloVigentes=true oculta los pasados/cancelados. */
QVector<TurnoBD> Repositorio::buscarTurnos(const QString &texto, bool soloVigentes)
{
    QVector<TurnoBD> out;
    const Resultado r = base.llamar("agenda.sp_buscar_turnos", { texto, soloVigentes ? 1 : 0 });
    error = r.ok ? QString() : r.error;
    for (const QVariantMap &f : r.filas)
        out.append(aTurno(f));
    return out;
}

/* Trae todos los turnos entre dos fechas (agenda.sp_turnos_del_periodo). Alimenta la agenda de Gestión. */
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

/* Reporte de auditoría (quién hizo qué y cuándo) con filtros opcionales; exitoso -1 = sin filtro. */
Resultado Repositorio::auditoria(const QDate &desde, const QDate &hasta, const QString &tipoEvento,
                                 int idUsuario, int idPaciente, int exitoso, const QString &origen)
{
    return base.llamar("auditoria.sp_reporte_auditoria",
        { desde.toString("yyyy-MM-dd"), hasta.toString("yyyy-MM-dd"), textoONulo(tipoEvento), idONulo(idUsuario),
          idONulo(idPaciente), exitoso < 0 ? QVariant() : QVariant(exitoso), textoONulo(origen) });
}

/* Guarda en la base lo que se preguntó al asistente y si se derivó a una persona (asistente.sp_registrar_consulta). */
Respuesta Repositorio::registrarConsultaAsistente(int idPaciente, const QString &origen, const QString &pregunta,
                                                  const QString &respuesta, bool derivada)
{
    return aRespuesta(base.llamar("asistente.sp_registrar_consulta",
        { idONulo(idPaciente), origen, pregunta, textoONulo(respuesta), derivada ? 1 : 0, QVariant() }));
}

/* ---------------------------------------------------------------------------
 * Cupones, tarjetas de regalo y evaluaciones previas (pantallas de Gestión)
 * --------------------------------------------------------------------------- */

/* Lista cupones de descuento de un paciente por DNI (beneficios.sp_listar_cupones). */
Resultado Repositorio::listarCupones(const QString &dni)
{
    return base.llamar("beneficios.sp_listar_cupones", { dni });
}

/* Emite los cupones que corresponden según las reglas activas, solo a pacientes con cuenta (beneficios.sp_emitir_cupones).
 * Lo corre el sistema cada tanto; devuelve cuántos emitió. */
Respuesta Repositorio::emitirCupones(const QString &origen)
{
    return aRespuesta(base.llamar("beneficios.sp_emitir_cupones", { origen }));
}

/* Pide el token vigente de un cupón (lo muestra la app o el QR de la paciente). dato = token, valor = segundos que le quedan. */
/* notificaciones.sp_avisar_turno_perdido: el mensaje sale por Telegram si la paciente lo vinculó, si no queda en Avisos. */
Respuesta Repositorio::avisarTurnoPerdido(int idPaciente, const QDateTime &inicio, const QString &protocolo,
                                          const QString &opciones, const QString &origen)
{
    return aRespuesta(base.llamar("notificaciones.sp_avisar_turno_perdido",
                                  { idPaciente, inicio.toString(FORMATO_FECHA_HORA), protocolo, textoONulo(opciones), origen }));
}

Respuesta Repositorio::tokenCupon(const QString &codigo, int idPaciente)
{
    return aRespuesta(base.llamar("beneficios.sp_generar_token_cupon", { codigo, idPaciente }));
}

/* Valida y canjea un cupón con su token (beneficios.sp_validar_cupon). */
Respuesta Repositorio::validarCupon(const QString &codigo, const QString &token, int idPaciente,
                                    const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("beneficios.sp_validar_cupon",
                                  { codigo, token, idONulo(idPaciente), idONulo(idUsuario), origen }));
}

Respuesta Repositorio::comprarTarjeta(double monto, const QString &medioPago, const QString &comprador,
                                      const QString &telefono, const QString &origen, int idUsuario)
{
    /* El código de la tarjeta lo arma la aplicación, igual que los de la base (GC- y 24 letras
     * o números al azar): largo para que no se pueda adivinar. */
    QString codigo = "GC-";
    for (int i = 0; i < 24; ++i)
        codigo += QString::number(QRandomGenerator::global()->bounded(16), 16).toUpper();
    return aRespuesta(base.llamar("pagos.sp_comprar_tarjeta",
                                  { monto, medioPago, comprador, textoONulo(telefono), idONulo(idUsuario), origen, codigo }));
}

/* Consulta el saldo de una tarjeta de regalo (pagos.sp_saldo_tarjeta). */
Resultado Repositorio::saldoTarjeta(const QString &codigo, const QString &origen, int idUsuario)
{
    return base.llamar("pagos.sp_saldo_tarjeta", { codigo, idONulo(idUsuario), origen });
}

/* Lista los movimientos (compra y usos) de una tarjeta de regalo. */
Resultado Repositorio::movimientosTarjeta(const QString &codigo)
{
    return base.llamar("pagos.sp_movimientos_tarjeta", { codigo });
}

/* Lista las consultas de evaluación prequirúrgica (clinica.sp_listar_evaluaciones). soloPendientes=true filtra las sin resolver. */
Resultado Repositorio::listarEvaluaciones(bool soloPendientes)
{
    return base.llamar("clinica.sp_listar_evaluaciones", { soloPendientes ? 1 : 0 });
}

/* Lista los usuarios del sistema con su rol (seguridad.sp_listar_usuarios). */
Resultado Repositorio::listarUsuarios()
{
    return base.llamar("seguridad.sp_listar_usuarios", {});
}

/* Un administrador crea un usuario nuevo con rol (seguridad.sp_alta_usuario). */
Respuesta Repositorio::altaUsuario(int idAdmin, const QString &usuario, const QString &email, const QString &clave,
                                   const QString &rol, const QString &origen)
{
    return aRespuesta(base.llamar("seguridad.sp_alta_usuario", { idONulo(idAdmin), usuario, email, clave, rol, origen }));
}

/* Cambia la clave de un usuario pidiendo la actual (seguridad.sp_cambiar_clave). */
Respuesta Repositorio::cambiarClave(int idUsuario, const QString &actual, const QString &nueva, const QString &origen)
{
    return aRespuesta(base.llamar("seguridad.sp_cambiar_clave", { idONulo(idUsuario), actual, nueva, origen }));
}

/* El profesional carga el resultado de la consulta prequirúrgica con observaciones (clinica.sp_resolver_evaluacion).
 * Si no es apta, el instituto reembolsa. */
Respuesta Repositorio::resolverEvaluacion(int idEvaluacion, const QString &resultado, const QString &observaciones,
                                          const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_resolver_evaluacion",
                                  { idEvaluacion, resultado, textoONulo(observaciones), idONulo(idUsuario), origen }));
}

/* La paciente reclama una evaluación vencida: el instituto retiene el 50% de la consulta y devuelve el resto. Solo una vez. */
Respuesta Repositorio::reclamarEvaluacion(int idEvaluacion, const QString &origen, int idUsuario)
{
    return aRespuesta(base.llamar("clinica.sp_reclamar_evaluacion", { idEvaluacion, idONulo(idUsuario), origen }));
}

/* Evaluaciones aptas que vencieron (6 meses) sin cirugía agendada: el instituto se queda con el dinero. Tarea diaria de n8n. */
Respuesta Repositorio::vencerEvaluaciones(const QString &origen)
{
    return aRespuesta(base.llamar("clinica.sp_vencer_evaluaciones", { origen }));
}
