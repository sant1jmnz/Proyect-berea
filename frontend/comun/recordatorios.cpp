#include "recordatorios.h"

#include <QLocale>
#include <QUrl>

namespace Recordatorios {

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

QString nombre(EstadoAviso estado)
{
    switch (estado) {
    case EstadoAviso::Pendiente: return "Pendiente";
    case EstadoAviso::Enviado: return "Enviado";
    case EstadoAviso::Fallido: return "Fallido";
    }
    return {};
}

QDateTime momentoDeEnvio(const QDateTime &inicioTurno, const QDateTime &ahora)
{
    const QDateTime ideal = inicioTurno.addDays(-1);
    return ideal > ahora ? ideal : ahora;
}

QString mensaje(const QString &paciente, const QString &protocolo, const QDateTime &inicioTurno)
{
    const QLocale es(QLocale::Spanish, QLocale::Argentina);
    return QString("Hola %1, te recordamos tu turno de %2 en Dermalia el %3 a las %4. "
                   "Si no podés venir, avisanos con más de 24 horas de anticipación.")
        .arg(paciente.section(' ', 0, 0), protocolo,
             es.toString(inicioTurno.date(), "dddd d 'de' MMMM"),
             inicioTurno.toString("HH:mm"));
}

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

QVector<int> RegistroAvisos::pendientesA(const QDateTime &ahora) const
{
    QVector<int> lista;
    for (int i = 0; i < avisos.size(); ++i)
        if (avisos[i].estado == EstadoAviso::Pendiente && avisos[i].programado <= ahora)
            lista.append(i);
    return lista;
}

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

void RegistroAvisos::marcarFallido(int indice, const QString &detalle)
{
    if (indice < 0 || indice >= avisos.size())
        return;
    Aviso &a = avisos[indice];
    a.estado = EstadoAviso::Fallido;
    a.intentos += 1;
    a.detalleError = detalle;
}

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
