/* Foto de la agenda real (protocolos, profesionales con sus franjas y turnos de la base), guardada en la PC
 * cada vez que hay conexión. Sin conexión, el Cliente calcula los horarios libres sobre esta foto con la
 * misma regla que sp_horarios_libres, para ofrecer solo horarios que existen de verdad en la base y que
 * el turno guardado en contingencia pueda sincronizarse después. */
#ifndef AGENDAREAL_H
#define AGENDAREAL_H

#include "modelo.h"
#include "repositorio.h"

#include <QDate>
#include <QDateTime>
#include <QStringList>
#include <QVector>

namespace AgendaReal {

struct Foto {
    QVector<Protocolo> protocolos;
    QVector<Profesional> profesionales;
    QVector<Turno> turnos;
    QDateTime tomada;   /* cuándo se leyó de la base */
    bool vacia() const { return profesionales.isEmpty(); }
};

constexpr int DIAS_FOTO = 400;   /* turnos que se guardan hacia atrás y hacia adelante */
constexpr int PASO_MIN = 30;     /* los horarios salen cada 30 min desde el inicio de la franja (igual que la base) */

bool leer(const QString &ruta, Foto *foto);
bool guardar(const QString &ruta, const Foto &foto);

/* Lee todo de la base. Devuelve false (y deja el motivo en `error`) si algo falla; en ese caso `foto` no cambia. */
bool tomar(Repositorio &repo, const QDate &hoy, Foto *foto, QString *error);

/* ¿Hay franjas cargadas para ese día? Si no, la agenda real no llega hasta ahí. */
bool cubreDia(const Foto &foto, const QDate &dia);

/* Horarios libres del día para esos tratamientos (por nombre): profesional activo que los hace todos, dentro de
 * una franja, que no pise otro turno no cancelado de ese profesional (en `foto.turnos` o en `extra`) y que
 * empiece después de `ahora`. Ordenados por hora; un renglón por profesional y hora. */
QVector<HorarioLibre> horariosLibres(const Foto &foto, const QStringList &protocolos, const QDate &dia,
                                     const QDateTime &ahora, const QVector<Turno> &extra = {});

}

#endif
