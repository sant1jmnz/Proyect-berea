#include "agendareal.h"

#include "datosbase.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <algorithm>

namespace AgendaReal {

static QJsonObject aJson(const Protocolo &p)
{
    return { { "id", p.id }, { "nombre", p.nombre }, { "duracionMin", p.duracionMin }, { "precio", p.precio },
             { "activo", p.activo } };
}

static Protocolo protocoloDeJson(const QJsonObject &o)
{
    Protocolo p {};
    p.id = o["id"].toInt();
    p.nombre = o["nombre"].toString();
    p.duracionMin = o["duracionMin"].toInt();
    p.precio = o["precio"].toInt();
    p.activo = o["activo"].toBool(true);
    return p;
}

static QJsonObject aJson(const Profesional &p)
{
    QJsonArray franjas;
    for (const Franja &f : p.franjas)
        franjas.append(QJsonObject { { "fecha", f.fecha.toString(Qt::ISODate) }, { "desde", f.desde.toString("HH:mm") },
                                     { "hasta", f.hasta.toString("HH:mm") }, { "activa", f.activa } });
    return { { "id", p.id }, { "nombre", p.nombre }, { "activo", p.activo },
             { "protocolos", QJsonArray::fromStringList(p.protocolos) }, { "franjas", franjas } };
}

static Profesional profesionalDeJson(const QJsonObject &o)
{
    Profesional p {};
    p.id = o["id"].toInt();
    p.nombre = o["nombre"].toString();
    p.activo = o["activo"].toBool(true);
    for (const QJsonValue &v : o["protocolos"].toArray())
        p.protocolos << v.toString();
    for (const QJsonValue &v : o["franjas"].toArray()) {
        const QJsonObject f = v.toObject();
        Franja franja;
        franja.fecha = QDate::fromString(f["fecha"].toString(), Qt::ISODate);
        franja.desde = QTime::fromString(f["desde"].toString(), "HH:mm");
        franja.hasta = QTime::fromString(f["hasta"].toString(), "HH:mm");
        franja.activa = f["activa"].toBool(true);
        p.franjas.append(franja);
    }
    return p;
}

/* Del turno solo hace falta lo que ocupa agenda: quién, cuándo y si sigue vigente. */
static QJsonObject aJson(const Turno &t)
{
    return { { "profesional", t.profesional }, { "inicio", t.inicio.toString(Qt::ISODate) },
             { "fin", t.fin.toString(Qt::ISODate) }, { "estado", int(t.estado) } };
}

static Turno turnoDeJson(const QJsonObject &o)
{
    Turno t {};
    t.profesional = o["profesional"].toString();
    t.inicio = QDateTime::fromString(o["inicio"].toString(), Qt::ISODate);
    t.fin = QDateTime::fromString(o["fin"].toString(), Qt::ISODate);
    t.estado = EstadoTurno(o["estado"].toInt());
    return t;
}

bool guardar(const QString &ruta, const Foto &foto)
{
    QJsonArray protocolos, profesionales, turnos;
    for (const Protocolo &p : foto.protocolos)
        protocolos.append(aJson(p));
    for (const Profesional &p : foto.profesionales)
        profesionales.append(aJson(p));
    for (const Turno &t : foto.turnos)
        turnos.append(aJson(t));
    const QJsonObject raiz { { "tomada", foto.tomada.toString(Qt::ISODate) }, { "protocolos", protocolos },
                             { "profesionales", profesionales }, { "turnos", turnos } };
    QDir().mkpath(QFileInfo(ruta).absolutePath());
    QSaveFile f(ruta);   /* escribe en un temporal y reemplaza: no deja el archivo a medias */
    if (!f.open(QIODevice::WriteOnly))
        return false;
    f.write(QJsonDocument(raiz).toJson(QJsonDocument::Compact));
    return f.commit();
}

bool leer(const QString &ruta, Foto *foto)
{
    QFile f(ruta);
    if (!f.open(QIODevice::ReadOnly))
        return false;
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject())
        return false;
    const QJsonObject o = doc.object();
    Foto leida;
    leida.tomada = QDateTime::fromString(o["tomada"].toString(), Qt::ISODate);
    for (const QJsonValue &v : o["protocolos"].toArray())
        leida.protocolos.append(protocoloDeJson(v.toObject()));
    for (const QJsonValue &v : o["profesionales"].toArray())
        leida.profesionales.append(profesionalDeJson(v.toObject()));
    for (const QJsonValue &v : o["turnos"].toArray())
        leida.turnos.append(turnoDeJson(v.toObject()));
    *foto = leida;
    return true;
}

bool tomar(Repositorio &repo, const QDate &hoy, Foto *foto, QString *error)
{
    Foto nueva;
    if (!DatosBase::cargarProtocolos(repo, nueva.protocolos, error)
        || !DatosBase::cargarProfesionales(repo, nueva.protocolos, nueva.profesionales, error)
        || !DatosBase::cargarTurnos(repo, hoy, DIAS_FOTO, nueva.turnos, error))
        return false;
    nueva.tomada = QDateTime::currentDateTime();
    *foto = nueva;
    return true;
}

bool cubreDia(const Foto &foto, const QDate &dia)
{
    for (const Profesional &p : foto.profesionales) {
        for (const Franja &f : p.franjas) {
            if (f.activa && f.fecha == dia)
                return true;
        }
    }
    return false;
}

static bool contiene(const QStringList &lista, const QString &nombre)
{
    for (const QString &s : lista) {
        if (s.compare(nombre, Qt::CaseInsensitive) == 0)
            return true;
    }
    return false;
}

static int minutosDelDia(const QTime &hora)
{
    return hora.hour() * 60 + hora.minute();
}

QVector<HorarioLibre> horariosLibres(const Foto &foto, const QStringList &protocolos, const QDate &dia,
                                     const QDateTime &ahora, const QVector<Turno> &extra)
{
    QVector<HorarioLibre> libres;
    if (protocolos.isEmpty())
        return libres;

    int duracion = 0;
    for (const QString &nombre : protocolos) {
        int minutos = 0;
        for (const Protocolo &p : foto.protocolos) {
            if (p.activo && p.nombre.compare(nombre, Qt::CaseInsensitive) == 0)
                minutos = p.duracionMin;
        }
        if (minutos <= 0)
            return libres;   /* un tratamiento que la base no tiene (o dado de baja): no hay horarios que ofrecer */
        duracion += minutos;
    }

    for (const Profesional &p : foto.profesionales) {
        if (!p.activo)
            continue;
        bool haceTodos = true;
        for (const QString &nombre : protocolos)
            haceTodos = haceTodos && contiene(p.protocolos, nombre);
        if (!haceTodos)
            continue;

        for (const Franja &f : p.franjas) {
            if (!f.activa || f.fecha != dia)
                continue;
            for (int m = minutosDelDia(f.desde); m + duracion <= minutosDelDia(f.hasta); m += PASO_MIN) {
                const QDateTime inicio(dia, QTime(m / 60, m % 60));
                const QDateTime fin = inicio.addSecs(duracion * 60);
                if (inicio <= ahora)
                    continue;
                bool ocupado = false;
                for (const QVector<Turno> *lista : { &foto.turnos, &extra }) {
                    for (const Turno &t : *lista) {
                        if (t.estado == EstadoTurno::Cancelado || (!t.profesional.isEmpty() && t.profesional != p.nombre))
                            continue;
                        ocupado = ocupado || (t.inicio < fin && inicio < t.fin);
                    }
                }
                if (!ocupado)
                    libres.append({ p.id, p.nombre, inicio, fin });
            }
        }
    }
    std::sort(libres.begin(), libres.end(), [](const HorarioLibre &a, const HorarioLibre &b) {
        return a.inicio != b.inicio ? a.inicio < b.inicio : a.idProfesional < b.idProfesional;
    });
    return libres;
}

}
