#include "conexionapp.h"

#include "repositorio.h"

ConexionApp::ConexionApp(AvisoConexion *franja, const ConfigBD &config,
                         const QString &archivoContingencia, QObject *parent)
    : QObject(parent), aviso(franja), base_(config), local(archivoContingencia)
{
    connect(aviso, &AvisoConexion::reintentar, this, &ConexionApp::probar);
}

bool ConexionApp::probar()
{
    const bool conectada = base_.conectar();
    if (conectada) {
        if (local.cantidad() > 0) {   // volvió la conexión: se envían los turnos guardados en este equipo
            QStringList problemas;
            const int enviados = sincronizar(&problemas);
            emit pendientesSincronizados(enviados, problemas);
        }
        aviso->mostrarConectado(local.cantidad());
        emit this->conectada();
    }
    else
        aviso->mostrarSinConexion(base_.ultimoError(), local.cantidad());
    return conectada;
}

bool ConexionApp::guardarEnContingencia(const TurnoPendiente &turno)
{
    const bool guardado = local.guardar(turno);
    aviso->actualizarPendientes(local.cantidad());
    return guardado;
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

        const Resultado paciente = repo.buscarPaciente(t.dni);
        int idProtocolo = 0;
        for (const ProtocoloBD &p : repo.listarProtocolos(t.protocolo)) {
            if (p.nombre.compare(t.protocolo, Qt::CaseInsensitive) == 0)
                idProtocolo = p.id;
        }
        int idProfesional = 0;
        if (idProtocolo > 0) {
            for (const HorarioLibre &h : repo.horariosLibres(t.inicio.date(), { idProtocolo })) {
                if (h.inicio == t.inicio) {
                    idProfesional = h.idProfesional;
                    break;
                }
            }
        }

        if (!paciente.ok || paciente.filas.isEmpty()) {
            motivo = QString("%1 (DNI %2) todavía no está en la base: hay que darla de alta.").arg(t.paciente, t.dni);
        } else if (idProtocolo == 0) {
            motivo = QString("El protocolo \"%1\" no está en el catálogo.").arg(t.protocolo);
        } else if (idProfesional == 0) {
            motivo = QString("El horario %1 ya no está libre.").arg(t.inicio.toString("dd/MM/yyyy HH:mm"));
        } else {
            const Respuesta turno = repo.altaTurno(paciente.filas.first().value("id_paciente").toInt(), idProfesional,
                                                   t.inicio, { idProtocolo }, origen);
            if (!turno.ok)
                motivo = turno.mensaje;
            else if (t.senaPagada)
                repo.registrarSena(turno.id, "efectivo", QString(), origen);
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
