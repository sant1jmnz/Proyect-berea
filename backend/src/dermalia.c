#include "dermalia.h"

#include <ctype.h>
#include <stdio.h>
#include <string.h>

long dermalia_calcular_sena(long precio_protocolo)
{
    if (precio_protocolo < 0)
        return -1;
    long sena = (precio_protocolo * SENA_PORCENTAJE + 50) / 100;
    if (sena < SENA_MINIMO)
        sena = SENA_MINIMO;
    if (sena > precio_protocolo)
        sena = precio_protocolo;
    return sena;
}

long dermalia_reembolso_sena(long sena, time_t turno, time_t ahora)
{
    double anticipacion = difftime(turno, ahora);
    if (anticipacion > CANCELACION_HORAS * 3600.0)
        return sena;
    return 0;
}

long dermalia_reembolso_ausencia(long sena)
{
    (void)sena;
    return 0;
}

int dermalia_recordatorio_visible(EstadoTurno estado, time_t turno,
                                  time_t ahora, int horas)
{
    if (estado != TURNO_CONFIRMADO)
        return 0;
    double falta = difftime(turno, ahora);
    return falta > 0 && falta <= horas * 3600.0;
}

int dermalia_superpone(time_t ini1, time_t fin1, time_t ini2, time_t fin2)
{
    return ini1 < fin2 && ini2 < fin1;
}

int dermalia_enlace_whatsapp(const char *telefono, const char *consulta,
                             char *out, size_t out_len)
{
    static const char hex[] = "0123456789ABCDEF";
    const char *base = "https://wa.me/";
    size_t n = 0;

    if (!telefono || !consulta || !out || out_len == 0)
        return -1;
    for (const char *p = telefono; *p; p++)
        if (!isdigit((unsigned char)*p))
            return -1;

    n = strlen(base) + strlen(telefono) + strlen("?text=");
    if (n >= out_len)
        return -1;
    snprintf(out, out_len, "%s%s?text=", base, telefono);

    for (const unsigned char *c = (const unsigned char *)consulta; *c; c++) {
        int seguro = isalnum(*c) || *c == '-' || *c == '_' || *c == '.';
        size_t need = seguro ? 1 : 3;
        if (n + need >= out_len) {
            out[0] = '\0';
            return -1;
        }
        if (seguro) {
            out[n++] = (char)*c;
        } else {
            out[n++] = '%';
            out[n++] = hex[*c >> 4];
            out[n++] = hex[*c & 15];
        }
    }
    out[n] = '\0';
    return 0;
}
