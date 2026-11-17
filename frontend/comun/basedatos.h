/* Conexión de la aplicación con MySQL, como en la clase (PPT 006):
 *   mysql_init()          crea el objeto de conexión
 *   mysql_real_connect()  abre la sesión con el servidor
 *   mysql_query()         manda el CALL al servidor
 *   mysql_store_result()  baja el resultado a la memoria del programa
 *   mysql_fetch_row()     recorre las filas
 *   mysql_free_result()   libera esa memoria
 *   mysql_close()         cierra la conexión
 *
 * La diferencia con el ejemplo del PPT: el usuario y la contraseña no van
 * escritos en el código (el repositorio es público). Salen de variables de
 * entorno o del archivo dermalia.ini (ver dermalia.ini.ejemplo).
 *
 * Los stored procedures, si fallan, devuelven la fila del EXIT HANDLER:
 * estado = 'ERROR' con el código y el mensaje. `llamar` la convierte en
 * Resultado::ok = false con el mensaje listo para mostrar. */
#ifndef BASEDATOS_H
#define BASEDATOS_H

#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>


/* Datos para conectarse (los mismos que recibe mysql_real_connect). */
struct ConfigBD {
    QString host = "127.0.0.1";
    unsigned puerto = 3306;
    QString usuario;
    QString clave;
    QString base;              /* vacío: los SP se llaman con su schema (agenda.sp_...) */
    bool ssl = false;          /* Aiven pide conexión cifrada */
    unsigned timeoutSeg = 5;   /* si no hay internet, no deja la ventana colgada */

    bool completa() const { return !host.isEmpty() && !usuario.isEmpty(); }

    /* Lee DERMALIA_DB_HOST, _PORT, _USER, _PASS, _NAME y _SSL;
     * lo que falte lo busca en dermalia.ini (sección [base]). */
    static ConfigBD desdeEntorno(const QString &archivoIni = QStringLiteral("dermalia.ini"));
};

/* Lo que devuelve un CALL: las filas (por nombre de columna) o el error. */
struct Resultado {
    bool ok = false;
    QString error;                 /* mensaje para la persona */
    int codigoSql = 0;             /* número de error de MySQL (0 si no hubo) */
    QVector<QVariantMap> filas;
    QStringList columnas;          /* nombres de las columnas en el orden del SELECT */
};

class BaseDatos
{
public:
    explicit BaseDatos(const ConfigBD &config);
    ~BaseDatos();
    BaseDatos(const BaseDatos &) = delete;              /* una conexión no se copia */
    BaseDatos &operator=(const BaseDatos &) = delete;

    bool conectar();               /* false: el motivo queda en ultimoError() */
    void cerrar();
    bool conectado() const { return conn != nullptr; }
    QString ultimoError() const { return error; }

    /* Ejecuta CALL sp(p1, p2, ...). Los textos van entre comillas simples,
     * los números sin comillas y un QVariant vacío como NULL. */
    Resultado llamar(const QString &sp, const QVariantList &parametros = {});

    /* Mensaje en castellano para los errores de MySQL más comunes. */
    static QString mensajeDeError(int codigo, const QString &textoOriginal);
    /* Un valor escrito como en SQL: NULL, 25000, '2026-11-20' o 'texto' (con las comillas escapadas). */
    static QString literal(const QVariant &valor);
    /* false si se compiló sin la librería de MySQL (entonces no hay conexión). */
    static bool compiladoConMysql();

private:
    ConfigBD config;
    void *conn = nullptr;          /* el MYSQL *conn del PPT (se guarda como void * para que compile igual con
                                      libmysqlclient y con libmariadb, que nombran distinto ese tipo); nullptr si no hay conexión */
    QString error;
};

#endif
