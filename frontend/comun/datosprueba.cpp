#include "datosprueba.h"

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

/* El catálogo de los 44 protocolos, el mismo de la base y del sitio web
 * (comun/fichas.generado.json, que arma web/scripts/generar-catalogo.mjs). */
QVector<Protocolo> protocolos()
{
    const QVector<Categoria> c = categorias();
    QVector<Protocolo> lista;
    for (const ResumenTratamiento::ProtocoloDelCatalogo &p : ResumenTratamiento::catalogo()) {
        Categoria categoria = c[0];
        for (const Categoria &cat : c)
            if (cat.id == p.idCategoria)
                categoria = cat;
        Protocolo protocolo = { p.nombre, p.duracionMin, p.precio, categoria };
        protocolo.descripcion = p.descripcion;
        lista << protocolo;   /* id = 0: es un dato local; con la base se usa el id de la base */
    }
    return lista;
}

/* El instituto no abre los domingos: esos turnos pasan al lunes. */
static QDateTime diaHabil(const QDate &dia, int hora)
{
    return QDateTime(dia.dayOfWeek() == Qt::Sunday ? dia.addDays(1) : dia, QTime(hora, 0));
}

// Arma un turno de ejemplo: la seña sale del precio y del porcentaje de la categoría, el fin de la duración.
static Turno turno(const QString &paciente, const QString &dni, const QString &telefono,
                   const Protocolo &p, const QDateTime &inicio, EstadoTurno estado,
                   const QString &origen, bool senaPagada)
{
    return { paciente, dni, telefono, p.nombre, p.precio,
             Sena::calcular(p.precio, p.categoria.porcentajeSena), inicio, inicio.addSecs(p.duracionMin * 60),
             estado, origen, senaPagada };
}

// Cuatro turnos de ejemplo alrededor de hoy (uno ya realizado y tres a futuro) para el modo sin base.
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

// Tres profesionales de ejemplo; la última está inactiva y sin franjas.
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

// Tres pacientes de ejemplo; los teléfonos y mails son ficticios.
QVector<Paciente> pacientes()
{
    return {
        { "María Sosa", "30111222", "1155550102", "maria.sosa@example.com", QDate(1984, 3, 12) },
        { "Carla Gómez", "33222111", "1155550177", "", QDate(1990, 11, 2) },
        { "Lucía Fernández", "28444555", "1155550144", "lucia.f@example.com", QDate(1981, 7, 25) },
    };
}

// Los cinco horarios fijos de turno de cada día.
QStringList horariosDelDia()
{
    return { "09:00", "10:30", "13:00", "15:30", "17:00" };
}

// Nombre legible del estado del turno.
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

// Pasa un protocolo al formato Tratamiento que usa la pantalla del cliente.
Tratamiento comoTratamiento(const Protocolo &p)
{
    Tratamiento t;
    t.id = p.id;
    t.nombre = p.nombre;
    t.categoria = p.categoria.nombre;
    t.descripcion = p.descripcion;
    t.precio = p.precio;
    t.duracionMin = p.duracionMin;
    t.porcentajeSena = p.categoria.porcentajeSena;
    t.esCirugia = p.categoria.requiereEvaluacion;
    return t;
}

// Igual que comoTratamiento pero para toda la lista; deja afuera los protocolos inactivos.
QVector<Tratamiento> comoTratamientos(const QVector<Protocolo> &protocolos)
{
    QVector<Tratamiento> lista;
    for (const Protocolo &p : protocolos)
        if (p.activo)
            lista << comoTratamiento(p);
    return lista;
}

}
