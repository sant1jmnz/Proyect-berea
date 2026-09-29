/* Núcleo de reglas de negocio de Dermalia (backend en C).
 * Sin dependencias de base de datos ni de Qt: se prueba solo y lo consumen
 * los dos apartados (Cliente y Gestión). Montos en pesos enteros. */
#ifndef DERMALIA_H
#define DERMALIA_H

#include <stddef.h>
#include <time.h>

#define SENA_PORCENTAJE 30       /* RF-10: 30% del valor del protocolo */
#define SENA_MINIMO 5000         /* RF-10: mínimo $5.000 */
#define CANCELACION_HORAS 24     /* RF-10: reembolso 100% con más de 24 h */
#define RECORDATORIO_HORAS 24    /* RF-11: anticipación por defecto */

typedef enum {
    TURNO_CONFIRMADO,
    TURNO_REALIZADO,
    TURNO_CANCELADO,
    TURNO_AUSENTE
} EstadoTurno;

/* RF-10: seña simulada. Nunca supera el precio del protocolo.
 * Devuelve -1 si el precio es negativo. */
long dermalia_calcular_sena(long precio_protocolo);

/* RF-10: monto reembolsable si se cancela `ahora` un turno en `turno`.
 * Reembolso total con más de CANCELACION_HORAS de anticipación; cero si
 * quedan 24 h o menos, o si el turno ya pasó. */
long dermalia_reembolso_sena(long sena, time_t turno, time_t ahora);

/* RF-10: la paciente no se presentó, la seña no se devuelve. */
long dermalia_reembolso_ausencia(long sena);

/* RF-11: 1 si corresponde mostrar el recordatorio (turno confirmado,
 * futuro y dentro de la ventana de `horas` de anticipación), 0 si no. */
int dermalia_recordatorio_visible(EstadoTurno estado, time_t turno,
                                  time_t ahora, int horas);

/* RF-04 / R1: 1 si [ini1, fin1) y [ini2, fin2) se superponen. Sirve para
 * impedir turnos sobre un horario ocupado. */
int dermalia_superpone(time_t ini1, time_t fin1, time_t ini2, time_t fin2);

/* RF-07: arma el enlace wa.me con la consulta sin coincidencia.
 * `telefono` solo con dígitos y código de país (ej. "5491100000000").
 * Escribe en `out` (cerrado con '\0'); devuelve 0 si entra, -1 si no. */
int dermalia_enlace_whatsapp(const char *telefono, const char *consulta,
                             char *out, size_t out_len);

#endif
