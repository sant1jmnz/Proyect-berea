#include "almacenlocal.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>

namespace AlmacenLocal {

static const int VERSION = 1;
static const char *FORMATO_FECHA = "yyyy-MM-dd";

QString rutaPorDefecto()
{
    const QString entorno = qEnvironmentVariable("DERMALIA_DATOS_LOCAL");
    if (!entorno.isEmpty())
        return entorno;
    return QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/Dermalia/datos_local.json";
}

/* ---- a JSON ---- */

static QJsonObject aJson(const Categoria &c)
{
    return { { "nombre", c.nombre }, { "porcentajeSena", c.porcentajeSena },
             { "requiereEvaluacion", c.requiereEvaluacion }, { "id", c.id } };
}

static QJsonObject aJson(const Protocolo &p)
{
    return { { "nombre", p.nombre }, { "duracionMin", p.duracionMin }, { "precio", p.precio },
             { "categoria", aJson(p.categoria) }, { "activo", p.activo }, { "id", p.id },
             { "descripcion", p.descripcion } };
}

static QJsonObject aJson(const Turno &t)
{
    return { { "paciente", t.paciente }, { "dni", t.dni }, { "telefono", t.telefono },
             { "protocolo", t.protocolo }, { "precioAplicado", t.precioAplicado }, { "sena", t.sena },
             { "inicio", t.inicio.toString(Qt::ISODate) }, { "fin", t.fin.toString(Qt::ISODate) },
             { "estado", static_cast<int>(t.estado) }, { "origen", t.origen },
             { "senaPagada", t.senaPagada }, { "codigoOperacion", t.codigoOperacion },
             { "reembolsado", t.reembolsado }, { "profesional", t.profesional } };
}

static QJsonObject aJson(const Franja &f)
{
    return { { "fecha", f.fecha.toString(FORMATO_FECHA) }, { "desde", f.desde.toString("HH:mm") },
             { "hasta", f.hasta.toString("HH:mm") }, { "activa", f.activa } };
}

static QJsonObject aJson(const Profesional &p)
{
    QJsonArray franjas;
    for (const Franja &f : p.franjas)
        franjas.append(aJson(f));
    return { { "nombre", p.nombre }, { "matricula", p.matricula }, { "activo", p.activo },
             { "protocolos", QJsonArray::fromStringList(p.protocolos) }, { "franjas", franjas },
             { "email", p.email } };
}

static QJsonObject aJson(const Paciente &p)
{
    return { { "nombre", p.nombre }, { "dni", p.dni }, { "telefono", p.telefono }, { "email", p.email },
             { "nacimiento", p.nacimiento.isValid() ? p.nacimiento.toString(FORMATO_FECHA) : QString() } };
}

template <typename T>
static QJsonArray lista(const QVector<T> &elementos)
{
    QJsonArray a;
    for (const T &e : elementos)
        a.append(aJson(e));
    return a;
}

/* ---- desde JSON (con valores por defecto si falta algún campo) ---- */

static Categoria categoriaDe(const QJsonObject &o)
{
    return { o["nombre"].toString(), o["porcentajeSena"].toInt(30), o["requiereEvaluacion"].toBool(),
             o["id"].toInt() };
}

static Protocolo protocoloDe(const QJsonObject &o)
{
    Protocolo p;
    p.nombre = o["nombre"].toString();
    p.duracionMin = o["duracionMin"].toInt();
    p.precio = o["precio"].toInt();
    p.categoria = categoriaDe(o["categoria"].toObject());
    p.activo = o["activo"].toBool(true);
    p.id = o["id"].toInt();
    p.descripcion = o["descripcion"].toString();
    return p;
}

static Turno turnoDe(const QJsonObject &o)
{
    Turno t;
    t.paciente = o["paciente"].toString();
    t.dni = o["dni"].toString();
    t.telefono = o["telefono"].toString();
    t.protocolo = o["protocolo"].toString();
    t.precioAplicado = o["precioAplicado"].toInt();
    t.sena = o["sena"].toInt();
    t.inicio = QDateTime::fromString(o["inicio"].toString(), Qt::ISODate);
    t.fin = QDateTime::fromString(o["fin"].toString(), Qt::ISODate);
    const int estado = o["estado"].toInt();
    t.estado = (estado >= 0 && estado <= static_cast<int>(EstadoTurno::Ausente))
                   ? static_cast<EstadoTurno>(estado) : EstadoTurno::Confirmado;
    t.origen = o["origen"].toString();
    t.senaPagada = o["senaPagada"].toBool();
    t.codigoOperacion = o["codigoOperacion"].toString();
    t.reembolsado = o["reembolsado"].toInt();
    t.profesional = o["profesional"].toString();
    return t;
}

static Franja franjaDe(const QJsonObject &o)
{
    Franja f;
    f.fecha = QDate::fromString(o["fecha"].toString(), FORMATO_FECHA);
    f.desde = QTime::fromString(o["desde"].toString(), "HH:mm");
    f.hasta = QTime::fromString(o["hasta"].toString(), "HH:mm");
    f.activa = o["activa"].toBool(true);
    return f;
}

static Profesional profesionalDe(const QJsonObject &o)
{
    Profesional p;
    p.nombre = o["nombre"].toString();
    p.matricula = o["matricula"].toString();
    p.activo = o["activo"].toBool(true);
    for (const QJsonValue &v : o["protocolos"].toArray())
        p.protocolos << v.toString();
    for (const QJsonValue &v : o["franjas"].toArray())
        p.franjas.append(franjaDe(v.toObject()));
    p.email = o["email"].toString();
    return p;
}

static Paciente pacienteDe(const QJsonObject &o)
{
    Paciente p;
    p.nombre = o["nombre"].toString();
    p.dni = o["dni"].toString();
    p.telefono = o["telefono"].toString();
    p.email = o["email"].toString();
    p.nacimiento = QDate::fromString(o["nacimiento"].toString(), FORMATO_FECHA);
    return p;
}

bool leer(const QString &ruta, Datos *datos)
{
    QFile archivo(ruta);
    if (!archivo.open(QIODevice::ReadOnly))
        return false;
    QJsonParseError error;
    const QJsonDocument doc = QJsonDocument::fromJson(archivo.readAll(), &error);
    if (error.error != QJsonParseError::NoError || !doc.isObject())
        return false;
    const QJsonObject raiz = doc.object();

    Datos leidos;
    for (const QJsonValue &v : raiz["protocolos"].toArray())
        leidos.protocolos.append(protocoloDe(v.toObject()));
    for (const QJsonValue &v : raiz["turnos"].toArray()) {
        const Turno t = turnoDe(v.toObject());
        if (t.inicio.isValid())   /* un turno sin fecha no se puede mostrar ni ocupar */
            leidos.turnos.append(t);
    }
    for (const QJsonValue &v : raiz["profesionales"].toArray())
        leidos.profesionales.append(profesionalDe(v.toObject()));
    for (const QJsonValue &v : raiz["pacientes"].toArray())
        leidos.pacientes.append(pacienteDe(v.toObject()));
    *datos = leidos;
    return true;
}

bool guardar(const QString &ruta, const Datos &datos)
{
    QDir().mkpath(QFileInfo(ruta).absolutePath());
    const QJsonObject raiz = {
        { "version", VERSION },
        { "protocolos", lista(datos.protocolos) },
        { "turnos", lista(datos.turnos) },
        { "profesionales", lista(datos.profesionales) },
        { "pacientes", lista(datos.pacientes) },
    };
    QSaveFile archivo(ruta);
    if (!archivo.open(QIODevice::WriteOnly))
        return false;
    archivo.write(QJsonDocument(raiz).toJson(QJsonDocument::Indented));
    return archivo.commit();
}

}
