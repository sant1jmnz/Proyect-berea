#include "datosprueba.h"

#include "sena.h"

namespace DatosPrueba {

/* Las cuatro categorías del catálogo (tabla maestra). */
QVector<Categoria> categorias()
{
    return {
        { "Faciales y corporales", 30, false },
        { "Aparatología", 30, false },
        { "Medicina estética", 30, false },
        { "Cirugías", 40, true },
    };
}

QVector<Protocolo> protocolos()
{
    const QVector<Categoria> c = categorias();
    const Categoria faciales = c[0];
    const Categoria aparatologia = c[1];
    const Categoria medicinaEstetica = c[2];
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

QVector<Profesional> profesionales(const QDate &hoy)
{
    /* Lunes a viernes de 9 a 18 en los próximos días hábiles. */
    auto semana = [&](const QTime &desde, const QTime &hasta) {
        QVector<Franja> franjas;
        for (int i = 1; franjas.size() < 5 && i < 15; ++i) {
            const QDate dia = hoy.addDays(i);
            if (dia.dayOfWeek() < Qt::Saturday)
                franjas.append({ dia, desde, hasta, true });
        }
        return franjas;
    };
    return {
        { "Dra. Julieta Marino", "MN 112233", true,
          { "Limpieza facial profunda", "Peeling químico", "Mesoterapia facial" },
          semana(QTime(9, 0), QTime(13, 0)) },
        { "Dr. Andrés Quiroga", "MN 445566", true,
          { "Mesoterapia facial", "Depilación láser (zona chica)" },
          semana(QTime(13, 0), QTime(18, 0)) },
        { "Lic. Marcela Ibáñez", "MP 778899", false, { "Limpieza facial profunda" }, {} },
    };
}

QVector<Paciente> pacientes()
{
    return {
        { "María Sosa", "30111222", "1155550102", "maria.sosa@example.com", QDate(1984, 3, 12) },
        { "Carla Gómez", "33222111", "1155550177", "", QDate(1990, 11, 2) },
        { "Lucía Fernández", "28444555", "1155550144", "lucia.f@example.com", QDate(1981, 7, 25) },
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
