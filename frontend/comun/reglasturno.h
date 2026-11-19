/* Reglas de un turno que usan igual Gestión y la terminal: qué horario está libre sin
 * la base, si un turno sigue vigente, el código de la seña simulada y qué pasa con la
 * seña al cancelar. Antes cada ventana tenía su propia copia. */
#ifndef REGLASTURNO_H
#define REGLASTURNO_H

#include "modelo.h"

namespace ReglasTurno {

/* Días hacia atrás y hacia adelante de agenda que se leen de la base. */
constexpr int DIAS_AGENDA = 60;
/* Cada cuánto las dos aplicaciones miran si la base cambió (milisegundos). */
constexpr int MS_SINCRONIZAR = 3000;

/* true si en ese horario ya hay un turno que no se canceló. */
bool horarioOcupado(const QVector<Turno> &turnos, const QDateTime &inicio);

/* Sin base: los horarios del instituto ("09:00", ...) de ese día que no pasaron y están libres.
 * Los domingos no hay ninguno. */
QStringList horariosLibresSinBase(const QDate &dia, const QVector<Turno> &turnos, const QDateTime &ahora);

/* Pendiente o confirmado, y todavía no pasó. */
bool esVigente(const Turno &t, const QDateTime &ahora);

/* Código de la seña simulada (mock): SIM-123456, sin repetirse entre los turnos cargados. */
QString nuevoCodigoOperacion(const QVector<Turno> &turnos);

/* Qué pasa con la seña si se cancela ahora (RF-10), para mostrarlo antes de confirmar. */
QString explicacionReembolso(const Turno &t, const QDateTime &ahora);

}

#endif
