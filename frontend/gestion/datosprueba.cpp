#include "datosprueba.h"

namespace DatosPrueba {

QVector<Protocolo> protocolos()
{
    return {
        { "Limpieza facial profunda", 60, 25000 },
        { "Peeling químico", 45, 40000 },
        { "Mesoterapia facial", 45, 55000 },
        { "Depilación láser (zona chica)", 30, 18000 },
    };
}

/* El instituto no abre los domingos: esos turnos pasan al lunes. */
static QDateTime diaHabil(const QDate &dia, int hora)
{
    return QDateTime(dia.dayOfWeek() == Qt::Sunday ? dia.addDays(1) : dia, QTime(hora, 0));
}

QVector<Turno> turnos(const QDate &hoy)
{
    return {
        { "María Sosa", "30111222", "1155550102", "Limpieza facial profunda",
          QDateTime(hoy.addDays(-27), QTime(16, 0)), true },
        { "Carla Gómez", "33222111", "1155550177", "Mesoterapia facial",
          diaHabil(hoy.addDays(1), 13), false },
        { "María Sosa", "30111222", "1155550102", "Depilación láser (zona chica)",
          diaHabil(hoy.addDays(2), 9), true },
        { "Lucía Fernández", "28444555", "1155550144", "Peeling químico",
          diaHabil(hoy.addDays(3), 17), true },
    };
}

QStringList horariosDelDia()
{
    return { "09:00", "10:30", "13:00", "15:30", "17:00" };
}

}
