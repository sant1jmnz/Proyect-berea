/* Conexión de la app a MySQL, al estilo de la cátedra (PPT 006): cliente C
 * `mysql.h`, mysql_init + mysql_real_connect + mysql_query + mysql_store_result.
 * Los datos de conexión NO van en el código (el PPT los escribe adentro):
 * salen de variables de entorno o de un archivo dermalia.ini, así la misma
 * app sirve para el MySQL local del laboratorio y para Aiven (que además
 * pide conexión cifrada con SSL). La contraseña nunca va al repositorio.
 *
 * Cómo se usan los stored procedures (convención en docs/arquitectura.md):
 *   · llamar("nombre_sp", {param1, param2}) arma el CALL y escapa los datos;
 *   · si el SP falla devuelve una fila  estado = 'ERROR', codigo_sql,
 *     descripcion_error  (el EXIT HANDLER de la cátedra); acá se convierte
 *     en Resultado::ok = false con el mensaje listo para mostrar. */
#ifndef BASEDATOS_H
#define BASEDATOS_H

#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

struct ConfigBD {
    QString host = "127.0.0.1";
    unsigned puerto = 3306;
    QString usuario;
    QString clave;
    QString base;              /* base por defecto; vacío si los SP llevan el schema */
    bool ssl = false;          /* Aiven lo exige */
    unsigned timeoutSeg = 5;   /* para que la pantalla no se cuelgue sin internet */

    bool completa() const { return !host.isEmpty() && !usuario.isEmpty(); }

    /* Variables de entorno DERMALIA_DB_HOST, _PORT, _USER, _PASS, _NAME, _SSL.
     * Si hay un dermalia.ini (secciones [base]), se usa para lo que falte. */
    static ConfigBD desdeEntorno(const QString &archivoIni = QStringLiteral("dermalia.ini"));
};

struct Resultado {
    bool ok = false;
    QString error;                 /* mensaje claro para el usuario */
    int codigoSql = 0;             /* 0 si no hubo error de MySQL */
    QVector<QVariantMap> filas;    /* primer conjunto de resultados, por nombre de columna */
};

class BaseDatos
{
public:
    explicit BaseDatos(const ConfigBD &config);
    ~BaseDatos();
    BaseDatos(const BaseDatos &) = delete;
    BaseDatos &operator=(const BaseDatos &) = delete;

    bool conectar();               /* false: ver ultimoError() */
    void cerrar();
    bool conectado() const;
    QString ultimoError() const { return error; }

    /* CALL sp(p1, p2, ...). QVariant nulo → NULL; números sin comillas;
     * texto y fechas entre comillas y escapados. */
    Resultado llamar(const QString &sp, const QVariantList &parametros = {});

    /* Texto en español para el código de error de MySQL (2002, 1045, ...). */
    static QString mensajeDeError(int codigo, const QString &textoOriginal);
    /* Texto SQL listo para pegar: escapa comillas y arma NULL/números/texto. */
    static QString literal(const QVariant &valor);
    /* ¿La biblioteca de MySQL estaba al compilar? */
    static bool compiladoConMysql();

private:
    struct Impl;
    Impl *d;
    ConfigBD config;
    QString error;
};

#endif
