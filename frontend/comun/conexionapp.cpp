#include "conexionapp.h"
#include "formato.h"

#include "repositorio.h"

#include <QDate>
#include <QStringList>
#include <algorithm>

// Guarda el aviso de conexión, la base y el archivo de contingencia; el botón Reintentar del aviso vuelve a probar.
ConexionApp::ConexionApp(AvisoConexion *franja, const ConfigBD &config,
                         const QString &archivoContingencia, QObject *parent)
    : QObject(parent), aviso(franja), base_(config), local(archivoContingencia)
{
    connect(aviso, &AvisoConexion::reintentar, this, &ConexionApp::probar);
    connect(&vigia, &QTimer::timeout, this, &ConexionApp::vigilar);
    vigia.start(VIGILAR_CADA_MS);
    /* Si una consulta descubre el corte, se avisa ya (en cola: no se cambia de modo en medio de la consulta). */
    base_.alPerderConexion = [this] { QMetaObject::invokeMethod(this, "avisarCaida", Qt::QueuedConnection); };
}

// Franja "sin conexión" y señal conexionPerdida, una sola vez por corte (lo llame quien lo llame).
void ConexionApp::avisarCaida()
{
    if (!teniaConexion || caidaAvisada || base_.conectado())
        return;
    caidaAvisada = true;
    aviso->mostrarSinConexion(base_.ultimoError(), local.cantidad());
    emit conexionPerdida();
}

// Detecta el corte de conexión en pleno uso (muestra la franja) y reconecta sola cuando vuelve.
void ConexionApp::vigilar()
{
    if (base_.conectado())
        base_.verificar();   /* si falla, cierra la conexión */
    if (base_.conectado() || !teniaConexion)
        return;
    if (!caidaAvisada)
        avisarCaida();
    else
        probar();   /* si falla, solo refresca la franja */
}

// Intenta conectar. Si anda, sube los turnos guardados en el equipo y avisa; si no, muestra el error.
bool ConexionApp::probar()
{
    const bool conectada = base_.conectar();
    if (conectada) {
        teniaConexion = true;
        caidaAvisada = false;
        if (local.cantidad() > 0) {   // volvió la conexión: se envían los turnos guardados en este equipo
            QStringList problemas;
            const int enviados = sincronizar(&problemas);
            emit pendientesSincronizados(enviados, problemas);
        }
        aviso->mostrarConectado(local.cantidad());
        const QDateTime servidor = relojAvisado ? QDateTime() : base_.horaServidorUtc();
        emit this->conectada();   /* primero se abre la sesión; el aviso de reloj no la frena */
        if (servidor.isValid()) {
            const int minutos = int(servidor.secsTo(QDateTime::currentDateTimeUtc()) / 60);
            if (qAbs(minutos) >= TOLERANCIA_RELOJ_MIN) {
                relojAvisado = true;   /* una sola vez por sesión, no en cada reconexión */
                QTimer::singleShot(0, this, [this, minutos] { emit relojDesfasado(minutos); });
            }
        }
    }
    else {
        aviso->mostrarSinConexion(base_.ultimoError(), local.cantidad());
        avisarCaida();   /* si la conexión andaba y este intento también falló, que las ventanas pasen a modo local */
    }
    return conectada;
}

// Guarda un turno en el equipo cuando no hay base y actualiza el contador de pendientes.
bool ConexionApp::guardarEnContingencia(const TurnoPendiente &turno)
{
    const bool guardado = local.guardar(turno);
    aviso->actualizarPendientes(local.cantidad());
    return guardado;
}

/* Los horarios libres de los 7 días desde el turno perdido (hoy como mínimo), hasta 2 por día y 10 en total:
 * "lun 14/12 09:00, lun 14/12 10:00, ...". Es el texto que lee la paciente para reagendar. */
static QString opcionesDeLaSemana(Repositorio &repo, const QDate &desde, int idProtocolo)
{
    static const char *dias[] = { "lun", "mar", "mié", "jue", "vie", "sáb", "dom" };
    const QDateTime ahora = QDateTime::currentDateTime();
    QStringList opciones;
    for (QDate dia = qMax(desde, ahora.date()); dia < qMax(desde, ahora.date()).addDays(7) && opciones.size() < 10; dia = dia.addDays(1)) {
        QStringList horas;
        for (const HorarioLibre &h : repo.horariosLibres(dia, { idProtocolo })) {
            const QString hora = h.inicio.toString("HH:mm");
            if (h.inicio > ahora && !horas.contains(hora))
                horas.append(hora);
        }
        std::sort(horas.begin(), horas.end());
        for (int i = 0; i < horas.size() && i < 2 && opciones.size() < 10; ++i)
            opciones.append(QString("%1 %2 %3").arg(dias[dia.dayOfWeek() - 1], dia.toString("dd/MM"), horas[i]));
    }
    return opciones.join(", ");
}

/* Manda a la base, uno por uno, los turnos guardados en contingencia. Para cada uno busca la paciente
 * (por DNI), el protocolo (por nombre) y el profesional libre en ese horario, y llama a sp_alta_turno
 * y, si la seña estaba paga, a sp_registrar_sena. */
int ConexionApp::sincronizar(QStringList *problemas)
{
    if (!hayConexion())
        return 0;
    Repositorio repo(base_);
    QVector<TurnoPendiente> quedan;
    int enviados = 0;

    for (const TurnoPendiente &t : local.pendientes()) {
        QString motivo;
        const QString origen = t.origen == "Gestión" ? "gestion" : t.origen.toLower();   // "Terminal" → "terminal"

        Resultado paciente = repo.buscarPaciente(t.dni);
        /* Paciente nueva reservada sin conexión: se la da de alta. Si no se sabe su nacimiento (la columna es
         * NOT NULL y el SP no lo deja modificar después) va 1900-01-01, que significa "no informada". */
        if (paciente.ok && paciente.filas.isEmpty()) {
            QString nombre, apellido;
            Formato::separarNombre(t.paciente, &nombre, &apellido);
            const QDate nacimiento = t.nacimiento.isValid() ? t.nacimiento : QDate(1900, 1, 1);
            if (repo.altaPaciente(t.dni, nombre, apellido, nacimiento, QString(), t.telefono, origen).ok)
                paciente = repo.buscarPaciente(t.dni);
        }
        int idProtocolo = 0;
        for (const ProtocoloBD &p : repo.listarProtocolos(t.protocolo)) {
            if (p.nombre.compare(t.protocolo, Qt::CaseInsensitive) == 0)
                idProtocolo = p.id;
        }
        /* El horario se busca en la base. Si el Cliente anotó con qué profesional lo eligió, se prefiere ese; si ya
         * no está libre con él (o es un pendiente viejo), sirve cualquier otro profesional libre a esa hora. */
        int idProfesional = 0;
        if (idProtocolo > 0) {
            for (const HorarioLibre &h : repo.horariosLibres(t.inicio.date(), { idProtocolo })) {
                if (h.inicio != t.inicio)
                    continue;
                if (idProfesional == 0 || h.idProfesional == t.profesional)
                    idProfesional = h.idProfesional;
            }
        }

        if (!paciente.ok || paciente.filas.isEmpty()) {
            motivo = QString("%1 (DNI %2) todavía no está en la base: hay que darla de alta.").arg(t.paciente, t.dni);
        } else if (idProtocolo == 0) {
            motivo = QString("El protocolo \"%1\" no está en el catálogo.").arg(t.protocolo);
        } else if (idProfesional == 0) {
            motivo = QString("El horario %1 ya no está libre.").arg(t.inicio.toString("dd/MM/yyyy HH:mm"));
            /* Se le avisa a la paciente (Telegram o recepción) con los horarios que sí quedan esa semana. */
            const Respuesta av = repo.avisarTurnoPerdido(paciente.filas.first().value("id_paciente").toInt(), t.inicio,
                                                            t.protocolo, opcionesDeLaSemana(repo, t.inicio.date(), idProtocolo), origen);
            motivo += av.ok ? (av.dato == "Telegram" ? " Se le avisó por Telegram." : " Se dejó el aviso en Avisos para la recepción.")
                            : QString(" No se pudo avisarle: %1").arg(av.mensaje);
        } else {
            const Respuesta turno = repo.altaTurno(paciente.filas.first().value("id_paciente").toInt(), idProfesional,
                                                   t.inicio, { idProtocolo }, origen);
            if (!turno.ok)
                motivo = turno.mensaje;
            else if (t.senaPagada) {
                /* El turno ya está en la base: aunque la seña falle NO se reenvía (saldría duplicado). */
                const Respuesta sena = repo.registrarSena(turno.id, "efectivo", QString(), origen);
                if (!sena.ok && problemas)
                    problemas->append(QString("%1, %2: el turno se cargó pero la seña no se pudo registrar (%3). "
                                              "Registrala desde Gestión.")
                                          .arg(t.paciente, t.inicio.toString("dd/MM HH:mm"), sena.mensaje));
            }
        }

        if (motivo.isEmpty()) {
            ++enviados;
        } else {
            quedan.append(t);
            if (problemas)
                problemas->append(QString("%1, %2: %3").arg(t.paciente, t.inicio.toString("dd/MM HH:mm"), motivo));
        }
    }
    local.reemplazar(quedan);
    aviso->actualizarPendientes(local.cantidad());
    return enviados;
}
