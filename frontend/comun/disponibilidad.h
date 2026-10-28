/* Franjas de disponibilidad de un profesional (RF-03): día y horario en que
 * atiende. La regla que importa es que dos franjas del mismo profesional no se
 * pisen, para no ofrecer el mismo horario dos veces (RF-04). Coincide con la
 * entidad Disponibilidad de docs/diagramas/README.md. */
#ifndef DISPONIBILIDAD_H
#define DISPONIBILIDAD_H

#include <QDate>
#include <QString>
#include <QTime>
#include <QVector>

struct Franja {
    QDate fecha;
    QTime desde;
    QTime hasta;
    bool activa = true;
};

namespace Disponibilidad {

/* Dos franjas se pisan si son del mismo día y se cruzan; que una termine
 * justo cuando la otra empieza (12:00 y 12:00) no es pisarse. */
inline bool sePisan(const Franja &a, const Franja &b)
{
    return a.fecha == b.fecha && a.desde < b.hasta && b.desde < a.hasta;
}

/* Revisa una franja nueva contra las que ya tiene el profesional. Devuelve
 * true si se puede agregar; si no, deja el motivo en `error`. */
inline bool puedeAgregar(const QVector<Franja> &existentes, const Franja &nueva, QString *error = nullptr)
{
    auto fallar = [&](const QString &motivo) {
        if (error)
            *error = motivo;
        return false;
    };
    if (!nueva.fecha.isValid())
        return fallar("Elegí el día.");
    if (nueva.fecha < QDate::currentDate())
        return fallar("No se carga disponibilidad en días pasados.");
    if (!nueva.desde.isValid() || !nueva.hasta.isValid() || nueva.hasta <= nueva.desde)
        return fallar("La hora de fin tiene que ser posterior a la de inicio.");
    for (const Franja &f : existentes)
        if (f.activa && sePisan(f, nueva))
            return fallar(QString("Se superpone con la franja de %1 a %2 de ese día.")
                              .arg(f.desde.toString("HH:mm"), f.hasta.toString("HH:mm")));
    return true;
}

}

#endif
