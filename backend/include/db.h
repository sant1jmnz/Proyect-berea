/* Acceso a SQL Server por ODBC. Simple: una conexión, consultas con
 * parámetros. Todas devuelven 0 si salió bien y -1 si falló. */
#ifndef DERMALIA_DB_H
#define DERMALIA_DB_H

#include <time.h>

#ifdef __cplusplus
extern "C" {   /* para incluirlo desde Qt (C++) */
#endif

typedef struct Db Db;

typedef struct {
    int  id;
    char nombre[101];
    int  duracion_min;
    int  precio;
} Protocolo;

/* `cadena`: cadena de conexión ODBC, ej.
 * "Driver={ODBC Driver 18 for SQL Server};Server=localhost;Database=dermalia;UID=...;PWD=...;" */
int  db_conectar(const char *cadena, Db **out);
void db_desconectar(Db *db);

/* RF-05/06: protocolos activos cuyo nombre o palabras contienen `texto`
 * (texto vacío = todos). Devuelve la cantidad en *n (hasta `max`). */
int db_buscar_protocolos(Db *db, const char *texto, Protocolo *out, int max, int *n);

/* RF-01/02: crea un turno confirmado para un paciente ya existente.
 * `origen` es "terminal" o "recepcion". Falla si el horario ya está
 * ocupado (índice único, RF-04). Devuelve el id en *id_turno. */
int db_crear_turno(Db *db, int paciente_id, int protocolo_id, int profesional_id,
                   time_t inicio, time_t fin, const char *origen, int sena_monto,
                   int *id_turno);

#ifdef __cplusplus
}
#endif

#endif
