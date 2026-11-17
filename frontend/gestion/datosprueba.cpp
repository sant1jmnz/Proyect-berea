#include "datosprueba.h"

#include "catalogogenerado.h"
#include "sena.h"

namespace DatosPrueba {

/* Las cuatro categorías del catálogo (tabla maestra). */
QVector<Categoria> categorias()
{
    return {
        { "Faciales y corporales", 30, false, 1 },   /* el último número es el id en la base */
        { "Aparatología", 30, false, 2 },
        { "Medicina estética", 30, false, 3 },
        { "Cirugías", 40, true, 4 },
    };
}

/* Los mismos protocolos que la base y el sitio web (catálogo generado desde backend/02_datos.sql).
 * El id queda en 0: sin base no hay id que valga. */
QVector<Protocolo> protocolos()
{
    const QVector<Categoria> c = categorias();
    QVector<Protocolo> lista;
    for (const FilaCatalogo &f : CATALOGO) {
        Protocolo p;
        p.nombre = QString::fromUtf8(f.nombre);
        p.duracionMin = f.duracionMin;
        p.precio = f.precio;
        p.categoria = c[f.idCategoria - 1];
        p.descripcion = QString::fromUtf8(f.descripcion);
        lista.append(p);
    }
    return lista;
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

/* El protocolo del catálogo con ese nombre. */
static Protocolo porNombre(const QString &nombre)
{
    for (const Protocolo &p : protocolos())
        if (p.nombre == nombre)
            return p;
    return {};
}

QVector<Turno> turnos(const QDate &hoy)
{
    const Protocolo limpieza = porNombre("Limpieza facial profunda");
    const Protocolo peeling = porNombre("Peeling químico");
    const Protocolo mesoterapia = porNombre("Mesoterapia facial");
    const Protocolo laser = porNombre("Depilación láser (zona chica)");
    return {
        turno("María Sosa", "30111222", "1155550102", limpieza, QDateTime(hoy.addDays(-27), QTime(16, 0)),
              EstadoTurno::Realizado, "Terminal", true),
        turno("Carla Gómez", "33222111", "1155550177", mesoterapia, diaHabil(hoy.addDays(1), 13),
              EstadoTurno::Confirmado, "Gestión", false),
        turno("María Sosa", "30111222", "1155550102", laser, diaHabil(hoy.addDays(2), 9),
              EstadoTurno::Confirmado, "Web", true),
        turno("Lucía Fernández", "28444555", "1155550144", peeling, diaHabil(hoy.addDays(3), 17),
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
    return { "09:00", "10:00", "11:00", "12:00", "14:00", "15:00", "16:00", "17:00", "18:00" };   /* los mismos que el sitio web sin conexión */
}

QString texto(EstadoTurno estado)
{
    switch (estado) {
    case EstadoTurno::Confirmado: return "Confirmado";
    case EstadoTurno::Realizado: return "Realizado";
    case EstadoTurno::Cancelado: return "Cancelado";
    case EstadoTurno::Pendiente: return "Pendiente";
    case EstadoTurno::Ausente: return "Ausente";
    }
    return {};
}

}
