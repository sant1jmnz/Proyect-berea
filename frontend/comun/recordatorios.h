/* Recordatorio de turno (RF-11): cada aviso queda registrado con canal,
 * estado y fecha programada (entidad Notificación de docs/modelo-entidades.md).
 * Por ahora vive en memoria; cuando exista la base se lee y se escribe con
 * stored procedures y n8n es quien los envía. */
#ifndef RECORDATORIOS_H
#define RECORDATORIOS_H

#include <QDateTime>
#include <QString>
#include <QVector>

/* Canal de notificación (tabla maestra). */
enum class CanalAviso { Telegram, WhatsApp, GoogleCalendar, WhatsAppAsistido };
/* Estado de notificación (tabla maestra). */
enum class EstadoAviso { Pendiente, Enviado, Fallido };

struct Aviso {
    QString paciente;
    QString dni;
    QString telefono;          /* solo dígitos */
    QDateTime inicioTurno;
    CanalAviso canal = CanalAviso::WhatsAppAsistido;
    EstadoAviso estado = EstadoAviso::Pendiente;
    QDateTime programado;      /* cuándo debe salir */
    QDateTime enviado;         /* vacío hasta que sale */
    int intentos = 0;
    QString mensaje;
    QString detalleError;      /* solo si falló */
};

namespace Recordatorios {

QString nombre(CanalAviso canal);
QString nombre(EstadoAviso estado);

/* El recordatorio sale 24 h antes del turno; si ese momento ya pasó (turno
 * cargado para mañana a la mañana), sale enseguida. */
QDateTime momentoDeEnvio(const QDateTime &inicioTurno, const QDateTime &ahora);

/* Texto del aviso, el mismo para todos los canales. */
QString mensaje(const QString &paciente, const QString &protocolo, const QDateTime &inicioTurno);

/* Enlace wa.me con el mensaje ya escrito (WhatsApp asistido: la recepción
 * toca el enlace y solo le falta enviar). Un celular de 10 dígitos
 * (11 5555-0102) se completa con el prefijo 549 de Argentina. */
QString enlaceWhatsApp(const QString &telefono, const QString &mensaje);

}

/* Lista de avisos, con la regla de qué hacer con cada uno. */
class RegistroAvisos
{
public:
    /* Programa el recordatorio de un turno. Sin Telegram vinculado se usa
     * WhatsApp asistido (arquitectura.md). Devuelve el aviso creado. */
    const Aviso &programar(const QString &paciente, const QString &dni, const QString &telefono,
                           const QString &protocolo, const QDateTime &inicioTurno,
                           const QDateTime &ahora, bool telegramVinculado = false);

    const QVector<Aviso> &todos() const { return avisos; }
    /* Avisos pendientes cuya hora ya llegó. */
    QVector<int> pendientesA(const QDateTime &ahora) const;
    /* Un aviso pasa a "enviado" o a "fallido"; cada intento se cuenta. */
    void marcarEnviado(int indice, const QDateTime &ahora);
    void marcarFallido(int indice, const QString &detalle);
    /* Si el turno se cancela, sus avisos pendientes ya no deben salir. */
    int anularDeTurno(const QString &dni, const QDateTime &inicioTurno);

private:
    QVector<Aviso> avisos;
};

#endif
