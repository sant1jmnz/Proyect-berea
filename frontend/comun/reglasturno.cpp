#include "reglasturno.h"

#include "datosprueba.h"
#include "formato.h"
#include "reembolso.h"

#include <QRandomGenerator>
#include <algorithm>

namespace ReglasTurno {

// Reglas del turno que no necesitan base de datos (se usan en modo contingencia y en las pruebas).

// Un horario está ocupado si ya hay un turno a esa hora que no esté cancelado.
bool horarioOcupado(const QVector<Turno> &turnos, const QDateTime &inicio)
{
    return std::any_of(turnos.cbegin(), turnos.cend(), [&](const Turno &t) {
        return t.inicio == inicio && t.estado != EstadoTurno::Cancelado;
    });
}

// Horarios libres de un día: no hay turnos los domingos, y se descartan los que ya pasaron o están ocupados.
QStringList horariosLibresSinBase(const QDate &dia, const QVector<Turno> &turnos, const QDateTime &ahora)
{
    QStringList libres;
    if (dia.dayOfWeek() == Qt::Sunday)
        return libres;
    for (const QString &hora : DatosPrueba::horariosDelDia()) {
        const QDateTime inicio(dia, QTime::fromString(hora, "HH:mm"));
        if (inicio > ahora && !horarioOcupado(turnos, inicio))
            libres << hora;
    }
    return libres;
}

// Un turno es vigente si está confirmado o pendiente y todavía no empezó.
bool esVigente(const Turno &t, const QDateTime &ahora)
{
    return (t.estado == EstadoTurno::Confirmado || t.estado == EstadoTurno::Pendiente) && t.inicio > ahora;
}

// Código de operación "SIM-" + 6 dígitos; se repite el sorteo hasta que no coincida con el de otro turno.
QString nuevoCodigoOperacion(const QVector<Turno> &turnos)
{
    for (;;) {
        const QString codigo = QString("SIM-%1").arg(QRandomGenerator::global()->bounded(100000, 1000000));
        const bool usado = std::any_of(turnos.cbegin(), turnos.cend(),
                                       [&](const Turno &t) { return t.codigoOperacion == codigo; });
        if (!usado)
            return codigo;
    }
}

// Texto para mostrar si se devuelve la seña. El monto lo calcula Reembolso::monto (límite en horas).
QString explicacionReembolso(const Turno &t, const QDateTime &ahora)
{
    if (!t.senaPagada)
        return "La seña no estaba pagada: no hay nada que devolver.";
    const int devolver = Reembolso::monto(t.sena, t.senaPagada, t.inicio, ahora);
    if (devolver > 0)
        return QString("Faltan más de %1 horas: se devuelve la seña completa (%2).")
            .arg(Reembolso::HORAS_LIMITE).arg(Formato::pesos(devolver));
    return QString("Faltan %1 horas o menos: la seña (%2) no se devuelve.")
        .arg(Reembolso::HORAS_LIMITE).arg(Formato::pesos(t.sena));
}

}
