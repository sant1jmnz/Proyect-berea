/* Seña de un turno (RF-10): es un porcentaje del precio y ese porcentaje
 * vive en la categoría del protocolo (30% en general, 40% en cirugías; ver
 * "Categoría de protocolo" en docs/modelo-entidades.md). No tiene mínimo. */
#ifndef SENA_H
#define SENA_H

namespace Sena {

/* Redondea al peso: 30% de $18.333 = $5.499,9 → $5.500. */
inline int calcular(int precio, int porcentaje)
{
    if (precio <= 0 || porcentaje <= 0)
        return 0;
    return (precio * porcentaje + 50) / 100;
}

}

#endif
