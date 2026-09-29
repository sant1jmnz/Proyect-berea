#include "db.h"

#include <sql.h>
#include <sqlext.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

struct Db {
    SQLHENV env;
    SQLHDBC dbc;
};

static int ok(SQLRETURN r) { return r == SQL_SUCCESS || r == SQL_SUCCESS_WITH_INFO; }

int db_conectar(const char *cadena, Db **out)
{
    Db *db = calloc(1, sizeof *db);
    if (!db)
        return -1;
    if (!ok(SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &db->env)) ||
        !ok(SQLSetEnvAttr(db->env, SQL_ATTR_ODBC_VERSION, (void *)SQL_OV_ODBC3, 0)) ||
        !ok(SQLAllocHandle(SQL_HANDLE_DBC, db->env, &db->dbc)) ||
        !ok(SQLDriverConnect(db->dbc, NULL, (SQLCHAR *)cadena, SQL_NTS, NULL, 0, NULL,
                             SQL_DRIVER_NOPROMPT))) {
        db_desconectar(db);
        return -1;
    }
    *out = db;
    return 0;
}

void db_desconectar(Db *db)
{
    if (!db)
        return;
    if (db->dbc) {
        SQLDisconnect(db->dbc);
        SQLFreeHandle(SQL_HANDLE_DBC, db->dbc);
    }
    if (db->env)
        SQLFreeHandle(SQL_HANDLE_ENV, db->env);
    free(db);
}

int db_buscar_protocolos(Db *db, const char *texto, Protocolo *out, int max, int *n)
{
    SQLHSTMT st;
    char patron[128];
    SQLLEN ind = SQL_NTS;
    int cant = 0, rc = -1;

    snprintf(patron, sizeof patron, "%%%s%%", texto ? texto : "");
    if (!ok(SQLAllocHandle(SQL_HANDLE_STMT, db->dbc, &st)))
        return -1;
    if (!ok(SQLPrepare(st, (SQLCHAR *)
            "SELECT id, nombre, duracion_min, precio FROM Protocolo "
            "WHERE activo = 1 AND (nombre LIKE ? OR palabras LIKE ?) ORDER BY nombre",
            SQL_NTS)))
        goto fin;
    for (int i = 1; i <= 2; i++)
        if (!ok(SQLBindParameter(st, i, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_VARCHAR,
                                 sizeof patron, 0, patron, 0, &ind)))
            goto fin;
    if (!ok(SQLExecute(st)))
        goto fin;
    while (cant < max && SQLFetch(st) == SQL_SUCCESS) {
        Protocolo *p = &out[cant++];
        SQLGetData(st, 1, SQL_C_SLONG, &p->id, 0, NULL);
        SQLGetData(st, 2, SQL_C_CHAR, p->nombre, sizeof p->nombre, NULL);
        SQLGetData(st, 3, SQL_C_SLONG, &p->duracion_min, 0, NULL);
        SQLGetData(st, 4, SQL_C_SLONG, &p->precio, 0, NULL);
    }
    *n = cant;
    rc = 0;
fin:
    SQLFreeHandle(SQL_HANDLE_STMT, st);
    return rc;
}

static void a_texto(time_t t, char *buf, size_t len)
{
    struct tm tm;
    gmtime_r(&t, &tm);
    strftime(buf, len, "%Y-%m-%d %H:%M:%S", &tm);
}

int db_crear_turno(Db *db, int paciente_id, int protocolo_id, int profesional_id,
                   time_t inicio, time_t fin, const char *origen, int sena_monto,
                   int *id_turno)
{
    SQLHSTMT st;
    char ini[24], fi[24];
    SQLLEN ind_txt = SQL_NTS, ind_id = 0;
    SQLINTEGER id = 0;
    int rc = -1;

    a_texto(inicio, ini, sizeof ini);
    a_texto(fin, fi, sizeof fi);
    if (!ok(SQLAllocHandle(SQL_HANDLE_STMT, db->dbc, &st)))
        return -1;
    if (!ok(SQLPrepare(st, (SQLCHAR *)
            "INSERT INTO Turno (paciente_id, protocolo_id, profesional_id, inicio, fin,"
            " origen, sena_monto) OUTPUT INSERTED.id VALUES (?, ?, ?, ?, ?, ?, ?)",
            SQL_NTS)))
        goto fin;
    SQLBindParameter(st, 1, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, &paciente_id, 0, NULL);
    SQLBindParameter(st, 2, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, &protocolo_id, 0, NULL);
    SQLBindParameter(st, 3, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, &profesional_id, 0, NULL);
    SQLBindParameter(st, 4, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_VARCHAR, sizeof ini, 0, ini, 0, &ind_txt);
    SQLBindParameter(st, 5, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_VARCHAR, sizeof fi, 0, fi, 0, &ind_txt);
    SQLBindParameter(st, 6, SQL_PARAM_INPUT, SQL_C_CHAR, SQL_VARCHAR, 10, 0, (SQLPOINTER)origen, 0, &ind_txt);
    SQLBindParameter(st, 7, SQL_PARAM_INPUT, SQL_C_SLONG, SQL_INTEGER, 0, 0, &sena_monto, 0, NULL);
    if (!ok(SQLExecute(st)))
        goto fin;              /* horario ocupado: viola el índice único */
    if (SQLFetch(st) == SQL_SUCCESS) {
        SQLGetData(st, 1, SQL_C_SLONG, &id, 0, &ind_id);
        *id_turno = (int)id;
        rc = 0;
    }
fin:
    SQLFreeHandle(SQL_HANDLE_STMT, st);
    return rc;
}
