#include "datosprueba.h"

#include "sena.h"

namespace DatosPrueba {

QVector<Protocolo> protocolos()
{
    const Categoria faciales = { "Faciales", 30, false };
    const Categoria aparatologia = { "Aparatología", 30, false };
    const Categoria medicinaEstetica = { "Medicina estética", 30, false };
    return {
        { "Limpieza facial profunda", 60, 25000, faciales },
        { "Peeling químico", 45, 40000, faciales },
        { "Mesoterapia facial", 45, 55000, medicinaEstetica },
        { "Depilación láser (zona chica)", 30, 18000, aparatologia },
    };
}

/* El instituto no abre los domingos: esos turnos pasan al lunes. */
static QDateTime diaHabil(const QDate &dia, int hora)
{
    return QDateTime(dia.dayOfWeek() == Qt::Sunday ? dia.addDays(1) : dia, QTime(hora, 0));
}

static Turno turno(const QString &paciente, const QString &dni, const QString &telefono,
                   const Protocolo &p, const QDateTime &inicio, EstadoTurno estado,
                   const QString &origen, bool senaPagada)
{
    return { paciente, dni, telefono, p.nombre, p.precio,
             Sena::calcular(p.precio, p.categoria.porcentajeSena), inicio, inicio.addSecs(p.duracionMin * 60),
             estado, origen, senaPagada };
}

QVector<Turno> turnos(const QDate &hoy)
{
    const QVector<Protocolo> p = protocolos();
    return {
        turno("María Sosa", "30111222", "1155550102", p[0], QDateTime(hoy.addDays(-27), QTime(16, 0)),
              EstadoTurno::Realizado, "Terminal", true),
        turno("Carla Gómez", "33222111", "1155550177", p[2], diaHabil(hoy.addDays(1), 13),
              EstadoTurno::Confirmado, "Gestión", false),
        turno("María Sosa", "30111222", "1155550102", p[3], diaHabil(hoy.addDays(2), 9),
              EstadoTurno::Confirmado, "Web", true),
        turno("Lucía Fernández", "28444555", "1155550144", p[1], diaHabil(hoy.addDays(3), 17),
              EstadoTurno::Confirmado, "Gestión", true),
    };
}

QStringList horariosDelDia()
{
    return { "09:00", "10:30", "13:00", "15:30", "17:00" };
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

}
