#include "dermalia.h"

#include <stdio.h>
#include <string.h>

static int fallos;
#define CHECK(c) do { if (!(c)) { printf("FALLA %s:%d  %s\n", __FILE__, __LINE__, #c); fallos++; } } while (0)

int main(void)
{
    /* RF-10: 30%, mínimo $5.000, tope en el precio */
    CHECK(dermalia_calcular_sena(100000) == 30000);
    CHECK(dermalia_calcular_sena(20000) == 6000);
    CHECK(dermalia_calcular_sena(10000) == 5000);
    CHECK(dermalia_calcular_sena(3000) == 3000);
    CHECK(dermalia_calcular_sena(0) == 0);
    CHECK(dermalia_calcular_sena(-1) == -1);

    time_t t = 1000000;
    CHECK(dermalia_reembolso_sena(6000, t, t - 25 * 3600) == 6000);
    CHECK(dermalia_reembolso_sena(6000, t, t - 24 * 3600) == 0);
    CHECK(dermalia_reembolso_sena(6000, t, t - 3600) == 0);
    CHECK(dermalia_reembolso_sena(6000, t, t + 3600) == 0);
    CHECK(dermalia_reembolso_ausencia(6000) == 0);

    /* RF-11 */
    CHECK(dermalia_recordatorio_visible(TURNO_CONFIRMADO, t, t - 3600, 24));
    CHECK(!dermalia_recordatorio_visible(TURNO_CONFIRMADO, t, t - 48 * 3600, 24));
    CHECK(!dermalia_recordatorio_visible(TURNO_CONFIRMADO, t, t + 1, 24));
    CHECK(!dermalia_recordatorio_visible(TURNO_CANCELADO, t, t - 3600, 24));

    /* RF-04 */
    CHECK(dermalia_superpone(0, 60, 30, 90));
    CHECK(!dermalia_superpone(0, 60, 60, 120));
    CHECK(dermalia_superpone(0, 60, 10, 20));

    /* RF-07 */
    char url[128];
    CHECK(dermalia_enlace_whatsapp("5491100000000", "botox precio?", url, sizeof url) == 0);
    CHECK(strcmp(url, "https://wa.me/5491100000000?text=botox%20precio%3F") == 0);
    CHECK(dermalia_enlace_whatsapp("+54 11", "x", url, sizeof url) == -1);
    CHECK(dermalia_enlace_whatsapp("5491100000000", "consulta larga", url, 30) == -1);

    if (fallos == 0)
        puts("OK");
    return fallos != 0;
}
