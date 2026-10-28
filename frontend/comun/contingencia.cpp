#include "contingencia.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>

static QJsonObject aJson(const TurnoPendiente &t)
{
    return { { "paciente", t.paciente }, { "dni", t.dni }, { "telefono", t.telefono },
             { "protocolo", t.protocolo }, { "inicio", t.inicio.toString(Qt::ISODate) },
             { "sena", t.sena }, { "senaPagada", t.senaPagada }, { "origen", t.origen },
             { "guardado", t.guardado.toString(Qt::ISODate) } };
}

static TurnoPendiente deJson(const QJsonObject &o)
{
    TurnoPendiente t;
    t.paciente = o["paciente"].toString();
    t.dni = o["dni"].toString();
    t.telefono = o["telefono"].toString();
    t.protocolo = o["protocolo"].toString();
    t.inicio = QDateTime::fromString(o["inicio"].toString(), Qt::ISODate);
    t.sena = o["sena"].toInt();
    t.senaPagada = o["senaPagada"].toBool();
    t.origen = o["origen"].toString();
    t.guardado = QDateTime::fromString(o["guardado"].toString(), Qt::ISODate);
    return t;
}

Contingencia::Contingencia(const QString &archivo)
    : ruta(archivo)
{
    if (ruta.isEmpty()) {
        const QString carpeta = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
        ruta = QDir(carpeta).filePath("pendientes.json");
    }
}

QVector<TurnoPendiente> Contingencia::pendientes() const
{
    QFile f(ruta);
    if (!f.open(QIODevice::ReadOnly))
        return {};   /* todavía no hay archivo: no hay pendientes */
    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    QVector<TurnoPendiente> lista;
    for (const QJsonValue &v : doc.array())
        lista.append(deJson(v.toObject()));
    return lista;
}

int Contingencia::cantidad() const
{
    return pendientes().size();
}

bool Contingencia::guardar(const TurnoPendiente &turno)
{
    QVector<TurnoPendiente> lista = pendientes();
    TurnoPendiente nuevo = turno;
    if (!nuevo.guardado.isValid())
        nuevo.guardado = QDateTime::currentDateTime();
    lista.append(nuevo);
    return escribir(lista);
}

bool Contingencia::vaciar()
{
    return escribir({});
}

bool Contingencia::escribir(const QVector<TurnoPendiente> &turnos) const
{
    QDir().mkpath(QFileInfo(ruta).absolutePath());
    QJsonArray arreglo;
    for (const TurnoPendiente &t : turnos)
        arreglo.append(aJson(t));
    QSaveFile f(ruta);   /* escribe en un temporal y reemplaza: no deja el archivo a medias */
    if (!f.open(QIODevice::WriteOnly))
        return false;
    f.write(QJsonDocument(arreglo).toJson());
    return f.commit();
}
