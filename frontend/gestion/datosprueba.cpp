#include "datosprueba.h"

#include "reglas.h"

namespace DatosPrueba {

QVector<Protocolo> protocolos()
{
    return {
        { "Limpieza facial profunda", 60, 25000, false },
        { "Peeling químico", 45, 40000, false },
        { "Mesoterapia facial", 45, 55000, false },
        { "Depilación láser (zona chica)", 30, 18000, false },
    };
}

static Turno turno(const QString &paciente, const QString &dni, const QString &telefono,
                   const Protocolo &p, const QDateTime &fechaHora, bool senaPagada,
                   EstadoTurno estado)
{
    return { paciente, dni, telefono, p.nombre, fechaHora, p.duracionMin,
             Reglas::calcularSena(p.precio, p.esCirugia),
             senaPagada ? EstadoSena::Pagada : EstadoSena::Pendiente,
             senaPagada ? "Transferencia" : "",
             senaPagada ? "SIM-000100" : "", estado };
}

/* Primer día desde `dia` en que atiende el instituto (no abre los domingos). */
static QDate diaHabil(QDate dia)
{
    return dia.dayOfWeek() == Qt::Sunday ? dia.addDays(1) : dia;
}

QVector<Turno> turnos(const QDateTime &ahora)
{
    const QVector<Protocolo> p = protocolos();
    const QDate hoy = ahora.date();

    /* Primer horario que empieza dentro de más de 1 hora: casi siempre queda
     * a menos de 24 h, así se prueba la seña que no se reembolsa. */
    QDateTime pronto;
    for (QDate dia = hoy; !pronto.isValid(); dia = dia.addDays(1)) {
        if (dia.dayOfWeek() == Qt::Sunday)
            continue;
        for (const QString &hora : horariosDelDia()) {
            const QDateTime inicio(dia, QTime::fromString(hora, "HH:mm"));
            if (inicio > ahora.addSecs(3600)) {
                pronto = inicio;
                break;
            }
        }
    }

    return {
        turno("María Sosa", "30111222", "1155550102", p[0],
              QDateTime(hoy.addDays(-27), QTime(16, 0)), true, EstadoTurno::Realizado),
        turno("Carla Gómez", "33222111", "1155550177", p[2],
              pronto, true, EstadoTurno::Confirmado),
        turno("María Sosa", "30111222", "1155550102", p[3],
              QDateTime(diaHabil(hoy.addDays(2)), QTime(9, 0)), true, EstadoTurno::Confirmado),
        turno("Lucía Fernández", "28444555", "1155550144", p[1],
              QDateTime(diaHabil(hoy.addDays(3)), QTime(17, 0)), false, EstadoTurno::Confirmado),
        turno("Julieta Díaz", "35777888", "1155550133", p[3],
              QDateTime(diaHabil(hoy.addDays(4)), QTime(13, 0)), true, EstadoTurno::Confirmado),
    };
}

QStringList horariosDelDia()
{
    return { "09:00", "10:30", "13:00", "15:30", "17:00" };
}

QStringList mediosDePago()
{
    return { "Efectivo", "Transferencia", "Mercado Pago (simulado)", "Tarjeta de débito (simulado)" };
}

QString texto(EstadoTurno estado)
{
    switch (estado) {
    case EstadoTurno::Confirmado: return "Confirmado";
    case EstadoTurno::Realizado: return "Realizado";
    case EstadoTurno::Cancelado: return "Cancelado";
    }
    return {};
}

QString texto(EstadoSena estado)
{
    switch (estado) {
    case EstadoSena::Pendiente: return "sin pagar";
    case EstadoSena::Pagada: return "pagada";
    case EstadoSena::Reembolsada: return "reembolsada";
    case EstadoSena::Retenida: return "retenida";
    }
    return {};
}

}
