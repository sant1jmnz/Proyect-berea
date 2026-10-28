/* Reembolso de la seña al cancelar (RF-10): se devuelve el 100% si se
 * cancela con más de 24 horas de anticipación; por debajo de ese plazo, o por
 * inasistencia, no se devuelve nada. Es el mismo criterio que ya usa el
 * apartado Cliente (buscarturnowidget.cpp). Como el pago es un mock, "devolver"
 * es solo cambiar el estado y el monto en el sistema. */
#ifndef REEMBOLSO_H
#define REEMBOLSO_H

#include <QDateTime>

namespace Reembolso {

constexpr int HORAS_LIMITE = 24;

/* true si faltan MÁS de 24 h para el turno. Justo 24 h ya no alcanza. */
inline bool aTiempo(const QDateTime &inicioTurno, const QDateTime &ahora)
{
    return ahora.secsTo(inicioTurno) > HORAS_LIMITE * 3600;
}

/* Monto a devolver: toda la seña si estaba pagada y se cancela a tiempo. */
inline int monto(int sena, bool senaPagada, const QDateTime &inicioTurno, const QDateTime &ahora)
{
    return (senaPagada && aTiempo(inicioTurno, ahora)) ? sena : 0;
}

}

#endif
