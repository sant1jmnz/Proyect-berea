#include "recordatorios.h"

#include <QLocale>
#include <QUrl>

namespace Recordatorios {

// Nombre legible del canal por el que sale el aviso.
QString nombre(CanalAviso canal)
{
    switch (canal) {
    case CanalAviso::Telegram: return "Telegram";
    case CanalAviso::WhatsApp: return "WhatsApp";
    case CanalAviso::GoogleCalendar: return "Google Calendar";
    case CanalAviso::WhatsAppAsistido: return "WhatsApp asistido";
    }
    return {};
}

// Nombre legible del estado del aviso.
QString nombre(EstadoAviso estado)
{
    switch (estado) {
    case EstadoAviso::Pendiente: return "Pendiente";
    case EstadoAviso::Enviado: return "Enviado";
    case EstadoAviso::Fallido: return "Fallido";
    }
    return {};
}

// El aviso se programa 24 horas antes del turno; si ya falta menos, sale ahora.
QDateTime momentoDeEnvio(const QDateTime &inicioTurno, const QDateTime &ahora)
{
    const QDateTime ideal = inicioTurno.addDays(-1);
    return ideal > ahora ? ideal : ahora;
}

// Texto del recordatorio: saluda con el primer nombre de la paciente e incluye protocolo, día y hora.
QString mensaje(const QString &paciente, const QString &protocolo, const QDateTime &inicioTurno)
{
    const QLocale es(QLocale::Spanish, QLocale::Argentina);
    return QString("Hola %1, te recordamos tu turno de %2 en Dermalia el %3 a las %4. "
                   "Si no podés venir, avisanos con más de 24 horas de anticipación.")
        .arg(paciente.section(' ', 0, 0), protocolo,
             es.toString(inicioTurno.date(), "dddd d 'de' MMMM"),
             inicioTurno.toString("HH:mm"));
}

// Arma el enlace wa.me con el texto ya codificado. Deja solo los dígitos del teléfono
// y le agrega el prefijo de Argentina (54 y el 9 de celular) si falta.
QString enlaceWhatsApp(const QString &telefono, const QString &texto)
{
    QString numero;
    for (const QChar c : telefono)
        if (c.isDigit())
            numero += c;
    if (numero.size() == 10)          /* 1155550102 → 5491155550102 */
        numero.prepend("549");
    else if (numero.size() == 12 && numero.startsWith("54"))   /* 541155550102 */
        numero.insert(2, '9');
    return QString("https://wa.me/%1?text=%2")
        .arg(numero, QString::fromLatin1(QUrl::toPercentEncoding(texto)));
}

}

// Crea un aviso pendiente. Va por Telegram si la paciente lo vinculó; si no, por WhatsApp asistido.
const Aviso &RegistroAvisos::programar(const QString &paciente, const QString &dni,
                                       const QString &telefono, const QString &protocolo,
                                       const QDateTime &inicioTurno, const QDateTime &ahora,
                                       bool telegramVinculado)
{
    Aviso a;
    a.paciente = paciente;
    a.dni = dni;
    a.telefono = telefono;
    a.inicioTurno = inicioTurno;
    a.canal = telegramVinculado ? CanalAviso::Telegram : CanalAviso::WhatsAppAsistido;
    a.programado = Recordatorios::momentoDeEnvio(inicioTurno, ahora);
    a.mensaje = Recordatorios::mensaje(paciente, protocolo, inicioTurno);
    avisos.append(a);
    return avisos.last();
}

// Índices de los avisos pendientes cuya hora de envío ya llegó.
QVector<int> RegistroAvisos::pendientesA(const QDateTime &ahora) const
{
    QVector<int> lista;
    for (int i = 0; i < avisos.size(); ++i)
        if (avisos[i].estado == EstadoAviso::Pendiente && avisos[i].programado <= ahora)
            lista.append(i);
    return lista;
}

// Marca el aviso como enviado, suma un intento y borra el error anterior. Ignora índices inválidos.
void RegistroAvisos::marcarEnviado(int indice, const QDateTime &ahora)
{
    if (indice < 0 || indice >= avisos.size())
        return;
    Aviso &a = avisos[indice];
    a.estado = EstadoAviso::Enviado;
    a.enviado = ahora;
    a.intentos += 1;
    a.detalleError.clear();
}

// Marca el aviso como fallido, suma un intento y guarda el motivo del error.
void RegistroAvisos::marcarFallido(int indice, const QString &detalle)
{
    if (indice < 0 || indice >= avisos.size())
        return;
    Aviso &a = avisos[indice];
    a.estado = EstadoAviso::Fallido;
    a.intentos += 1;
    a.detalleError = detalle;
}

// Quita los avisos pendientes de un turno (por DNI y hora), por ejemplo si se cancela. Devuelve cuántos quitó.
// Recorre de atrás para adelante para poder borrar sin saltear elementos.
int RegistroAvisos::anularDeTurno(const QString &dni, const QDateTime &inicioTurno)
{
    int anulados = 0;
    for (int i = avisos.size() - 1; i >= 0; --i) {
        if (avisos[i].dni == dni && avisos[i].inicioTurno == inicioTurno
            && avisos[i].estado == EstadoAviso::Pendiente) {
            avisos.removeAt(i);
            ++anulados;
        }
    }
    return anulados;
}
